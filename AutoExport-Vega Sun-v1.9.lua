--[[
@description 自动分段导出录音脚本 (v1.9 - 中文最终版)
@author Vega Sun - Riedel
@version 1.9
@about
  此脚本在后台运行。当REAPER处于录音状态时，
  它会按固定的时间间隔，自动停止录音、等待静默导出完成后、再从停止的位置继续录音。
  可以指定要导出的轨道，并使用轨道名称为文件命名。
  再次运行此脚本可以停止它。
--]]

reaper.ClearConsole() -- 每次运行时清空控制台，方便调试

---------------------------------------------------------------------
-- [ 用户配置区域 ] --
---------------------------------------------------------------------
local export_path = "C:/Record" -- <--- !! 修改这里 !! 导出文件的目标文件夹路径
local file_prefix = "Rec"                   -- 导出的文件名前缀
local export_interval_sec = 5.0             -- 每隔多少秒导出一-次 (单位：秒)

--[[
  导出格式设置
  - 支持的格式: "mp3", "wav", "flac", "ogg"
  - 注意: 导出质量（如比特率、采样率、位深度）取决于您在REAPER的渲染窗口 (File > Render) 中
    为该格式设置的 *最后一次* 配置。
    例如，要导出320kbps的MP3，请先手动打开渲染窗口，选择MP3格式，将比特率设置为320kbps，
    然后关闭窗口即可。脚本之后就会使用这个设置。
--]]
local export_format = "mp3" -- <--- 在这里设置您想要的导出格式 ("mp3", "wav", "flac", "ogg")

--[[
  指定要导出的轨道
  - "all": 导出所有正在录音的轨道。
  - "1,3,5": 仅导出第1、3、5轨道。
  - "2-5": 仅导出从第2到第5的轨道。
  - "1,3,6-8": 混合使用，导出第1、3、6、7、8轨道。
--]]
local tracks_to_export = "1,3-4" -- <--- 在这里设置您想导出的轨道

---------------------------------------------------------------------

-- [ 脚本内部变量，请勿修改 ] --
local format_codes = { mp3 = "l3pm", wav = "wave", flac = "flac", ogg = "oggv" }
local format_extensions = { mp3 = ".mp3", wav = ".wav", flac = ".flac", ogg = ".ogg" }
local render_format_code = format_codes[export_format] or "wave"
local file_extension = format_extensions[export_format] or ".wav"

-- [ 脚本状态管理 ] --
local g_state_key = "Gemini_AutoExportScript_Running_v1.9_cn"
local script_name = "录音分段自动导出"

if not reaper.file_exists(export_path) then
  reaper.RecursiveCreateDirectory(export_path, 0)
  reaper.ShowConsoleMsg(string.format("[%s] 导出目录不存在。已创建: %s\n", script_name, export_path))
end

if reaper.GetExtState("ReaScript", g_state_key) == "1" then
  reaper.DeleteExtState("ReaScript", g_state_key, false)
  reaper.ShowConsoleMsg(string.format("[%s] 收到停止信号。脚本即将终止。\n", script_name))
  return
end

reaper.SetExtState("ReaScript", g_state_key, "1", false)

function OnExit()
  reaper.DeleteExtState("ReaScript", g_state_key, false)
  reaper.ShowConsoleMsg(string.format("[%s] 脚本已终止并清理完毕。\n", script_name))
end
reaper.atexit(OnExit)


-- [ 主逻辑 ] --
local segment_start_time = -1
local is_recording_segment_active = false
local is_busy = false

-- 解析用户配置的轨道选择字符串
function ParseTrackSelection(selection_str)
  if selection_str:lower():match("^%s*all%s*$") then return "all" end
  local tracks_to_include = {}
  for part in selection_str:gmatch("([^,]+)") do
    part = part:match("^%s*(.-)%s*$") -- Trim whitespace
    local start_num, end_num = part:match("^(%d+)%s*-%s*(%d+)$")
    if start_num then
      for i = tonumber(start_num), tonumber(end_num) do
        tracks_to_include[i] = true
      end
    else
      local num = tonumber(part)
      if num then tracks_to_include[num] = true end
    end
  end
  return tracks_to_include
end

function GetTracksToExport()
  local selected_tracks = ParseTrackSelection(tracks_to_export)
  local final_tracks = {}
  local track_count = reaper.CountTracks(0)
  
  for i = 0, track_count - 1 do
    local track = reaper.GetTrack(0, i)
    if track and reaper.ValidatePtr(track, "MediaTrack*") and reaper.GetMediaTrackInfo_Value(track, "I_RECARM") == 1 then
      local track_number = reaper.GetMediaTrackInfo_Value(track, "IP_TRACKNUMBER")
      if selected_tracks == "all" or (type(selected_tracks) == "table" and selected_tracks[track_number]) then
        table.insert(final_tracks, track)
      end
    end
  end
  return final_tracks
end

function ProcessExportAndResume(start_time, end_time, should_resume)
  reaper.ShowConsoleMsg(string.format("[%s] 开始导出时间段: %.2fs 至 %.2fs\n", script_name, start_time, end_time))
  
  local tracks_for_export = GetTracksToExport()
  if #tracks_for_export == 0 then
    reaper.ShowConsoleMsg(string.format("[%s] 未找到符合条件的已录音准备轨道用于导出。\n", script_name))
    is_busy = false
    -- 如果没有轨道要导出，但应该继续录音，则立即继续
    if should_resume and reaper.GetExtState("ReaScript", g_state_key) == "1" then
        reaper.ShowConsoleMsg(string.format("[%s] 继续录音...\n", script_name))
        reaper.SetEditCurPos(end_time, true, false)
        reaper.Main_OnCommand(1013, 0)
    end
    return
  end

  reaper.Undo_BeginBlock()
  reaper.PreventUIRefresh(1)
  
  local originally_selected_tracks = {}
  for i = 0, reaper.CountSelectedTracks(0) - 1 do
    local t = reaper.GetSelectedTrack(0, i)
    if t and reaper.ValidatePtr(t, "MediaTrack*") then table.insert(originally_selected_tracks, t) end
  end
  
  local timestamp = os.date("%Y%m%d-%H%M%S")
  
  for _, track in ipairs(tracks_for_export) do
    if track and reaper.ValidatePtr(track, "MediaTrack*") then
      local track_number = reaper.GetMediaTrackInfo_Value(track, "IP_TRACKNUMBER")
      local _, track_name_raw = reaper.GetTrackName(track, "")
      
      local track_identifier
      if track_name_raw == "" or track_name_raw:match("^Track %d+$") then
        track_identifier = "Ch" .. track_number
      else
        track_identifier = track_name_raw:gsub('[\\/:*?"<>|]', '_') -- 过滤非法字符
      end
      
      local filename_base = string.format("%s-%s-%s", file_prefix, timestamp, track_identifier)
      
      reaper.SetOnlyTrackSelected(track)
      
      reaper.GetSetProjectInfo_String(0, "RENDER_FILE", export_path, true)
      reaper.GetSetProjectInfo_String(0, "RENDER_PATTERN", filename_base, true)
      reaper.GetSetProjectInfo_String(0, "RENDER_FORMAT", render_format_code, true)
      reaper.GetSetProjectInfo(0, "RENDER_BOUNDSFLAG", 0, true)
      reaper.GetSetProjectInfo(0, "RENDER_STARTPOS", start_time, true)
      reaper.GetSetProjectInfo(0, "RENDER_ENDPOS", end_time, true)
      reaper.GetSetProjectInfo(0, "RENDER_SETTINGS", 2 | 128, true)
      
      reaper.Main_OnCommand(42230, 0)
      
      reaper.ShowConsoleMsg(string.format("  - 已导出轨道 '%s' 至 %s\\%s%s\n", track_identifier, export_path, filename_base, file_extension))
    end
  end
  
  reaper.Main_OnCommand(40289, 0)
  for _, t in ipairs(originally_selected_tracks) do
    if t and reaper.ValidatePtr(t, "MediaTrack*") then
      reaper.SetTrackSelected(t, true)
    end
  end
  
  reaper.PreventUIRefresh(-1)
  reaper.Undo_EndBlock("自动分段导出录音", -1)

  reaper.ShowConsoleMsg(string.format("[%s] 导出完成。\n", script_name))

  if should_resume and reaper.GetExtState("ReaScript", g_state_key) == "1" then
    reaper.ShowConsoleMsg(string.format("[%s] 继续录音...\n", script_name))
    reaper.SetEditCurPos(end_time, true, false)
    reaper.Main_OnCommand(1013, 0)
  else
    reaper.ShowConsoleMsg(string.format("[%s] 不继续录音。\n", script_name))
  end
  
  is_busy = false
end

function MainLoop()
  if reaper.GetExtState("ReaScript", g_state_key) ~= "1" then return end
  if is_busy then reaper.defer(MainLoop); return end

  local play_state = reaper.GetPlayState()
  
  if (play_state & 4) == 4 then
    local current_pos = reaper.GetPlayPosition()

    if not is_recording_segment_active then
      segment_start_time = current_pos
      is_recording_segment_active = true
      reaper.ShowConsoleMsg(string.format("[%s] 录音开始。新片段起始于 %.2fs。\n", script_name, segment_start_time))
    end
    
    if current_pos - segment_start_time >= export_interval_sec then
      is_busy = true
      local export_start = segment_start_time
      local export_end = current_pos
      
      reaper.Main_OnCommand(1016, 0)
      
      reaper.defer(function() ProcessExportAndResume(export_start, export_end, true) end)
      
      is_recording_segment_active = false 
    end
    
  elseif (play_state & 4) == 0 and is_recording_segment_active then
    is_recording_segment_active = false
    is_busy = true
    
    local export_start = segment_start_time
    local export_end = reaper.GetCursorPosition()
    
    if export_end > export_start then
      reaper.ShowConsoleMsg(string.format("[%s] 用户停止录音。正在导出最后一个片段。\n", script_name))
      reaper.defer(function() ProcessExportAndResume(export_start, export_end, false) end)
    else
      reaper.ShowConsoleMsg(string.format("[%s] 用户停止录音。无新音频可导出。\n", script_name))
      is_busy = false
    end
    segment_start_time = -1
  end
  
  reaper.defer(MainLoop)
end

reaper.ShowConsoleMsg(string.format("[%s] 脚本已启动，由 Vega Sun - Riedel 提供。正在等待录音开始...\n", script_name))
MainLoop()

