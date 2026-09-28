# 02 — 工具路径动态解析：不再指向已删的符号链接

Status: resolved
Slice: 1
Blocked by: —

## 落地结果（2026-09-29）

- 新增 `Resolve-ToolPair`：按候选顺序解析，**要求 ffmpeg.exe 与 ffprobe.exe 成对存在**才算可用，避免只命中一个。
- 候选表：WinGet `Links`（向后兼容将来装回）→ LosslessCut 内置 `resources`（**当前唯一可用**）→ 项目 `ffmpeg\bin` → `C:\ffmpeg\bin` → `C:\Program Files\ffmpeg\bin` → PATH。
- 实测输出（不再是空 Target）：
  - `FFmpeg resolved: ...\.video-tools\LosslessCut\resources\ffmpeg.exe :: ffmpeg version n8.0-23-gd1f31a829d-20251022`
  - `FFprobe resolved: ...\ffprobe.exe :: ffprobe version n8.0-23-...`
- `Get-ToolVersion` 实执行 `-version` 取首行；跑不动则回报 `present but did not run (exit=N)` 而非假装通过。
- Python 侧同样走候选解析（venv 优先 → 常见安装位 → PATH），**只解析不新建环境**。
- 全部候选都缺 `ffmpeg/ffprobe` 时判 **BLOCKER**（而非旧脚本的 WARN），因为没有它渲不出任何东西。

## 问题

`docs/TOOLS.md` 与两个提示词文件都指示工人「解析 WinGet Links 下 ffmpeg/ffprobe 符号链接的 Target 再调用」。

实测：`%LOCALAPPDATA%\Microsoft\WinGet\Links` **整个目录已不存在**。

机器上现存的可用 FFmpeg 是：
`C:\Project\永劫无间\.video-tools\LosslessCut\resources\ffmpeg.exe`（n8.0-23）

照文档做的工人会拿到空 Target 然后卡住。

## 目标

工具定位从**硬编码单一路径**改为**按候选顺序动态解析**，谁先存在用谁，并把结果打印出来。

## 动作

1. 预检脚本内建候选列表（按优先级），至少覆盖：
   - `WinGet\Links\ffmpeg.exe`（保留，向后兼容将来装回来）
   - `.video-tools\LosslessCut\resources\ffmpeg.exe`（**当前唯一可用**）
   - PATH 上的 `ffmpeg` / `ffprobe`
   - `ffmpeg.exe` / `ffprobe.exe` 成对出现的目录才判定可用
2. 解析结果打印**实际绝对路径 + 版本首行**，取代现在打印空 Target 的行为。
3. `ffmpeg` 与 `ffprobe` 必须**成对**判定，避免只有其中一个。
4. 找到即打印 `FFmpeg resolved: <path>`，供后续步骤直接引用，不再各自硬编码。
5. 同样为 Python 准备候选解析（venv → PATH → 常见安装位），但**不新建环境**，只解析并如实报告。

## 验收

- 运行预检，必须打印出真实存在的 ffmpeg 绝对路径与版本行，不能是空字符串。
- 文档与提示词中不再有「解析符号链接 Target」这类指示（见 03）。

## 备注

候选表要能扩展：将来真装了 WinGet 版或别的版本，插一行即可，不改调用方。
