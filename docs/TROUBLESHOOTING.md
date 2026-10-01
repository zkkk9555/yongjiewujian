# 常见问题与故障排查

## 为什么另一个对话又安装了一遍工具？

截图中的流程把“当前工作区没有找到它期待的 Python 包”当成了“项目没有安装工具”，随后创建了 `.video-venv` 并安装了一套重复包。常见原因有：

1. 项目原先没有 `AGENTS.md`、README 和固定工具路径；
2. 对话只检查了系统 Python，而没有检查 `.video-tools\venv\Scripts\python.exe`；
3. 对话自己拼 FFmpeg 路径，没有跑预检拿解析结果（早期版本还需要解析 WinGet 符号链接，该目录现已删除）；
4. 每个任务把模型缓存放在自己的目录，误把“模型未在本任务目录”当成“模型未下载”。

正确做法是先运行：

```powershell
& 'C:\Project\永劫无间\scripts\check_video_environment.ps1'
```

然后**以它的输出为准**：Python 从预检打印的路径取，FFmpeg 同样从预检取，不要自己拼。只有用户明确要求修复或安装时，才改变工具环境。

每次任务还必须使用统一的输出根目录：

```text
C:\Project\永劫无间\123\<编号>.<素材文件名>
```

不要因为新对话启动，就把同一任务的结果写到 `video_edit_*` 或其他临时根目录。所有任务结果直接写入 `123\<编号>.<素材文件名>`。

## “FFmpeg 已存在，但普通沙箱不能执行”是什么意思？

> **2026-09-29 更新：下面这套 WinGet 符号链接的说法已经作废。** 现在跑预检拿路径即可。
>
> 更正一处旧描述：那个 `Links\` 目录**并没有被整体删除**，实测它仍在，只是里面不再有
> `ffmpeg.exe` / `ffprobe.exe`（只剩 bun / bunx / jq / rg / uv / uvw / uvx 七个链接）。
> 真正被卸载的是它背后的 `Gyan.FFmpeg_*` WinGet 包目录。结论不变：那儿没有 FFmpeg，
> 现存可用的是 LosslessCut 内置那份。

历史原因是：当时 `ffmpeg.exe` 的 PATH 入口是 WinGet **符号链接**，普通沙箱可能禁止启动链接解析到的真实 EXE，于是出现「`Get-Item` 能看到链接、直接启动失败、换实际目标路径后可运行」的现象。那不是缺 FFmpeg，也不该重装。

**现在的正确做法是不解析任何链接，直接读预检输出：**

```powershell
& 'C:\Project\永劫无间\scripts\check_video_environment.ps1' -Json
```

它会打印出当下实际可用的绝对路径和版本行。当前解析到的是：

```text
C:\Project\永劫无间\.video-tools\LosslessCut\resources\ffmpeg.exe   (n8.0-23)
```

如果预检报 `BLOCKER: FFmpeg/FFprobe`（即没有任何候选目录同时含两个 exe），那才是真缺，届时按 `AGENTS.md §3` 记录缺口并等用户授权，不要自行安装。

## 报“在此系统上禁止运行脚本”，所有 .ps1 都跑不了

```text
无法加载文件 C:\Project\永劫无间\scripts\check_video_environment.ps1，
因为在此系统上禁止运行脚本。请参阅 about_ExecutionPolicies
```

这不是缺工具，也不是权限不足。**成因是文件带 Mark of the Web**（`Zone.Identifier`
附加数据流，来自「压缩包解压 / 下载」），而本机 `CurrentUser` 执行策略是 `RemoteSigned`
——该策略会拒绝运行任何带此标记且未数字签名的本地脚本。`powershell.exe -File` 同样被拦，
只有带 `-ExecutionPolicy Bypass` 的形式能过。

治本（一次性解除标记，**不改动机器执行策略**）：

```powershell
Get-ChildItem 'C:\Project\永劫无间' -Recurse -File |
  Where-Object { $_.FullName -notlike '*\.video-tools\*' } |
  Unblock-File
```

单次绕过：

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File 'C:\Project\永劫无间\scripts\check_video_environment.ps1'
```

项目重新解压后标记会回来，需重跑上面那条 `Unblock-File`。
两个 bash 脚本内部本来就用 Bypass 形式调 PowerShell，所以 bash 链路不受影响。
详见 `docs/TOOLS.md`「运行 .ps1 脚本：Mark of the Web 陷阱」。

## 脚本里的中文全变乱码 / 找不到带中文的路径

Windows PowerShell 5.1 读 `.ps1` 文件时，**没有 BOM 就按系统 ANSI 码页解码**。
文件存成「UTF-8 无 BOM」时，里面每一个中文字符都会被读坏，典型症状：

```text
无法加载文件 ...build_fixture.ps1 ...   或者   路径 C:\Project\????  明明存在却报找不到
```

项目根路径本身就含中文（`C:\Project\永劫无间`），所以这条几乎必然踩到。

**规则**：

- **含中文的 `.ps1` 一律存为 UTF-8 with BOM。** 纯 ASCII 的脚本存不存 BOM 都无所谓。
- 已经存错的补救（不用重开编辑器）：

  ```powershell
  $f = 'C:\Project\永劫无间\scripts\你的脚本.ps1'
  $t = [System.IO.File]::ReadAllText($f, (New-Object System.Text.UTF8Encoding $false))
  [System.IO.File]::WriteAllText($f, $t, (New-Object System.Text.UTF8Encoding $true))   # $true = 加 BOM
  ```

- 自检：`$b=[System.IO.File]::ReadAllBytes($f); $b[0] -eq 0xEF -and $b[1] -eq 0xBB -and $b[2] -eq 0xBF`
- **更省事**：干脆让源码全用 ASCII（注释也用英文），这样存不存 BOM 都对。
  项目 `scripts\` 下的常驻脚本现在都是纯 ASCII 或带 BOM。

**预检会自动查这一条**：`check_video_environment.ps1` 每次都会扫 `scripts\*.ps1`，
发现"含非 ASCII 字节却没有 BOM"就报 `[WARN] script encoding` 并点名文件。

**它真的会造出垃圾目录**：2026-09-29 就发生过一次——一个 UTF-8 无 BOM 的测试脚本里写了
`C:\Project\永劫无间\...`，被读成 `C:\Project\<乱码名>\`，整棵目录树（12 个空目录）建到了项目外面。
码位可证：UTF-8 的 `永劫无间`（12 字节）按 GBK 解码正好是那 6 个乱码字符。

**清理方法**：不要手打乱码名字（手打也会被搞坏，可能再造一个）。按内容特征识别真项目，
删掉不是真项目的那些：

```powershell
$dirs = Get-ChildItem -LiteralPath 'C:\Project' -Directory -Force
$junk = $dirs | Where-Object {
    -not ((Test-Path (Join-Path $_.FullName 'AGENTS.md')) -and
          (Test-Path (Join-Path $_.FullName '.video-tools')))
}
$junk | ForEach-Object { Remove-Item -LiteralPath $_.FullName -Recurse -Force }
```

预检的 `[PASS] no stray dirs beside project` 就是按这个逻辑判断的，所以这类垃圾以后当场会被点名。

本项目实例：
- `scripts\cleanup_after_master.ps1` 产出中文清理日志，初版无 BOM 导致日志乱码，已加 BOM 并核对码位。
- `scripts\check_task_hygiene.ps1` 的中文全在注释里，无路径字面量，功能没受影响，但注释读不了，已加 BOM。
- 任务 13.849 目录下另有 9 个历史辅助脚本（`shots\*\mkc_*.ps1`、`cache\validate_ps1.ps1`）同样无 BOM。
  它们是任务证据，**未改动**；只在被重跑时才会暴露该风险。

> 顺带：`ffmpeg` / `git bash` 这类外部程序不受影响——它们按 UTF-8 读。
> 受影响的只有 PowerShell 读 `.ps1` 源码这一条路径。

## GPU 转写报 “Library cublas64_12.dll is not found”（已解决，2026-09-29）

> 832 当时就踩过，症状与临时绕法见 `.scratch\run-832\issues\01-run-report.md` 第 2 条。现已按那张单子自己提的要求做进共享入口。

```text
RuntimeError: Library cublas64_12.dll is not found or cannot be loaded
```

**不是 DLL 缺失**——它就在 `venv\Lib\site-packages\nvidia\cublas\bin\cublas64_12.dll`，实测在。
成因是 CTranslate2 在 C++ 里用 `LoadLibraryA` 加载 cuBLAS/cuDNN，**那条路径只认 PATH**，
不认 Python 3.8+ 的 `os.add_dll_directory()`。所以新 shell 里一句 PATH 都没设就必然炸。

已修：venv 内放了两个文件，解释器启动时自动生效，**任何脚本都不用再手动设 PATH**：

```text
.video-tools\venv\Lib\site-packages\_project_cuda_dlls.pth   一行 import _project_cuda
.video-tools\venv\Lib\site-packages\_project_cuda.py        prepend 三个 bin 目录 + add_dll_directory
```

自检（不设任何 PATH）：

```powershell
& 'C:\Project\永劫无间\.video-tools\venv\Scripts\python.exe' -c "from faster_whisper import WhisperModel; WhisperModel('large-v3', device='cuda', compute_type='int8_float16', download_root=r'C:\Project\永劫无间\.video-tools\models'); print('CUDA OK')"
```

**别再在转写脚本头部手动 prepend PATH**，那是被取代的临时绕法。若这两个文件被删，
症状就会原样复现——`docs\TOOLS.md`「GPU 需要的 CUDA DLL」一节有完整说明。

## 联系表脚本跑不起来 / 4K 成片脚本起不来

2026-09-29 修复前，`make_contact_sheet.ps1`、`seg_render_master.sh`、`verify_master.sh`
三个脚本各自硬编码了一个已被卸载的 WinGet FFmpeg 路径。症状是 `[FAIL] ffmpeg not reachable`
或 `Invalid argument` 之类的 ffmpeg 找不到类报错。

现在三个脚本都通过 `scripts/resolve_ffmpeg.ps1` 在运行时解析路径。**如果你又看到了新的
硬编码 ffmpeg 路径，那就是回归**——正确做法见 `docs/TOOLS.md`「不要在脚本里硬编码 FFmpeg 路径」。

顺带一提，`seg_render_master.sh` 过去还依赖已失效的 venv `python.exe`、把 840/841/842 的
时间码写死在 `case "$JOB"` 里、并读错了时间线 JSON 的键名（`episodes` 实为 `combat_episodes`）。
现在改为用 `scripts/read_episode_bounds.ps1` 从时间线读边界，**整条 4K 链路零 Python 可跑**。

## 预检报 “python interpreter: EXISTS but CANNOT START”（已解决，2026-09-29）

> **这一条已修复。** 下面保留成因，供追溯；现在预检是 `ok=7 warn=0 blocker=0` 退出码 0。

症状：

```text
[BLOCKER] python interpreter: EXISTS but CANNOT START: ... venv base interpreter is
         MISSING (was): %USERPROFILE%\.cache\codex-runtimes\...\python
```

**不是缺 Python。** 你的机器上一直装着 `%LOCALAPPDATA%\Programs\Python\Python312\python.exe`
（3.12.10，pip 与 venv 模块都正常），只是**不在 PATH 上**——PATH 上的 `python` 是微软商店占位壳，
一敲就提示“请从商店安装”。项目的 2.64 GB venv 里六个包（faster-whisper / scenedetect / auto-editor /
ctranslate2 / librosa / opentimelineio）与 CUDA 运行库**文件全在、版本全对**，只是
`venv\pyvenv.cfg` 的 `home` 指向了一个被系统日常清理删掉的临时缓存解释器，于是启动即失败。

**修法（不需要下载任何东西）**：把 `pyvenv.cfg` 指回系统 Python。同为 CPython 3.12，cp312 ABI 相同，
已装的二进制扩展原地复用。

```powershell
$PY = "$env:LOCALAPPDATA\Programs\Python\Python312\python.exe"
$cfg = 'C:\Project\永劫无间\.video-tools\venv\pyvenv.cfg'
Copy-Item $cfg "$cfg.before" -Force          # 先备份
@"
home = $(Split-Path -Parent $PY)
include-system-site-packages = false
version = 3.12.10
executable = $PY
command = $PY -m venv C:\Project\永劫无间\.video-tools\venv
"@ | Set-Content -LiteralPath $cfg -Encoding UTF8
& 'C:\Project\永劫无间\.video-tools\venv\Scripts\python.exe' --version
```

修完自检：解释器能起 → 六个包能 `import` → `check_video_environment.ps1` 退出码 0 → GPU 转写实跑一次。

**教训已立为铁律**（`AGENTS.md §2`）：环境优先级「项目自带 > 系统正常安装」，
**绝不建在临时 / 缓存 / 工具运行时目录上**。建在系统解释器上的 venv 才扛得住系统清理。

## 预检说环境 OK，但还是跑不起来

新版预检以「能不能真的执行」为判据，不该再出现假绿。如果你看到 `[PASS]` 却实际跑不了，按顺序查：

1. 是不是在看**旧版预检的输出**？旧版只做 `Test-Path`，会把起不来的解释器报成 PASS。确认脚本里有 `Test-InterpreterRuns` 与 `PREFLIGHT_PY_SENTINEL_OK` 字样。
2. 是不是在**子进程**里跑的？PowerShell 调用策略可能拦住 `.ps1`（报「禁止运行脚本」）。用 `Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass` 或 `powershell -ExecutionPolicy Bypass -File ...`。
3. 是不是**控制台编码**把中文路径显示成乱码，导致你误判路径不存在？加 `[Console]::OutputEncoding = [Text.Encoding]::UTF8`。

## 预检报 “python interpreter: EXISTS but CANNOT START”

这是当前项目的**已知真实状态**（2026-09-29），不是新故障：项目 venv 的 `python.exe` 文件还在，但它依赖的基础解释器（原 `~\.cache\codex-runtimes\...`）已被系统清理，所以起不来。

后果：faster-whisper / PySceneDetect / Auto-Editor 全部不可用，**字幕做不了**。模型权重本身没丢。

此时走降级路径（纯视觉 + 音频活动信号，先出无字幕预览），并在任务目录写明缺口。修复它属于 `AGENTS.md §3` 授权闸口内的动作，**未获用户明确批准前不要重建环境**。

## 为什么系统 Python 说没有 faster-whisper？

因为包安装在项目虚拟环境，不在系统 Python。使用：

```powershell
$VideoPython = 'C:\Project\永劫无间\.video-tools\venv\Scripts\python.exe'
& $VideoPython -c "import faster_whisper, scenedetect; import importlib.metadata as m; print(m.version('faster-whisper')); print(m.version('scenedetect'))"
```

不要因为系统 Python 导入失败就执行 pip 安装。

## Python 包已有，但 GPU 运行失败

按顺序检查：

1. 是否使用了 `.video-tools\venv\Scripts\python.exe`；
2. 是否设置 `device="cuda"`；
3. 是否使用 `int8_float16` 或已验证的计算类型；
4. `.video-tools\venv\Lib\site-packages\nvidia` 下的 CUDA 运行库是否存在；
5. 先运行短音频 smoke test，再处理整段素材。

先记录具体错误，再决定是否需要修复运行库；不要无条件重装 faster-whisper。

## 模型没有下载和工具没有安装不是一回事

faster-whisper 的 Python 包可以已经安装，而 large-v3 模型尚未缓存。检查：

```text
C:\Project\永劫无间\.video-tools\models\models--Systran--faster-whisper-large-v3
```

只有模型目录确实不存在时，才在用户知道会产生下载的情况下下载模型。下载模型不会要求重新安装 faster-whisper。

## Auto-Editor 或 PySceneDetect 的结果不理想

它们提供的是辅助信号：

- Auto-Editor 看到的是音频活动，不理解游戏操作价值；
- PySceneDetect 看到的是画面变化，不理解振刀和拆火；
- 连续战斗中镜头变化可能很少，场景边界不一定是好剪点。

保留它们的分析结果，同时结合音频峰值、字幕、HUD/OCR、缩略图和人工复核。不要把某一个工具的输出直接当作最终时间线。

## 出现两层字幕（历史教训，现行已禁烧录）

旧事故原因是 MP4 已烧录字幕、播放器又自动加载同名 `.srt`，或预览生成时烧过一次、后续又用字幕滤镜烧第二次。现行规则已根除该路径：预览与成片一律干净画面，禁烧录、禁内嵌字幕流，字幕只以外挂 SRT 交付。若仍看到双层字，说明某版 MP4 违规带了字幕流或烧录像素字，按门禁直接打回重渲，不修字幕文件。

## 成片体积异常大

先检查是否误用了 `-rc cbr -b:v 150M`。4K60、150 Mbps 的视频每分钟大约会产生 1.1 GB 视频数据，几分钟精选片段也会迅速膨胀。

应先读取源素材平均码率，再使用受控 VBR，例如：

```text
-rc vbr -b:v 18M -maxrate 28M -bufsize 56M
```

实际参数需结合源素材质量和目标平台调整。

## 单轮一次提交超过 50 张图片导致会话作废

上游单次请求携带的图片总数上限是 50 张（累计口径：历史已看图 + 本轮新增的全部图片工具加总），与模型无关。曾因一次性提交 53 张导致上游返回失败、当前会话无法继续，只能换新窗口；`sess_03bfff9d` 则因每批 5 张小批量多轮累加超 50 同样作废。

看图前必须先用 `ls`/`dir` 数好数量并写出数字，再运行 `scripts\check_image_budget.ps1 -ImageDir <缩略图目录> -AlreadySeen <历史已看数>` 打印分轮计划；总数 >50 或累计会超 50，必须拆成多轮。单轮新增不超过 10 张，常规每批 4–10 张；超过 10 帧优先用 `scripts\make_contact_sheet.ps1` 把联系表拼成一张再看；每轮先写结论，下一轮按累计口径调小预算后再继续。完整口径见根目录 `IMAGE_LIMIT.md` 与 `AGENTS.md §9`。

## PowerShell 脚本中文路径乱码（832 v2 修复沉淀）

无 BOM 的 UTF-8 `.ps1` 在 Windows PowerShell 5.1 下中文路径会读乱，导致
ffmpeg 报 `Error opening input: No such file or directory`（文件实际存在）。
修复：ps1 统一存为 UTF-8 with BOM（任务内可用 venv python 重写：
`Path(ps1).write_text(Path(ps1).read_text(encoding='utf-8'), encoding='utf-8-sig')`）。
`render_preview_v2.ps1` 已按此保存；应急时也可用 Bash 直接调 ffmpeg 绕开。

## PowerShell 管道会把「数组的数组」拆平（2026-09-30，修 `excluded_inside` 时踩到）

把「若干个 `(start, end)` 数对」收进 `ArrayList`，再 `| Sort-Object { $_[0] }`：

```powershell
$holes.Add(@($hs, $he))          # 装的是一个 Object[]
foreach ($h in ($holes | Sort-Object { $_[0] })) { ... }
```

**结果是错的，而且是静默的错**：管道遇到「元素本身是数组」的集合会**自动拆平**，
一个洞变成两个独立的标量，于是 `$h[1]` 变成 `$null`、比较全部落空。表现为：

- 分段数变多、出现重复切片（`S=2269 E=2322.2` / `S=2269 E=2338` / `S=2269 E=2346.4`）
- `PROGRAM` 虚高（1228.5，实际应为 1090.5）
- 想拿它去索引会直接抛 `NullReferenceException`

**修法：用 `PSCustomObject` 承载，不要用裸数对。** 对象不会被管道拆平：

```powershell
[void]$holes.Add([PSCustomObject]@{ Start = $hs; End = $he })
foreach ($h in ($holes | Sort-Object Start)) { $h.Start; $h.End }
```

相关第二个坑：**`$list[0][1] = $x`（对 `ArrayList` 元素做嵌套索引器赋值）在 5.1 上不可靠**，
同样抛 `NullReferenceException`。改用两个平行的 `ArrayList`（各存 double），或先取出来改好再 `Add` 回去。

> 通用教训：本项目 `scripts\*.ps1` 里的**中文/结构化数据**一律用
> `[System.IO.File]::ReadAllText(..., [System.Text.Encoding]::UTF8)` 显式读，
> 集合遍历一律用对象或标量，不要用「数组的数组」。

## `qa_gate.py` 报 `preview_duration FAIL`，但预览其实是对的（2026-09-30 已修）

**症状**：`measured` 比 `threshold` 少几十秒，`status: NOT_FROZEN`，Agent 因此反复重渲。

**根因**：节目时长的公式漏了 `excluded_inside`（段内挖洞）。
`qa_gate.py` 曾用 `Σ(source_end − source_start)`，**不扣洞**，于是对着一个正确
扣洞渲出来的预览报 FAIL。861 v4 实例：实测 1090.5 s、门禁期望 1119.4 s、
差值 28.9 s **恰好等于**时间线声明的挖洞总长。

**判定这类 FAIL 是不是误报，三步**：

1. `ffprobe -show_entries format=duration` 直接量成片，不信任何报告的自报值。
2. 看 `timeline\program_map_vN.json` 头部 `program_seconds_total` —— **时间线自己知道真实节目时长**。
3. 手算 `Σ(end − start) − Σ(hole.end − hole.start)`，与前两步对账。

三者一致就说明**渲染是对的、门禁算错了**，别去改时间线。规则现已写进
`skills/naraka-highlight-studio/references/complete-combat-roughcut.md`
（`excluded_inside`：段内挖洞与节目时长公式），两处实现由
`scripts\test_insegment_holes.sh` 锁一致性、`scripts\test_hole_render_e2e.sh` 做端到端验证。

## `verify_master.sh` 报 `full decode did not exit 0`，但母版完全正常（2026-09-30 已修）

**症状**：`[FAIL] full decode did not exit 0`，而手工 `ffmpeg -i out.mp4 -f null -` 退出码是 0。

**根因**：解码命令硬写了 `-map 0:a:0`。**母版没有音轨时 ffmpeg 无法解析该 map**：

```
Stream map '' matches no streams.
Failed to set value '0:a:0' for option 'map': Invalid argument
DECODE_EXIT=127
```

游戏实录通常有音轨所以平时不触发，但这是**同一类病**：门禁比真相更严，
把一个完全正常的产物判成 FAIL。已改为**先探测有没有音轨再决定是否 map**
（日志会打 `decode_map=video` 或 `decode_map=video+audio`）。

> 同类教训：门禁断言的东西必须**宽于或等于真相**，不能严于真相。
> 同一次修复里还发现 `read_episode_bounds.ps1` 初版对**重叠的洞**报 FAIL、
> 而 PowerShell 侧静默合并照渲——门禁拦住了一个渲染器能正常处理的时间线。
> 现在两边都按并集合并，并由测试锁住。

---

# 864 沉淀的三条技术性错误（2026-10-01，与剪辑判断无关但都真实发生过）

这三条的共同点：**都产生了一个看起来很确定的假结论**，而且被写进了冻结件。原件在
`docs\lessons\2026-10-01_864-审片反馈与教训.md` §7。

## T2 · `shots\segN\hd\tXXXX.0.jpg` 的文件名秒点有系统性 +0.4667 s（+28 帧）偏移

**现象**：按文件名里的秒点去核对边界帧，结果每一条都对不上，恒定偏 **+28 帧**。
两帧独立复核，偏移完全一致 —— 这不是随机误差，是系统性的。

**结论**：**该套帧不能作为秒点真值。** 要定位某一秒，抽帧必须用直接 `-ss`，
或按帧号算（`fps=60` 时第 N 帧 = `N/60` 秒），不要拿文件名里的浮点数当真。

**为什么危险**：偏移是恒定的，所以**看起来像是"我算错了边界"而不是"帧的命名不可信"**——
人会去调时间线，而真正该怀疑的是取证工具本身。

## T3 · `blackdetect` 误用 `-af`，日志里的"零命中"是假的

**现象**：想查黑帧，跑了 `blackdetect`，输出"零命中"，于是写进冻结件表说"无黑帧"。

**真相**：`-af` 是**音频**滤镜路径，`blackdetect` 是**视频**滤镜，filtergraph 直接报错退出。
**报错退出的非零退出码被吞了，日志里留下一个空文件，"零命中"就是这么来的。**

**两条规矩**：
1. 视频滤镜用 `-vf`，音频滤镜用 `-af`（`silencedetect` / `astats` 才是 `-af`）。
2. **任何检测日志生成后，必须逐段确认它非空。** 空日志 = 工具没跑起来 = 结论无效。
   和 `verify_master.sh` 的 `decode_exit` 同一个道理：先证明工具跑过了，再读它的结论。

## T1 · 程序化"红色像素检测"判定有无敌方血条，被落日色调骗过

**现象**：脚本按"画面里有敌方红条"筛可疑段，命中就去质疑审片员。

**真相**：4K 逐像素复核证明那些红段是 —— **落日粉紫天空 `BGR(174,177,228)`**、
紫色/品红护甲条、妖刀进度条、播报栏。

**结论**：**凡判"有敌方红条"必须上 4K 目视复核。** 这类画面的落日色调 + 品红 HUD
会稳定骗过阈值检测，不是调阈值能解决的。

## 通用教训：门禁与自动化结论，严于真相就是错

这三条和 `preview_duration` 那条是**同一个病**：工具/门禁断言的东西比真相更严，
于是把一个正确的东西判成错的。判断标准始终是——

> **断言必须宽于或等于真相，不能严于真相。**

自动化结论可疑时，上 4K 目视复核（§5「裁决独立于执行者」：执行者与审片员冲突时，
需要的是第三方裁决，不是谁更自信）。
---

# 已知未修的工具缺陷（登记以免丢失，2026-10-01）

以下缺陷已被发现并分析过，但**当时没有修**——不是没看见，是修它会改变已冻结任务的
历史判定结论，属于「改动环境 / 扩大范围」，需要你拍板。登记在这里，别让它随任务目录
一起消失。

## `qa_gate.py` 的 `subtitle_overlap` 可能拿错了时间轴

**发现来源**：任务 863 验收员独立复现。

**现象**：门禁只报了 **1 处**字幕重叠，验收员独立算出的是 **4 处**。
不是门禁算错了数，是它**只报了首处就停**。

**根因**：`subtitle_overlap` 拿**节目时间（program）**的字幕区间去比
**源时间（source）**的 episode 边界。跨切点时两个坐标系对不齐，
本任务实测恰好 0 条命中，所以门禁显示「无重叠」——但同一份共享脚本换个素材就会误报或漏报。

**正确口径有两种**，取决于这条检查想验什么：

| 口径 | 含义 |
|---|---|
| `--subtitle-axis program` | 字幕按节目时间对齐后，检查相邻字幕是否重叠/断裂 |
| `--subtitle-axis source` | 字幕换算回源时间后，与 episode 边界比对 |

**为什么没修**：该脚本被 849 / 854 / 859 / 860 / 861 等**已冻结任务**依赖，
改默认轴会改写它们的历史结论。算式与影响面记在任务 863 的
`reports\qa_gate_axis_defect_863.md`。

**待办**：给 `qa_gate.py` 加显式 `--subtitle-axis` 参数（默认保持现状以免影响历史），
并把「只报首处」改成报全部。这样新任务可显式选轴，历史结论不动。

## 「半 ASCII 半乱码」的空壳目录靠人眼很难发现

任务 863 有至少 3 个 Agent 因为看控制台（或听转述）把真乱码目录**误判成**
「兄弟项目 / 误报」。其中一个残留叫 `Project` —— **纯 ASCII 名**，
看起来完全像正常目录名，比纯乱码目录隐蔽得多。

已做的：`scripts\sanitize_stray_dirs.ps1` 按**内容**识别真项目（不按名字），
预检的野目录检查升为 BLOCKER。

**待办**：野目录检查可增加「纯 ASCII 目录名」提示项——当前只看内容是否像项目，
一个叫 `Project` 的空目录会被判为「非项目目录」而静默跳过。

---

## 护栏判了「拒绝」却仍然执行了删除（2026-10-01，自查发现）

清项目根垃圾时，我自己写的清理脚本里有这一段：

```powershell
$ok = $true
foreach ($t in $targets) {
    if ($files.Count -gt 0 -and -not $allPyc) {
        Write-Output "[拒绝] 含非字节码文件，不自动删: $($t.Path)"
        $ok = $false; continue
    }
    ...
}
if (-not $ok) { Write-Output "有拒绝项，未全执行" }   # <-- 只是打印了一句

foreach ($t in $targets) { Remove-Item -LiteralPath $t.Path -Recurse -Force }   # <-- $ok 根本没参与判断
```

`bagY.txt` 被护栏判了「拒绝」，脚本打印「未全执行」，**然后照样把它删了**。

**这次结果没错**（它确实是垃圾），但**护栏说了不做却做了，比没有护栏更危险** ——
下一次护栏拦住一个真正不该删的东西时，人会以为脚本没删，结果它删了。

**两条规矩**：

1. **护栏必须真正短路执行**，不能只打印。把删除循环放进 `if ($ok) { ... }`，
   或者对每个目标独立判断 `if (-not $allowed) { continue }`，不要靠一个汇总布尔值。
2. **清理前先说清楚每一项是什么、为什么可删**，把清单摆给用户看，
   删完再报实际结果。这样即使护栏失效，人还能看出异常。

> 同类形态还有本手册前面记的 `-match` 被当成参数名那类**非终止错误**：
> 脚本照样跑完、照样打印 PASS，而真正该执行的那一步从没发生。
> **静默的假成功和静默的假失败一样致命。**