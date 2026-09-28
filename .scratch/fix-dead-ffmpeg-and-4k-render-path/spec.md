# Spec: 修死掉的 FFmpeg 路径与 4K 成片渲染链路

**Status:** completed（2026-09-29）
**Lane:** B（well-scoped，多文件，每片可独立验证）
**Gate 0:** MISS — 解析逻辑只存在于 `check_video_environment.ps1 :: Resolve-ToolPair` 内部；
`make_contact_sheet.ps1` / `seg_render_master.sh` / `verify_master.sh` 三处各自硬编码已删除路径。

## Problem

`scripts\` 下 6 个脚本有 5 处独立缺陷，导致「4K 出片」这条工作流**一步都跑不动**：

1. **路径全死。** `make_contact_sheet.ps1:21` 指向 `WinGet\Links\ffmpeg.exe`（该目录现存 7 个符号链接，无 ffmpeg）；
   `seg_render_master.sh:8` 与 `verify_master.sh:6-7` 指向 `WinGet\Packages\Gyan.FFmpeg_…\ffmpeg-9.0-full_build\`（包目录已整个不存在）。
   唯一可用的是 `.video-tools\LosslessCut\resources\` 下的 n8.0-23。
   连带后果：联系表工具不可用 → 50 张看图红线唯一的合规缓解手段失效。

2. **全项目带 Mark of the Web。** 9733/9733 个文件带 `Zone.Identifier`，本机 `CurrentUser=RemoteSigned`
   → PowerShell 拒绝运行任何本地 `.ps1`。文档里写的 `& '…ps1'` 和 `powershell.exe -File …ps1` **全部被拦**，
   只有 `-ExecutionPolicy Bypass` 能过。这是每个任务第一步就撞的墙。

3. **4K 渲染脚本另有两处独立缺陷**（修了路径也跑不起来）：
   - `seg_render_master.sh:16` 读 `m['episodes']`，而真实时间线 JSON 的键是 `combat_episodes` → 必然 KeyError。
   - `seg_render_master.sh:9,16,46` 依赖 `.video-tools\venv\Scripts\python.exe`（预检 BLOCKER，起不来）；
     `case "$JOB"`（22-25 行）把 840/841/842 三局的时间码写死，别的任务无法使用。

## Solution

一个解析真源 + 三个消费者，加上去 Python 依赖、零安装可跑。

- 新增 `scripts\resolve_ffmpeg.ps1`：候选表与解析逻辑的唯一出处。
  两种用法：被 dot-source 时只定义 `Resolve-FfmpegPair` 函数；`-Emit` 时输出 `FFMPEG=` / `FFPROBE=` / `DIR=` 三行，退出码 0/1。
- `check_video_environment.ps1` 改为 dot-source 它，删掉自己那份副本，**行为必须逐字节不变**（回归门）。
- `make_contact_sheet.ps1` 改用同一函数。
- 新增 `scripts\read_episode_bounds.ps1`：用 PowerShell 的 `ConvertFrom-Json` 从时间线 JSON 读出每段
  `source_start` / `source_end`，每行输出 `S=<start> E=<end>`。**不依赖 Python**（PowerShell 5.1 自带 JSON 解析）。
- `seg_render_master.sh` 运行时解析 ffmpeg、从上面的输出取边界、删掉 Python 调用与写死的 `case`。
- `verify_master.sh` 运行时解析 ffmpeg/ffprobe。
- 对项目内脚本执行 `Unblock-File` 去掉 MOTW（不动机器执行策略）。

## Slices

- [x] **S1 MOTW 解除**：`scripts\` 与 `skills\` 下全部可执行脚本去掉 `Zone.Identifier`，
      判据：`& '…check_video_environment.ps1'` 不带 Bypass 直接跑通。
- [x] **S2 解析真源 + 三消费者**：`resolve_ffmpeg.ps1` 落地；`check_video_environment.ps1` 预检输出与改前逐字节一致；
      `make_contact_sheet.ps1` 端到端拼出真联系表。
- [x] **S3 4K 链路可跑**：`read_episode_bounds.ps1` 输出与 JSON 一致（11 段）；
      `seg_render_master.sh` 语法通过、边界取自 JSON、ffmpeg 可执行；`verify_master.sh` 同。

## Implementation Decisions

- **为什么抽公共文件而不是各脚本各修一份**：`.scratch\project-fix\issues\01-path-drift.md` 那轮已经修过一次同类漂移，
  但只改了文档没改脚本，导致同一缺陷复发两次（任务 849 的 `pc3_point_check.md:28` / `pc4_point_check.md:19`
  明写「因硬编码 WinGet 链接 ffmpeg，改用 LosslessCut 直接 xstack，未修改该脚本」）。三份副本必然再次漂移。
- **为什么用 PowerShell 读 JSON 而不是 bash grep**：`ConvertFrom-Json` 是 PS 5.1 自带，能正确处理
  `boundary_reason` / `notes` 里的中文与转义；grep 匹配 `"source_start":` 会被散文里的同名字符串污染。
  项目根路径含中文（`C:\Project\永劫无间`），bash 侧的编码问题也会一并避开。
- **为什么不改 `skills\ffmpeg-video-editor\scripts\*.sh`**：那三个脚本用 `command -v ffmpeg` 查 PATH，
  设计正确、无硬编码，只是本机 ffmpeg 不在 PATH。给它们喂 PATH 即可，不该改上游文件。
- **`-Emit` 输出强制 UTF-8**：项目根含中文，PS 5.1 重定向 stdout 默认走控制台 OEM 码页会乱码。
- **保留 `BURN=1` 分支但加警告（偏离记录）**：项目铁律是「不存在合法烧录版」，严格说这个分支该删。
  但删它属于改变脚本行为、超出「让它能跑」的范围，故保留并在日志里写明政策冲突与
  「不得与同名 SRT 同时交付」。**是否彻底移除，留给用户拍板。**

## Build evidence（2026-09-29）

改动文件：`scripts\resolve_ffmpeg.ps1`（新增）、`scripts\read_episode_bounds.ps1`（新增）、
`scripts\check_video_environment.ps1`、`scripts\make_contact_sheet.ps1`、
`scripts\seg_render_master.sh`、`scripts\verify_master.sh`；另对项目内 9735 个文件执行
`Unblock-File` 去 Mark of the Web。

逐条 seam 实跑结果（17/17 PASS，退出 0）：

| seam | 判据 | 实测 |
|---|---|---|
| 1 文档原样调用 | 无 Bypass 直接跑预检 | `SUMMARY: ok=4 warn=3 blocker=1`，未被策略拦截 |
| 1 回归 | 预检输出与改前逐字节一致 | PASS（`baseline_preflight.txt` vs `after_preflight.txt`） |
| 2 解析真源 | `-Emit` 退出 0 且指向 LosslessCut 那份 | 退出 0，bash 可 stat 且可执行 |
| 3 联系表 | 5 张真 jpg 端到端拼表 | 产出 5×1 联系表，产物可解码，退出 0 |
| 4 边界提取 | 对 849 v4 真实时间线 | `N=11`、11 行 S/E、`PROGRAM=1156.8`（与手算一致） |
| 5 4K 渲染 | 真实 NVENC 渲染（非语法检查） | `h264,3840,2160,60/1`，17.9 Mbps，日志 `MASTER_RENDER_COMPLETE` |
| 6 验收正例 | 时长吻合 | 退出 0，`DECODE_EXIT=0`，零字幕流 |
| 6 验收反例 | 时长不符 / 文件缺失 | 均正确拒绝（退出非 0） |
| 6 坏时间线 | `source_end <= source_start` | 拒绝渲染，退出 1 |
| 7 未回归 | 看图预算 / 任务卫生脚本 | 均正常 |

**过程中自查出并修掉的两个自身错误**（记录以免后人重蹈）：
1. 第一次验证里两条 FAIL 是**验证脚本自己写错**——断言用了正斜杠而解析器输出原生反斜杠；
   规格探测误把 `-select_streams` 喂给 `ffmpeg` 而非 `ffprobe`。产品无问题，断言改正后重跑全绿。
2. 首次真实渲染**失败**并暴露真 bug：bash 解析 `S=2 E=6` 时 `${line##* }` 只剥到空格，
   把 `E=6` 整段当成了结束时间（ffmpeg 报 `Invalid duration for option to: E=6`）；
   同时 PowerShell 输出带 CRLF，`\r` 混进数值。已改为 `${line##*E=}` 并在取值前 `tr -d '\r'`。
   ——这说明"只做语法检查就交付"会让这个 bug 直接进生产。

## Testing Decisions

seam 锁在「脚本真的产出结果」，不锁内部实现：

1. 预检回归：改前/改后 `check_video_environment.ps1` 文本输出 + 退出码必须完全一致。
2. 解析真源：`resolve_ffmpeg.ps1 -Emit` 退出 0，`FFMPEG=` 指向 LosslessCut 那份。
3. 联系表端到端：造 3 张真 jpg，跑 `make_contact_sheet.ps1`，产出真 PNG 且输出 `[PASS]`。
4. 边界提取：`read_episode_bounds.ps1` 对 `combat_episodes_v4.json` 输出 11 行，
   与 `ConvertFrom-Json` 读出的 `source_start`/`source_end` 逐行相等。
5. 4K 链路：`bash -n` 语法通过；从 JSON 取到的第一段边界驱动一次真实 ffmpeg 切片调用成功。

## Out of Scope

- **不修 Python**（`docs\PYTHON_RUNTIME_DECISION.md` 挂着的待授权项）。本轮所有改动的前提是「零 Python 也能跑」。
- 不删 `assets\` / `feedback\` 的空结构：无真实数据可填，不是缺陷。
- 不动 `skills\naraka-highlight-studio\scripts\*.py`：它们本来就依赖 Python，Python 是独立议题。

## Glossary

| 词 | 含义 |
|---|---|
| 解析真源 | `resolve_ffmpeg.ps1`，FFmpeg 候选表与解析逻辑的唯一存放处 |
| MOTW | Mark of the Web，Windows 的 `Zone.Identifier` 附加数据流，来源为「从网络下载/解压」 |
| 零安装约束 | 不新增任何需要 pip/npm/系统安装的依赖；PowerShell 与 Git Bash 自带的算已有 |
