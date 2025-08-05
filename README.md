# **Reaper Auto-Export While Recording Script**

## **录音时自动分段导出ReaScript脚本**

**Author:** Vega Sun \- Riedel  
**Version:** 1.9  
**Language:** Lua  
A ReaScript for Cockos REAPER that automatically stops, exports, and resumes recording at user-defined intervals. This is ideal for long recording sessions, streaming, or any scenario where you need to periodically save your work as separate audio files without manually interrupting the process.  
一个为 Cockos REAPER 设计的ReaScript脚本。它可以在录音过程中，按照用户设定的时间间隔，自动地停止录音、导出音频片段、然后无缝地继续录音。这个脚本非常适合长时间录音、直播或任何需要将工作成果定期保存为独立音频文件的应用场景，整个过程无需手动干预。

## **Features / 功能特性**

* **Automated Segmentation & Export:** Automatically splits long recordings into smaller, manageable files at a fixed time interval.**自动化分段与导出：** 在录音过程中，按固定的时间间隔自动将长录音分割成小文件。  
* **Seamless Workflow:** The script intelligently handles stopping, exporting, and resuming the recording process to ensure no data is lost.**无缝工作流：** 脚本智能地管理着“停止-导出-继续录音”的整个流程，以确保数据完整性。  
* **Background Operation:** Runs quietly in the background. Simply start recording, and the script takes care of the rest.**后台运行：** 脚本会在后台安静地运行。您只需开始录音，剩下的交给它即可。  
* **Silent Export:** Exports files using your last-used render settings without showing any confirmation dialogs.**静默导出：** 使用您最后一次在渲染窗口中设置的参数进行导出，全程不会弹出任何确认窗口。  
* **Highly Configurable:** Easily set the export path, file prefix, time interval, audio format, and which tracks to export directly within the script file.**高度可配置：** 您可以直接在脚本文件中轻松设置导出目录、文件名前缀、时间间隔、音频格式以及需要导出的轨道。  
* **Smart Filenaming:** Automatically names exported files using the track's name. If a track is unnamed, it defaults to "Ch\[TrackNumber\]".**智能命名：** 自动使用轨道名称来为导出文件命名。如果轨道未命名，则会使用“Ch\[轨道序号\]”的格式。  
* **Easy Toggle:** Run the script once to start it. Run it again to stop it.**轻松开关：** 运行一次脚本即可启动，再次运行则会停止。

## **Installation / 安装方法**

1. In REAPER, go to the Actions menu and select Show action list....在 REAPER 中，点击菜单栏的 Actions \> Show action list...。  
2. In the Actions window, click the ReaScript: New/load... button.在弹出的“Actions”窗口中，点击 ReaScript: New/load... 按钮。  
3. Save the script file with a name like auto\_export\_while\_recording.lua.将脚本文件保存为一个您喜欢的名字，例如 auto\_export\_while\_recording.lua。  
4. Copy the entire code from the .lua file in this repository and paste it into the REAPER's script editor.将本仓库中的 .lua 文件代码完整地复制并粘贴到 REAPER 的脚本编辑器中。  
5. Save the script (Ctrl+S or Cmd+S).保存脚本 (Ctrl+S 或 Cmd+S)。

## **How to Use / 如何使用**

1. **Configure the script:** Open the script in REAPER's editor and modify the settings in the **\[ User Configuration Area \]** section to your liking.**配置脚本：** 在 REAPER 编辑器中打开此脚本，根据您的需求修改 **\[ 用户配置区域 \]** 内的参数。  
2. **Run the script:** Find the script in your Action List and run it. The REAPER console will show a message indicating that the script is running and waiting for recording to start.**运行脚本：** 在 Action List 中找到这个脚本并运行它。REAPER 的控制台会显示一条消息，提示脚本已启动并正在等待录音开始。  
3. **Start Recording:** Arm the tracks you want to record and press the record button in REAPER as you normally would. The script will now automatically handle the export process.**开始录音：** 像往常一样，在 REAPER 中准备好您想录音的轨道并按下录音键。脚本现在会自动开始工作。  
4. **Stop the script:** To stop the script, simply run it again from the Action List. A message will appear in the console confirming that it has been terminated.**停止脚本：** 想要停止脚本，只需在 Action List 中再次运行它即可。控制台会显示消息确认脚本已终止。

## **Configuration / 参数配置**

You can customize the script's behavior by editing these variables at the top of the file:  
您可以通过修改脚本文件头部的这些变量来自定义脚本的行为：

* export\_path: The folder where your audio files will be saved.export\_path: 您希望保存导出文件的文件夹路径。  
* file\_prefix: The prefix for all exported filenames (e.g., "Rec").file\_prefix: 导出文件名的前缀 (例如 "Rec")。  
* export\_interval\_sec: The duration of each recording segment in seconds.export\_interval\_sec: 每个录音片段的时长（单位：秒）。  
* export\_format: The desired audio format. Supported: "mp3", "wav", "flac", "ogg". **Note:** The quality settings (bitrate, sample rate, etc.) are based on the last settings you used for that format in REAPER's Render window.export\_format: 您希望的导出格式。支持："mp3", "wav", "flac", "ogg"。**请注意：** 导出质量（如比特率、采样率等）取决于您最后一次在 REAPER 渲染窗口中为该格式所做的设置。  
* tracks\_to\_export: Specify which tracks to export.tracks\_to\_export: 指定需要导出的轨道。  
  * "all": Exports all armed tracks. (导出所有已准备录音的轨道)  
  * "1,3,5": Exports tracks 1, 3, and 5 only. (仅导出第1、3、5轨道)  
  * "2-5": Exports tracks 2 through 5\. (导出从第2到第5的轨道)

## **How It Works / 工作原理**

The script operates on a "record-stop-export-resume" cycle. When the recording time reaches the specified interval, the script automatically:

1. Stops the recording. This finalizes the audio file on disk.  
2. Immediately queues a background task to export the just-completed segment.  
3. Instantly resumes recording from the exact point it stopped, minimizing downtime.  
4. The export task runs silently in the background while the new segment is being recorded.

该脚本基于一个“录制-停止-导出-继续”的循环工作。当录制时长达到设定的间隔时，脚本会自动：

1. **停止录音**，以确保音频文件被完整地写入磁盘。  
2. 立即将刚刚完成的片段的**导出任务**加入后台队列。  
3. **立刻从停止的位置继续录音**，将录音中断的时间降至最低。  
4. 在新的录音段正在进行的同时，导出的任务会在后台静默执行。

## **Credits / 鸣谢**

* **AI Assistant:** Gemini by Google
