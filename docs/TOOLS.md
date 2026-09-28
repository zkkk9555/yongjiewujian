# 工具基线与固定入口

本文档回答三个问题：工具是否已经安装、应该从哪里调用、遇到入口异常时应该怎么处理。

## 主工具环境

| 项目 | 当前固定值 |
|---|---|
| 项目根目录 | `C:\Project\永劫无间` |
| 系统 Python（venv 基座） | `%LOCALAPPDATA%\Programs\Python\Python312\python.exe`（3.12.10） |
| 主 Python（项目 venv） | `C:\Project\永劫无间\.video-tools\venv\Scripts\python.exe` |
| Python 版本 | 3.12.10 |
| faster-whisper | 1.2.1 |
| CTranslate2 | 4.8.1 |
| PySceneDetect | 0.7.1 |
| Auto-Editor | 29.3.1 |
| librosa | 0.11.0 |
| OpenTimelineIO | 0.18.1 |
| CUDA/cuBLAS | `nvidia_cublas_cu12` 已安装 |
| CUDA/cuDNN | `nvidia_cudnn_cu12` 已安装 |
| 模型缓存 | `C:\Project\永劫无间\.video-tools\models` |

主环境同时提供：

```text
C:\Project\永劫无间\.video-tools\venv\Scripts\auto-editor.exe
C:\Project\永劫无间\.video-tools\venv\Scripts\scenedetect.exe
```

> **venv 基座必须是系统 Python（`AGENTS.md §2` 铁律）。**
> 这个 venv 曾在 2026-09-29 之前绑在一个临时缓存目录的解释器上（`~\.cache\codex-runtimes\...`），
> 被系统日常清理删除，结果 2.64 GB 的包文件全在、六个 dist-info 全对、`import` 却一个都跑不了。
> 修法不是重装，而是把 `venv\pyvenv.cfg` 的 `home` / `executable` 指回上表的系统 Python——
> 同为 CPython 3.12，cp312 ABI 相同，已装的二进制扩展（ctranslate2 / numpy / av / tokenizers）直接复用。
> 修完预检 `ok=7 warn=0 blocker=0`，GPU 转写实跑通过。
> **以后新建任何环境，先确认基座是系统 Python，不要挂在临时/缓存/工具运行时目录上。**

`librosa` 用于 BGM 的 BPM、节拍和起音分析；`OpenTimelineIO` 用于保存可重建的多轨编辑时间线。它们是生产级高质量工作流新增的共享依赖，不需要按任务重复安装。

## 项目内 skills（随项目走，不用用户级）

下面两个已随项目存放在 `C:\Project\永劫无间\skills\`，不再读取任何用户级 skill 目录：

```text
C:\Project\永劫无间\skills\ffmpeg-analyse-video-skill\SKILL.md
C:\Project\永劫无间\skills\ffmpeg-video-editor\SKILL.md
```

它们提供“如何分析视频”和“如何构造 FFmpeg 剪辑命令”的操作规范；项目内的 `.video-tools\venv` 提供实际执行所需的 Python 工具。未来对话直接按项目路径读取并使用这些 skill，再调用项目固定环境。`autopilot` 及其 25 个子 skill 同样已随项目存放（`skills\autopilot\` 等），按项目路径直接读取，不再依赖用户级目录。

## FFmpeg 和 FFprobe

**不要硬编码 FFmpeg 路径。** 跑预检，读它解析出来的绝对路径：

```powershell
& 'C:\Project\永劫无间\scripts\check_video_environment.ps1' -Json
```

候选顺序（先存在且**同时**含 `ffmpeg.exe` 与 `ffprobe.exe` 者胜出）：

| 顺序 | 目录 | 状态（2026-09-29 实测） |
|---|---|---|
| 1 | `…\Microsoft\WinGet\Links` | **已整体删除**，保留仅为将来装回时兼容 |
| 2 | `C:\Project\永劫无间\.video-tools\LosslessCut\resources` | **当前唯一可用**，n8.0-23 |
| 3 | `C:\Project\永劫无间\.video-tools\ffmpeg\bin` | 不存在 |
| 4 | `C:\ffmpeg\bin` | 不存在 |
| 5 | `C:\Program Files\ffmpeg\bin` | 不存在 |
| 6 | PATH | 无 |

实测解析结果：

```text
FFmpeg  = C:\Project\永劫无间\.video-tools\LosslessCut\resources\ffmpeg.exe   (n8.0-23)
FFprobe = C:\Project\永劫无间\.video-tools\LosslessCut\resources\ffprobe.exe  (n8.0-23)
```

> 历史注记：早期文档让你读 WinGet 符号链接的 `Target`。那条路径已失效，照做会拿到空值并卡住。**不要再解析符号链接**，直接用预检输出。

### 不要在脚本里硬编码 FFmpeg 路径

候选表与解析逻辑只有一处存放：`scripts\resolve_ffmpeg.ps1`。

- **PowerShell 脚本**里 dot-source 后调用函数：

  ```powershell
  . (Join-Path $PSScriptRoot 'resolve_ffmpeg.ps1')
  $pair = Resolve-FfmpegPair
  if (-not $pair) { ... }   # $pair.Ffmpeg / $pair.Ffprobe / $pair.Directory
  ```

- **bash 脚本**里取路径（输出 `KEY=VALUE`，退出码 0/1）：

  ```bash
  RESOLVE_OUT=$(powershell.exe -NoProfile -ExecutionPolicy Bypass \
    -File "$(cygpath -m "$PS_DIR/resolve_ffmpeg.ps1")" -Emit)
  FF=$(printf '%s\n' "$RESOLVE_OUT" | sed -n 's/^FFMPEG=//p')
  ```

  交给 ffmpeg 前用 `cygpath -m` 转成 Windows 形式；`-Emit` 已强制 UTF-8 输出，
  项目根路径含中文也不会乱码。

**不要**在任何脚本里写死 ffmpeg 路径。`make_contact_sheet.ps1`、`seg_render_master.sh`、
`verify_master.sh` 三个脚本都曾各自硬编码 WinGet 路径，而那份安装早已被卸载，
导致联系表工具与整套 4K 成片链路全部无法运行。详见
`.scratch/fix-dead-ffmpeg-and-4k-render-path/spec.md`。

## 运行 .ps1 脚本：Mark of the Web 陷阱

本项目文件若来自压缩包或下载，会带 `Zone.Identifier`（Mark of the Web）。
本机 `CurrentUser` 执行策略是 `RemoteSigned`，PowerShell 会**拒绝运行任何带此标记且未签名的本地脚本**：

```text
无法加载文件 ...check_video_environment.ps1，因为在此系统上禁止运行脚本
```

三个处理办法，任选其一：

1. **一次性解除标记（推荐，治本）**：

   ```powershell
   Get-ChildItem 'C:\Project\永劫无间' -Recurse -File |
     Where-Object { $_.FullName -notlike '*\.video-tools\*' } |
     Unblock-File
   ```

   这只删文件的来源标记，**不改动机器执行策略**。项目重新解压后需重跑一次。

2. **单次调用加 Bypass**：

   ```powershell
   powershell.exe -NoProfile -ExecutionPolicy Bypass -File 'C:\Project\永劫无间\scripts\check_video_environment.ps1'
   ```

   所有 bash 脚本内部调 PowerShell 时用的就是这个形式，所以 bash 链路不受影响。

3. `Set-ExecutionPolicy` 改机器策略——**本项目不采用**，属于对机器的全局改动，需用户明确授权。

沙箱里如果出现“拒绝访问”或“没有应用程序与此操作的指定文件有关联”，那是执行权限问题，不是安装缺失：改用预检解析出的实际目标，并让本地执行环境对该命令请求提升权限。不要执行 `winget install` 或重新下载 FFmpeg。

## faster-whisper 和 GPU

当前 GPU 运行方案：

```python
WhisperModel(
    "large-v3",
    device="cuda",
    compute_type="int8_float16",
    download_root=r"C:\Project\永劫无间\.video-tools\models",
)
```

说明：

- `faster-whisper` 是 Python 包，不是语音音色包。
- 模型缓存和 Python 包是两件事；模型已经下载时，不需要再次安装包。
- 它负责语音识别，不天然识别说话人身份，也不会自动生成配音音色。
- 人声/游戏音效筛选来自 VAD、置信度、音频轨道和后处理规则。
- 如果 OBS 把麦克风、队友语音和游戏声音分开录在不同音轨，字幕准确率会明显更高。

### GPU 需要的 CUDA DLL：已做进共享入口，不用手动设 PATH

> 2026-09-29 修复。832 当时踩的就是这个坑，它自己的问题单写着
> 「优化点：这是本轮最大卡点。**应把 PATH 修复做进共享入口**（环境检查脚本提…+ 转写脚本模板头部 + TOOLS/WORKFLOW 文档），
> 而不是每个任务各自踩一遍」。现已按此落地。

**症状**：在一个干净 shell 里直接建 GPU 模型就炸：

```text
RuntimeError: Library cublas64_12.dll is not found or cannot be loaded
```

**成因**（不是 DLL 缺失，文件就在 `site-packages\nvidia\cublas\bin\`）：CTranslate2 是在 C++ 里用
`LoadLibraryA` 加载 cuBLAS/cuDNN 的，那条路径**只认标准 Windows DLL 搜索顺序（即 PATH）**，
不认 Python 3.8+ 的 `os.add_dll_directory()`。所以新开的 shell 一句 PATH 都没设就必然失败。

**已做的处理**（venv 内，任何脚本都自动生效）：

```text
.video-tools\venv\Lib\site-packages\_project_cuda_dlls.pth    一行：import _project_cuda
.video-tools\venv\Lib\site-packages\_project_cuda.py           把三个 bin 目录 prepend 进 PATH 并 add_dll_directory
```

`.pth` 在解释器启动的 site 初始化阶段执行，**早于任何 `import ctranslate2`**，
所以 `WhisperModel(device="cuda")` 拿得到路径。纯增量：nvidia 包不在时什么都不做，也从不删改已有 PATH。

**自检**（不设任何 PATH 跑这条，能建出模型就是好的）：

```powershell
& 'C:\Project\永劫无间\.video-tools\venv\Scripts\python.exe' -c "from faster_whisper import WhisperModel; WhisperModel('large-v3', device='cuda', compute_type='int8_float16', download_root=r'C:\Project\永劫无间\.video-tools\models'); print('CUDA OK')"
```

**不要再在转写脚本头部手动 prepend PATH**——那是 832 的临时绕法，已被共享入口取代。

## PySceneDetect

项目入口：

```text
C:\Project\永劫无间\.video-tools\venv\Scripts\scenedetect.exe
```

它主要提供场景边界和画面变化信号。连续游戏战斗未必会产生理想的场景切点，因此它不能单独决定精彩片段，也不能替代人工审片。

## Auto-Editor

项目入口：

```text
C:\Project\永劫无间\.video-tools\venv\Scripts\auto-editor.exe
```

它主要提供音频活动、静音和低活动片段参考，适合粗筛跑图、等待和长时间无声区间。它不是《永劫无间》动作识别器，不能单独判断振刀、反杀或拆火。

## LosslessCut

项目内便携版：

```text
C:\Project\永劫无间\.video-tools\LosslessCut\LosslessCut.exe
```

它适合人工快速无损取段。自动剪辑主流程以 FFmpeg 时间线为准，LosslessCut 是可选的人工检查工具，不需要为了每次任务重新安装。

## 重复环境说明

旧对话创建的 `C:\Project\永劫无间\.video-venv` 已清理。新任务只使用
`C:\Project\永劫无间\.video-tools\venv`；如果某次对话再次建议创建 `.video-venv`，先回到本文件和环境检查脚本核对共享环境，不要按对话重新安装。
