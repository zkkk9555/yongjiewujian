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

**清理方法**：不要手打乱码名字（手打也会被搞坏，可能再造一个）。
只跑 `sanitize_stray_dirs.ps1` 看清单（默认干跑，只打印不删），找出肇事的 `.ps1`
把它重存为 UTF-8 with BOM，确认无用后、人点头后才加 `-Remove`，见 `AGENTS.md §1`。
别自己 `Remove-Item`，也别动清单里“不动”那一栏的任何东西。

预检的 `[PASS] no stray dirs beside project` 就是按这个逻辑判断的，所以这类垃圾以后当场会被点名。
（**注**：2026-10-06 起这条判据收窄为「只认本项目路径的反解乱码」——
项目旁边的其它目录一律 PASS 且不删除，理由见下方「半 ASCII 半乱码」一节末尾的补充。）

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

## 预检报 “python interpreter: EXISTS but CANNOT START”（历史，2026-09-29 前）

> **历史记录**：这是 2026-09-29 修复前的已知状态，现已解决（见上一节）。
> 当前真实状态以预检输出为准，不要凭本节假设工具不可用。

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
`skills/cujian/references/complete-combat-roughcut.md`
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

# 机器读数与仪表的坑（884–890 六局汇总，2026-10-22）

以下都是**已经在交付件上踩过**的仪器/工具问题。共同特征不是判断力差，而是
**仪器测的不是标尺要的东西**，或者**量错了地方**。

## M1 · `squad_state.py` 的几何与配色是按某一个素材写死的

- **890**：直接套用 → 护甲恒 false、健康几乎全 false；更糟的是它的判据（看右侧窗口有没有条像素）
  在该素材上**会漏报**——条从右端往回缩，右窗落在条的**内部**，「只剩 27% 血」也被判成「满」。
- **884**：颜色掩膜把完整的浅灰低阶护甲读成「没有护甲」，于是「第二局之后再也没有满状态秒点」这个
  **假事实**被 9 路报告反复引用，差一步整局的入片点全改错。
- **888**：换素材后默认行坐标直接失效。

⇒ **换素材必须先标定仪表**：3–5 张**人眼确认过**的帧（满 / 部分 / 空 / 整行被 UI 盖住各一张），
结果写成 `reports\squad_state_instrument_<任务>.md`。**没有标定表，不许引用「满状态窗口」。**

## M2 · 护甲通道是系统性假阴性源（889）

`squad_state.json` 的护甲通道在 889 的素材上**整片假阴性**：空甲与「被打光」在几何上分不开，
同一行在不同时刻量到的「满长」还不一样。它会污染全片门禁（`entry_state_full`）。
⇒ **护甲不作判据**：`*_armour_full` 一律记 true 并写明理由；用**血条**当受损见证（挨打必然掉血）。

## M3 · `round()` 的银行家舍入会把每隔一秒的读数串行（888）

队伍曲线与机器信号的对齐键不能用 `round()`——`round(0.5)=0`、`round(1.5)=2`、`round(2.5)=2`，
每隔一秒都串行，对齐结果整段偏一格。⇒ 用 `floor(x+0.5)`，或直接用未取整的浮点键。

## M4 · `squad_dmg`（我方掉条）这个机器通道的原语义是「假命中发生器」（888）

HUD 特效、场景光照变化都会被算成掉条。**不能当伤害证据。**

## M5 · 帧↔秒映射必须实测标定，而且**参照系不能与被测路径共用**（888 / 885 / 883）

用「直接 `-ss T` 抽的帧」当基准去验「编号帧的秒点」= 误差对消的循环论证
（POOL 的 L-052 已被 08 号 Agent 实测推翻，见 POOL 末节）。
标定基准必须用与被测路径无关的参照（`showinfo` 的 pts_time、`-copyts`、或已知帧数反推）。
另：**`fps=1` 的帧号不是秒号**——`showinfo` 记录的是**重标号后的输出 pts**（883 实测）。

## M6 · 切点不在 60fps 帧格上 → 多切一帧（889）

`44.76 × 60 = 2685.6` 不是整数；用 `-t (end−start)` 切时最后一帧会滑过 `end`，
于是**删除区的第一帧进了成片**（观众看到片尾闪一下本该删掉的东西）。
⇒ 渲染器必须把每段起止吸附到帧格：`s_f = ceil(s*60)/60`、`e_f = ceil(e*60)/60`、
帧数 `round((e_f − s_f) * 60)`；吸附后总量与声明值差几十分之一秒，门禁 ±0.3 s 扛得住。
（另：**分段渲染要用精确帧数 `-frames:v N`，不要用 `-t <时长>`**——888 L34-20。）

## M7 · 预览容器的 `start_time` 不是 0（888）

`-ss P` 在硬切点会落到**上一段的尾帧**。做帧级对位时，别拿容器的 0 号帧当节目 0 秒。

## M8 · `map_captions.py` 的相邻间隙逻辑有 bug：会造出 0.000 秒的贴边字幕（890）

「保证相邻字幕有 MIN_GAP」的写法用了 `min()`：当后一条正好从前一条结束处开始时，`min()` 推不动它，
两条字幕贴边（间隙 0.000 秒），门禁 `subtitle_overlap` 报 WARN。
另一个改法（把后一条往后推）会连锁制造新的重叠，最后只能靠丢字幕收场（890 实测从 111 条丢到 44 条）。
⇒ 正确做法是**把相邻的同一段话合并成一条**（文字与时长同步增长，字符/秒比不变），
合并后若超过 MAX_DUR 才裁前一条的尾。890 修好后：75 条、最小间隙 0.080 秒、零重叠、时长 0.92–7.00 秒。

## M9 · `qa_gate.py` 的字幕跨段检查在缺 `program_start`/`program_end` 时会假 FAIL（890 / 888）

它退回用**源时间**比 episode 边界，于是「源 282 边界」会把落在节目 276–283 的那条字幕
误判成「跨切点」。⇒ 时间线每条 episode **必须带 `program_start` / `program_end`**
（用 `episode_geometry` 算，和别处同一套公式）。

## M10 · `program_map` 的 `holes` 字段语义错（继承自 864 的 `build_program.py`）

它填的是**第一段保留区**，不是真正的挖洞（用了 `segments[:-1]`，而真正的洞是相邻保留段之间的空隙）。
后果很严重：**看文件的人会以为源 744–845 被删了，其实那 101 秒在片内。**
工具链不读这个字段，所以渲染与门禁都没受影响——**正因为没人读，它躲过了所有自动检查**。
⇒ 「区间类」字段都要问一句「这个区间的两端是什么意思」；权威源永远是时间线本身。

## M11 · 上一会话留下的代理视频可能是残件（888）

用之前必须 ffprobe 验时长/帧数；残件会让人对着错素材判读。

## M12 · 「`-f concat` 拼块每接缝漏 1 帧 + 逐段漂移」——本项目实测**未复现**（2026-10-22）

889 的指挥层经验写「`-f concat`（demuxer）拼块 = 每个接缝漏 1 帧 + 音画逐段漂移」。
项目正式 4K 路径 `scripts\seg_render_master.sh:177` 用的正是 `-f concat` + `-c copy`。
**2026-10-22 实测 10 份已交付母版（881–890，含 13 段的 887）**：
`nb_frames == duration × 60` 全部 **delta = 0**（无漏帧、无重帧）；
音画漂移恒为 **21 ms（一个 AAC 包）**，**不随段数累加**（13 段的 887 仍是 21 ms）。
⇒ 该说法在已交付件上**没有复现**；`seg_render_master.sh` **不必**因此改
（与 POOL L-057 的结论一致）。真正会漏帧的是 **M6 的切点未吸附帧格**，不是拼块方式。

## M13 · `collect_lessons.ps1` 的「来源键」机制一直是死的（2026-10-22 已修）

**现象**：POOL 里已经补齐了 25 个逐局摘要行（来源列写**任务目录全名**），
脚本仍然报「待升级 695 条，来自 23 个未收录的经验源」——一条都没闭合。

**根因**：`$absorbedSources` 的正则
`\|\s*L-\d{3}\s*\|[^|]*\|\s*([^|]+?)\s*\|` 捕获的是 POOL 的**第 3 列（教训）**，
却被拿去和候选的 `$c.Source`（来源键）比——两边根本不是同一个东西，
于是「来源键」这条机制**从未生效过**。（POOL 列序是 `| # | 来源 | 教训 | 状态 | 吸收去向 |`，
`[^|]*` 吃掉来源列，捕获组落在教训列。）

**修法**：改捕获第 2 列（来源）——
`(?m)^\|\s*L-\d{3}\s*\|\s*([^|]+?)\s*\|`；教训正文另有 `$absorbedTexts` 一路，两条机制互不干扰。

**实证**：修前 **695 条待升级** → 修后 **0 条**；「有 workflow_notes 的」从 21 升到 24
（本轮补写了 854 / 858 / 860 三份）。

## M14 · 经验命名门禁的判据过严，39 条噪声里真错只有 2 条（2026-10-22 已修）

**现象**：卫生门报「命名不合规 39 个」。

**根因**：判据要求文件名**恰好等于** `workflow_notes_<任务目录号>.md`，
把一个任务目录里合法的多份经验（34.889 有 32 份：`_34.md` + `_34_commander*.md` + `_34_seg1..28.md`）
全判成违规——**真正的错只有 2 个**：13.849 里的 `_849.md`、20.863 里的 `_863.md`。

**修法**：判据改**前缀式** `^workflow_notes_<任务目录号>(_.*)?\.md$`；
`check_task_hygiene.ps1` §6 与 `collect_lessons.ps1` 的 `NameOk` 用同一判据；
883 的 5 个 `workflow_notes_segN.md` 改名为 `workflow_notes_29_segN.md`。

**实证**：修后 25 个任务目录跑卫生门 **0 失败**；`collect_lessons.ps1` 的
「命名不合规」计数从 **39 → 0**。

---

# 已知未修的工具缺陷（登记以免丢失，2026-10-01）

以下缺陷已被发现并分析过，但**当时没有修**——不是没看见，是修它会改变已冻结任务的
历史判定结论，属于「改动环境 / 扩大范围」，需要你拍板。登记在这里，别让它随任务目录
一起消失。

## `map_captions.py` 的相邻间隙逻辑会造出 0.000 秒的贴边字幕（2026-10-22 登记）

**发现来源**：任务 890 的字幕员。详见上文 **M8**。
**为什么没修**：该脚本不在本仓（864 沿用的任务内脚本），且已被多个已冻结任务的字幕依赖。
**当时的绕法**：在任务内改用「合并相邻同段话」的局部脚本重排；根因未动。
**待办**：把「相邻间隙保证」改成合并优先（合并 → 超 MAX_DUR 才裁前一条），并给 `subtitle_overlap` 加一条
「间隙 = 0 视为违规」的断言。

## `squad_state.py` 的护甲通道系统性假阴性（2026-10-22 登记）

**发现来源**：任务 889（护甲通道整片假阴性）、890（护甲槽几何不稳、空甲与被打光分不开）。
详见上文 **M2**。**为什么没修**：改它等于改「入片必须满状态」这条门禁的判据口径，
会改写 882 / 883 / 884 / 887 已冻结任务的历史判定。
**当时的绕法**：护甲不作为判据（`*_armour_full` 记 true 并写明理由），改用血条当受损见证。
**待办**：把护甲判据改成「几何 + 颜色双证」，或干脆从 `entry_state_full` 里移除护甲项。

## `program_map` 的 `holes` 字段语义错（2026-10-22 登记）

**发现来源**：任务 890 的复验员（帧级比对钉死）。详见上文 **M10**。
**为什么没修**：`build_program.py` 是 864 沿用的任务内脚本，不在本仓；改了会改写旧任务的 program_map。
**当时的绕法**：890 局部修正 + 把 `excluded_inside` 一并写进 program_map；权威源仍是时间线本身。
**待办**：把 `holes` 改成按「相邻保留段之间的空隙」算，并给 program_map 加一条字段语义自检。

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

**2026-10-06 补：判据换掉了，而且这次是按"删错东西"的方向补的。**

上面两条措施解决的是「漏报」（真乱码被当成误报放过），但引入了更糟的反向问题：
判定条件是「不是本项目」，而 `C:\Project\` 是**共享父目录**——用户的其它项目、
随手新建的空文件夹，全都满足「不是本项目」。于是

- 预检对每一个兄弟目录报 BLOCKER（含真项目 `云山巨城`），假警报；
- `sanitize_stray_dirs.ps1 -Remove` 对 `C:\Project\` 下**每一个**目录
  `Remove-Item -Recurse -Force`，**照文档执行就会删掉活着的其它项目**。

新判据是**反解证明**（`scripts\mojibake_guard.ps1`，预检与清理脚本共用）：
把目录名按 ANSI 编码回字节、再按**严格** UTF-8 解码，结果必须**恰好等于 `永劫无间`**
才算本项目的乱码。它不是"像不像"，是来源证明——别的名字不可能解出这个串。

护栏三条，任一不过即**不删**：

1. 反解命中本项目名
2. 不是项目本体
3. **不含 `.git`** —— 真项目有版本库，无版本库的那个才可能是产物

第 3 条理论上多余（没人会特意把项目建成乱码名），但删除沙箱外的东西不可逆，
便宜的保险值得。**空目录同样不删**——用户随时会新建空文件夹，那不是垃圾。

回归：`scripts\test_mojibake_guard.ps1`（36 例）。其中 8 例是**端到端**——
拿真脚本带 `-Remove` 跑一遍 fixture，然后逐个断言 `云山巨城`、空文件夹、
无关项目、带 `.git` 的乱码名目录**全都还在**。分类测试全绿但删除路径另有行为，
这种事发生过，所以必须真跑一次。

> fixture 建在 `.scratch\` 下，**绝不在 `C:\Project\` 里造测试目录**——
> 那本身就是我们要防的 bug。

**2026-10-07 补：第二种坏法，双见证 + 只删空壳。**

10-07 剪完 23/26 两个视频，`C:\Project\` 下冒出两个新目录。第一个是老熟人
（`U+59D8 U+7A3F U+59ED U+93C3 U+72BB U+68FF`，反解命中，一档整树删，6 项 0 B）；
第二个是新东西：`U+6C38 U+526B U+65E0 U+95F4`——"劫"是 **U+526B**，GBK 里没有这个字。

U+526B 不在 GBK 里，意味着它**不可能是 GBK 误读的产物**（GBK 解不出自己没有的字），
反解判据对它注定无解。渲染图确认三字肉眼几乎无差（U+52AB / U+526B / U+52BE
在宋体下只有末笔方向之别），所以这是**上游字形损坏**，不是本机 BOM bug——
护栏修 BOM 修不到它头上，别指望"找到肇事 .ps1"这一条对它成立。

走**双见证**（`Test-NameCorruptDir`）：（A）树里带着 `123\` 克隆骨架，
（B）树里带着克隆证据（`123\<数字>.<任务名>` 任务目录，或文件字节解码后提到本项目名）。
两条都中才算本项目的。当天那棵树（`123\23.870…\cache\inspect_v6` 空壳链）双双命中，
0 文件——于是**只删空壳叶子**（`cache\inspect_v6` 那一个），顶层目录、`123\` 骨架、
任务目录全部保留当证据。

三条铁律（这次写死在代码里，不只是文档）：

1. **双见证有一条不中就不认** —— 光有 `123\` 不行（任何项目都能有个叫 123 的文件夹），
   光文件里提到本项目名也不行；
2. **树里但凡有一个文件就整树保留** —— 报 BLOCKER（`damaged dir needing human review`）
   等人裁决，`sanitize -Remove` 的退出码也会是 1（REVIEW），不是 0；
3. **删之前重判一次** —— recheck 重新清点全树，期间多出一个文件就转跳过。

> 中间走过两次弯路，都记在回归里：
> 一是"字母表路由"——曾想用"名字在不在 GBK 乱码字母表里"做分流，结果普通中文名和 ASCII 名
> 全都满足，等于没分，改成现在的顺序（先精确反解，不中再双见证）；
> 二是见证 B 曾想"解码损坏的顶层名"，但 U+FFFD 吃掉的字节不可恢复，改成认**下级**的克隆形状。

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

---

## 不要用「回读自己刚写的文件」做格式转换（864 重剪轮，2026-10-01）

**现象**：生成的 SRT 每条正文是一个**纯数字**（就是那条字幕自己的序号），**真正的台词全部丢失**。
而 `qa_gate` 的两条门禁都绿：

```
subtitle_stats   「条数与 stats 一致」        -> PASS
subtitle_span    「96 cues，零跨切」           -> PASS
```

**两条门禁全绿，文件是废的。** 这是本项目至今最贵的一次「门禁全绿但交付物是错的」。

**根因**：脚本用正则从 `captions\source.srt` 回读转写，而 SRT 块的结构是

```
142                          <- 序号在时间戳行「之前」
00:14:40,380 --> 00:14:46,660
还有光诱,我来给你两个血药      <- 正文在时间戳行「之后」
```

代码写的是 `body = stamp.sub("", block).strip()` —— 删掉时间戳后剩下
`"142\n\n还有光诱,我来给你两个血药"`，**序号被当成了正文**；
紧接着 `fix_srt_gaps.py` 又按空行切块，两者被切成两块，正文再次只剩序号。

**修法**：① 文本**直接从转写 JSON 取**，不再回读 SRT（少一次有损往返）；
② `fix_srt_gaps.py` 取**时间戳行之后**的内容；
③ 冻结校验加常驻断言 **`subtitle_bodies_are_text`**：正文不得是纯数字、不得为空。

> **两条教训**
> 1. **文本永远从权威源取**（这里是转写 JSON）。中间格式一旦被误解析，错误会被「洗」成合法形状。
> 2. **「条数对得上」这类一致性检查查不出内容被换掉** —— 必须有一条**看内容本身**的断言。
>    门禁只查它会查的东西；**「全绿」不等于「对」**。

## 结算链里的加载屏：机器检测必然命中，别当缺陷去修（864 重剪轮）

`blackdetect` / `freezedetect` / `silencedetect` 在成片尾部集中命中，看起来像黑帧缺陷。
864 实证：败北局结算链里含 **19.18 秒黑屏/加载**（源 1095.85–1115.03）+ **19.1 秒数字静音**，
是游戏自己的过门（纯黑过场卡 → logo 卡 → 插画加载屏）。

**口诀**：结算链里的黑屏/加载，**只要它两侧分别接在「最后一次交战」和「战绩表」上，就是原生必经流，
不是缺陷，按规则保留不挖**；反之，若黑屏前后接的不是这两者，那就是真的挖错了。

没有这一轮交叉定位，下一轮很容易把它当「黑帧缺陷」删掉，**结果把结算链剪成两截**。

定位手法（可复用）：4 fps YAVG + `freezedetect` + `select='gt(scene,0.4)'` 三路交叉。

> 附带：败北局结算链形态与吃鸡局不同 ——
> `阵亡观战 → 败北 → 奇袭黑屏 → 名次屏 → 战绩表 → 段位屏 → 加分屏 → 大厅`。