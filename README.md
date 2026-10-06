# 《永劫无间》视频剪辑项目

这是一个以 FFmpeg 为基础渲染核心的《永劫无间》视频分析与剪辑项目，可在任意 Agent 对话（harness）中按项目内 skill 执行，不依赖任何 harness 的用户级 skill。基础流程已经跑通；当前正在升级为面向多把对局的“批量分析 → 可选本地 BGM → 事件驱动节奏/特效 → 质量检查 → 最终成片”工作流。

## 先看这里

- 项目规则：[AGENTS.md](AGENTS.md)
- 工具安装与固定路径：[docs/TOOLS.md](docs/TOOLS.md)
- **启动第一步（环境预检，唯一真源）**：`scripts/check_video_environment.ps1`
- 标准视频工作流：[docs/WORKFLOW.md](docs/WORKFLOW.md)
- 常见故障与“为什么不要重新安装”：[docs/TROUBLESHOOTING.md](docs/TROUBLESHOOTING.md)
- 任务目录规范：[123/README.md](123/README.md)
- 高质量批量成片工作流：[docs/CREATIVE_WORKFLOW.md](docs/CREATIVE_WORKFLOW.md)
- 专属剪辑 skill：[skills/naraka-highlight-studio/SKILL.md](skills/naraka-highlight-studio/SKILL.md)
- **粗剪提示词（通用唯一版，日常就用这份）**：[docs/粗剪提示词.md](docs/粗剪提示词.md)
- 生产依赖清单：[config/production_dependencies.json](config/production_dependencies.json)
- 本地素材库说明：[assets/README.md](assets/README.md)
- 单次图片上限硬红线：[IMAGE_LIMIT.md](IMAGE_LIMIT.md)（单轮 50 张封顶，看图前先数数）

所有新任务直接创建在 `123\<编号>.<素材文件名>`，不经过其他任务目录。

本项目的 skill 分两类，**判据是「这份 skill 的规格是否只对本项目成立」**：

| 类别 | 内容 | 存放位置 |
|---|---|---|
| **项目资产** | `naraka-highlight-studio`、`ffmpeg-video-editor`、`ffmpeg-analyse-video-skill` | 项目内 `skills\`，**唯一来源**。只在本项目内维护和迭代，**不复制到任何用户级 skill 目录**；处理本项目的视频任务时按项目相对路径 `skills\<name>\SKILL.md` 读取 |
| **用户级工具** | `autopilot` 及其子 skill、`issue-tracker` / `domain` 类工程 skill | harness 的用户级 skill 目录。**用 skill 工具按名字加载**，本项目不存放、不修改副本 |

项目资产要用 harness 支持的方式登记一遍才会被发现（各家发现路径不同）。**若哪天项目 skill 集体不显示，先查这一项。** 详见 `AGENTS.md` 的 **Skill 来源分两类**。

## 素材和结果目录

```text
E:\OBS                         OBS 原始录制，只读
E:\PR导出                      已经粗加工过的整局素材，只读
C:\Project\永劫无间            项目工作区
└─ 123\<编号>.<素材文件名>      每个剪辑任务的独立结果
```

不要把最终视频写回 `E:\OBS` 或 `E:\PR导出`，也不要覆盖原始 MP4。

## 已安装工具：项目共用，不按对话重复安装

主工具环境已经固定在：

```text
C:\Project\永劫无间\.video-tools\venv
```

这里已经包含 faster-whisper、PySceneDetect、Auto-Editor、CUDA/cuBLAS/cuDNN 运行库和视频处理依赖。模型缓存位于：

```text
C:\Project\永劫无间\.video-tools\models
```

FFmpeg 和 FFprobe 由预检脚本**动态解析**，不要硬编码路径；脚本里请用 `scripts\resolve_ffmpeg.ps1`。
早期文档记录的 WinGet FFmpeg 入口**已卸载**（`Links\` 目录本身还在，但里面没有 ffmpeg）；
当前实际可用的是 LosslessCut 内置的那份：

```text
C:\Project\永劫无间\.video-tools\LosslessCut\resources\ffmpeg.exe   (n8.0-23)
```

跑一次预检就知道当下解析到哪一份：

```powershell
& 'C:\Project\永劫无间\scripts\check_video_environment.ps1' -Json
```

## 一次标准剪辑任务怎么运行

### 1. 先做环境检查

```powershell
$ProjectRoot = 'C:\Project\永劫无间'
& "$ProjectRoot\scripts\check_video_environment.ps1"
```

这个脚本只读检查，不会创建虚拟环境、不执行 pip、不下载工具。退出码 `0` = 可开工，`2` = 存在 BLOCKER（看 `BLOCKERS:` 列表）。**以它的输出为环境真源**，不要自己 `Test-Path` 判断工具在不在。

### 2. 给 Agent 的任务描述

**用 `docs/粗剪提示词.md` 里的那份。** 它通用，同时支持新剪与续剪，只改「素材：」一行即可。

早期的 `PROMPT_TEMPLATES_GOAL.md` / `PROMPT_TEMPLATES_OPENCODE.md` 已从本目录移除：
前者依赖 DeepSeek 专属的 `create_goal`、后者绑定 opencode，都不通用；两者还都指示
「解析 WinGet 符号链接 Target」——该目录已整体删除，照做必撞墙。新提示词不继承这些毛病。

工作窗口至少要拿到两样东西：

1. **素材绝对路径**（如 `E:\PR导出\xxx.mp4`）。
2. **模式**：要做「每一场战斗完整保留、战斗中不切走」就用 `naraka-highlight-studio` 的 `complete_combat_roughcut`（见 `skills/naraka-highlight-studio/SKILL.md`）。

> **当前环境（2026-09-29 实测）：预检退出码 0，`ok=7 warn=0 blocker=0`，全部可用，含字幕。**
> 此前 venv 绑在一个被系统清理掉的临时缓存解释器上，2.64 GB 工具链文件全在却起不来；
> 已把 `venv\pyvenv.cfg` 指回系统 Python 3.12.10 修好，**没有重装、没有下载任何包**。
> GPU 转写（faster-whisper large-v3 / int8_float16）实跑通过。派活前仍先跑预检确认。

### 3. 标准阶段

```text
环境检查
  → ffprobe 源文件探测
  → 音频提取和 faster-whisper 转写
  → PySceneDetect 场景分析
  → Auto-Editor 音频活动分析
  → FFmpeg 缩略图/候选片段分析
  → 候选清单和剪辑时间线
  → 720p 或其他低清预览
  → 用户审片
  → 从源素材重新渲染最终成片（4K60）
  → 成片验收（解码/字幕流/时长对账）
  → 收尾清理（自动，回收可再生空间，保留证据与任务目录）
```

粗剪预览不是最终画质，也不是流程上限；它是用来确认选片、战斗完整性、字幕和切点的审片版本。

完整战斗粗剪模式的判断重点是“战斗事件的完整性”，而不是“尽可能短”。当边界不确定时，
先保留候选并标记 `needs_review`，不要让自动流程在战斗中途切走。

每次任务的全部派生文件都写入对应的 `123\<编号>.<素材文件名>` 目录。后续修订沿用同一目录，使用清晰的版本名；不要把同一任务的文件分散到根目录或另一个任务目录。

### 4. 出 4K 成片之后会自动做一次收尾清理

你说「输出 4K 成片」就等于授权整条链，末端自带清理，不用你再吩咐、也不需要你手动删：

```powershell
& 'C:\Project\永劫无间\scripts\cleanup_after_master.ps1' -TaskDir 'C:\Project\永劫无间\123\<编号>.<素材名去扩展名>'
```

它只删可由源素材重新生成的东西——`preview\`（审片预览）、`cache\`（4K 分段中间件）、
`shots\`（上千张分析抽帧）、`audio\`（转写音频），
**保留任务目录本身、`timeline\`、`reports\`、`analysis\`、`deliverables\`、`captions\`**。

849 实测：整个目录 3.39 GB，其中 3.38 GB 是上面那四样；真正值钱的是约 10 MB 的时间线与审计记录
（"这段为什么留、那段为什么删、谁核过"）。**所以不要整目录手删**——那会把依据一起删掉，
而且目录没了编号会复用。删重量、留证据、留目录壳，规则见 `AGENTS.md §7.1`。

## 已完成的参考任务

`123\` 下的任务与状态（**实测 2026-09-29**）：

| 任务目录 | 素材 | 状态 |
|---|---|---|
| `123\13.849永劫无间2026-08-29 00-06-20` | 849 | **在制**，目录现存唯一。预览 v4 已出、门禁与审计报告齐；无成片、无字幕（环境 BLOCKED） |
| （目录已删除） | 848 | 已交付，成片 2,882 MB 在 `E:\Cujian导出\` |
| （目录已删除） | 852 | 已交付 streak=2，成片 2,117 MB 在 `E:\Cujian导出\`；流程最干净的一份，可作范例 |
| （目录已删除） | 853 | 成片 1,190 MB 已在 `E:\Cujian导出\`，**但未走 `freeze_gate` 门禁**（遗留缺口） |

**已交付任务的目录由用户在成片落盘后手动删除**，不是丢失。新任务取号规则见
`123\README.md`「编号怎么取」——不写死任何具体数字。

交付目录 `E:\Cujian导出\` 实测共 **16** 条成片：
830、832、834、835、837、838、839、840、841、842、844、846、847、848、852、853。

任务 852 证明了：预览确认后，可以从原始 4K 素材按源时间线重新编码，并通过受控 VBR（h264_nvenc，b:v 18M / maxrate 28M，3840×2160@60）把体积保持在合理范围。
这条链路现在由 `scripts\seg_render_master.sh` + `scripts\verify_master.sh` 承担，两者都零 Python 可跑。

## 重要原则

1. 先检查项目现有工具，再决定是否需要安装。
2. 新任务使用 `.video-tools\venv`，不使用重复的 `.video-venv`。
3. 所有任务结果写入 `123\<编号>.<素材文件名>`。
4. 原素材只读。
5. 4K 最终版从原素材渲染，不从低清预览放大。
6. 字幕烧录版不和同名外挂字幕一起交付。
