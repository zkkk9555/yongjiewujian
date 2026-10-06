# 项目级工作规则（任意 Agent / harness 通用）

本文件是 `C:\Project\永劫无间` 的项目级操作说明。处理本项目的视频分析、字幕、粗剪、精剪或导出任务时，先阅读本文件、`README.md` 和 `docs\` 下的相关文档。

## 1. 项目范围

| 用途 | 路径 | 规则 |
|---|---|---|
| 项目根目录 | `C:\Project\永劫无间` | 脚本、说明文件和任务结果的工作区 |
| OBS 原始素材 | `E:\OBS` | 只读，不在这里写入剪辑结果 |
| PR 粗加工素材库 | `E:\PR导出` | 只读，不覆盖原始 MP4 |
| 任务结果 | `C:\Project\永劫无间\123\<编号>.<素材文件名>` | 每个任务独立保存分析、时间线、预览和成片；全部派生文件只许落此，禁写项目根与源盘（路径铁律见 skill 内 `references/roughcut-launch.md §2.7`） |

原始素材永远不直接修改。所有剪切使用源时间码，最终成片从原始素材重新渲染，不从 720p 预览放大。

**预检已内置两道路径防线**（`check_video_environment.ps1`，只读，每次任务第一步就会跑）：

- `[BLOCKER] our mojibake dir beside project`（**退出码 2，停止开工**）—— 项目根**旁边**（上一级目录）
  出现了**本项目自己的路径被读坏后产生的目录**。成因是某个 `.ps1` 存成 UTF-8 无 BOM，
  PowerShell 5.1 按 ANSI 读源码把中文项目路径读成 GBK 乱码，于是整棵目录树被建到了
  `C:\Project\<乱码名>\` 下。

  **判据是反解证明，不是"名字像不像乱码"**：把目录名按 ANSI 编码回字节、再按严格 UTF-8 解码，
  结果必须**恰好等于 `永劫无间`** 才算命中。判据在 `scripts\mojibake_guard.ps1`，
  预检与清理脚本共用它，两边不可能各判一套。

  > **2026-10-06 前的判据是"名字里汉字数 ≥ 4"，那是错的** —— `云山巨城`、`全自动跑` 全都满足。
  > 而旧的 `sanitize_stray_dirs.ps1 -Remove` 会删掉 `C:\Project\` 下**每一个**目录。
  > `C:\Project\` 是**共享父目录**，装着用户的其它项目和新建的空文件夹，照着当时的处置指引
  > 执行就会把它们一起删掉。判据已换，回归由 `scripts\test_mojibake_guard.ps1`（27 例，含
  > 拿真脚本带 `-Remove` 跑的端到端）锁住。

  **处置顺序**：
  1. 先看预检点名的**具体路径**——只有它点名的那几个才是本项目的乱码。
  2. 找到肇事的 `.ps1`，**重存为 UTF-8 with BOM**，否则删完还会再长出来。
  3. 确认无用后跑 `& 'C:\Project\永劫无间\scripts\sanitize_stray_dirs.ps1'`（默认干跑）。
     它现在只删反解命中的那几个，**其它目录一律列出并注明保留原因，绝不删除——哪怕是空的**。
  4. 要真删再加 `-Remove`。**删目录属破坏性动作，必须由人确认后执行，不要自己删。**
  > 这条曾是 WARN，被反复忽略，乱码目录一直复发（2026-09-30 升级为 BLOCKER）；
  > 2026-10-06 收窄为只对**本项目乱码**报 BLOCKER，别的项目不再误报。
- `[WARN] script encoding` —— `scripts\*.ps1` 里出现"含非 ASCII 字节但没有 UTF-8 BOM"就报。
  BOM 缺失时中文会被读坏；若坏掉的正好是**路径字面量**，脚本就会写到别处。
  修法：存成 **UTF-8 with BOM**（纯 ASCII 脚本则无所谓）。详见 `docs\TROUBLESHOOTING.md`。

## 2. 已安装的共享工具基线

> **剪辑任务第一动作（2026-10-05 立）**
> 用户给素材要粗剪预览时，**先 `skill` 工具加载 `naraka-highlight-studio`**，再按它的
> `references\` 干活；本文件只提供环境真源与项目铁律，不复述剪辑规格。
> 用户的要求「不要问我，不要分段汇报，最后一次性给结论」写在
> `docs\粗剪提示词.md`，但**那 211 行是 skill 不可见时代的加载器**——
> 现在 skill 已可见（见文末「skill 可见性」），提示词可以只留触发语 + 素材路径。

新任务优先使用下面的现有工具，不创建新的虚拟环境，也不重复安装 Python 包：

| 工具 | 项目内固定入口 | 当前状态（2026-09-29 实测） |
|---|---|---|
| Python / faster-whisper / PySceneDetect / Auto-Editor | `C:\Project\永劫无间\.video-tools\venv\Scripts\python.exe` | **可用**：预检 `[PASS]`，Python 3.12.10，六个包版本与 `config\production_dependencies.json` 完全一致，GPU 转写实跑通过 |
| Auto-Editor CLI | `C:\Project\永劫无间\.video-tools\venv\Scripts\auto-editor.exe` | 可用（29.3.1） |
| PySceneDetect CLI | `C:\Project\永劫无间\.video-tools\venv\Scripts\scenedetect.exe` | 可用（0.7.1） |
| faster-whisper 模型缓存 | `C:\Project\永劫无间\.video-tools\models` | **完好**（large-v3 / medium / small / tiny 权重都在） |
| LosslessCut | `C:\Project\永劫无间\.video-tools\LosslessCut\LosslessCut.exe` | 可用 |
| FFmpeg / FFprobe | 由 `scripts\resolve_ffmpeg.ps1` 解析，当前实际为 `C:\Project\永劫无间\.video-tools\LosslessCut\resources\ffmpeg.exe`（n8.0-23） | 可用；WinGet `Links\` 目录仍在但**已不含 ffmpeg**，`Gyan.FFmpeg_*` 包目录已整个卸载 |

**环境铁律（2026-09-29 立，教训换来的）**：

1. **优先级：项目自带 > 系统正常安装 > 其他。** 项目里已有的东西最优先；需要常规环境就用系统的。
2. **绝不依赖临时、缓存或工具运行时目录。** 本项目的 venv 原本建在 `~\.cache\codex-runtimes\...\python` 上，
   被系统日常清理删掉，2.64 GB 的字幕工具链（faster-whisper / PySceneDetect / Auto-Editor / CUDA 全套）**文件全在却一个都用不了**。
   修法不是重装 2.64 GB，而是把 `venv\pyvenv.cfg` 的 `home` 指回系统 Python——
   **建在系统解释器上的 venv 才扛得住系统清理**。任何时候新建环境都要先确认基座是系统 Python。
3. **工具路径一律运行时解析，不硬编码。** 用 `scripts\resolve_ffmpeg.ps1`（PowerShell dot-source 取函数 /
   `-Emit` 给 bash 取 `KEY=VALUE`）与 `scripts\check_video_environment.ps1`。
   三个脚本曾各自硬编码已卸载的 WinGet 路径，导致联系表工具与整条 4K 成片链路全部瘫痪。

上表是**目标态**（Python 一栏写的是项目一贯要求的入口），第三列是**当前实况**。两者不一致时以预检脚本输出为准，不要凭表格假设工具可用。

FFmpeg/FFprobe **不要硬编码路径**。正确做法是跑预检、读它解析出的绝对路径；脚本里则用 `scripts\resolve_ffmpeg.ps1` 运行时解析：

```powershell
& 'C:\Project\永劫无间\scripts\check_video_environment.ps1' -Json
```

旧对话遗留的 `.video-venv`、`video_edit_833` 和独立自动分析目录已经清理。以后如果再次看到 `.video-venv`，将其视为旧任务残留，不作为新任务入口，也不要重新创建同名环境。

## 3. 每个新任务的启动顺序

1. 运行只读预检，**以其输出为唯一环境真源**：

   ```powershell
   & 'C:\Project\永劫无间\scripts\check_video_environment.ps1'
   ```

   退出码含义：`0` = 可开工；`2` = 存在 BLOCKER；`1` = 检查本身没跑完。`BLOCKERS:` 列表逐条记录。

2. 需要机器可读结果时加 `-Json`；**不要**再去手工 `Test-Path` 判断工具是否存在——旧脚本就是只查文件存在与否，把一个起不来的解释器报成了 PASS。

3. 预检若报 `BLOCKER: python interpreter`，含义是：没有可运行的 Python，faster-whisper / PySceneDetect / Auto-Editor 全部不可用，**字幕做不了**。此时走降级路径（纯视觉 + 音频活动信号，先出无字幕预览），并在任务目录写明缺口。**不要**因此声称满足完整门禁。

4. 从预检输出里取 FFmpeg/FFprobe 的实际绝对路径，用它探测输入素材；不要自己拼路径。

5. 根据素材文件名生成下一个编号，在 `123\<编号>.<素材文件名>` 建立任务目录，再开始分析。

如果检查发现缺包或可执行文件不可用，先在任务目录写出缺口和影响。只有用户明确要求安装、修复或升级时，才执行安装动作；普通剪辑请求不包含重新安装授权。

## 4. 固定视频工作流

标准顺序是：

```text
探测源文件
  → 音频提取与 faster-whisper 人声转写
  → PySceneDetect 场景/画面变化分析
  → Auto-Editor 音频活动/静音参考
  → FFmpeg 缩略图和候选片段分析
  → 候选清单与源时间线
  → 低清预览
  → 用户审片和修改
  → 从原素材输出最终成片
```

自动标签只是筛选信号，不能单独证明“振刀、反杀、拆火或连续击杀”发生。正式输出前必须保留预览审片环节。

## 5. 字幕规则（全外挂，禁烧录禁内嵌）

- 预览与成片一律干净画面：MP4 内零字幕流、零烧录像素字，不烧录、不内嵌任何字幕。
- 使用一个明确的字幕源文件，并让字幕时间轴跟随粗剪后的节目时间线；字幕只以外挂 SRT 交付（冻结版 `captions\<序号>-review-vN.srt`），播放器按需挂载。
- 无字幕版与外挂字幕版是仅有的两种预览形态；不存在合法烧录版，不出烧录预览、不出烧录成片。
- 历史教训：烧录版再叠加同名 SRT 会造成双层字幕；本条只解释旧事故，不再是可选路径。
- faster-whisper 负责语音转文字，不天然完成说话人身份识别；“只保留玩家/队友人声”属于 VAD、置信度和人工修正规则的组合结果。

## 6. 编码和体积规则

先读取源素材的分辨率、帧率、编码器和平均码率。源素材是 VBR 时，最终输出也使用受控 VBR；不要默认使用 150 Mbps CBR。

当前已验证的 4K60 方案是：H.264 NVENC、3840×2160、60fps、VBR 目标约 18 Mbps、峰值约 28 Mbps、AAC 48 kHz。实际目标应根据源素材和成片时长调整。

## 7. 输出与交付

每次任务至少保留：源文件探测结果、候选清单、剪辑时间线、预览、字幕/字幕统计和最终参数记录。交付时说明：

- 成片绝对路径；
- 是否从原始素材重新渲染；
- 分辨率、帧率、编码器和实际码率；
- 文件体积；
- 字幕一律外挂（禁烧录禁内嵌），记录外挂 SRT 路径；
- 原始素材是否保持不变。

## 7.1 成片归属与出 4K 后的收尾清理（固定步骤，不是可选项）

**成片的唯一归属是 `E:\Cujian导出\<源文件名> cujian.mp4`。**
任务目录（`123\<编号>.<素材文件名>\`）**不得长期持有 4K 成片**——它只承载可再生的过程物与文本证据。

> 2026-09-30 立。此前成片长期留在 `deliverables\`，导致 849 / 854 / 859 各自在任务目录与 E 盘
> 各存一份，**重复占用约 6.2 GB**；且对外报路径时报的是任务目录路径，被判为"输出错目录"。

出 4K 的正确顺序：

```text
1. 渲 4K 到 E:\Cujian导出\<源文件名> cujian.mp4   ← 直接渲到交付目录，不进任务目录
2. 验收：对 E 盘那份跑 scripts\verify_master.sh
3. 收尾：& 'C:\Project\永劫无间\scripts\cleanup_after_master.ps1' -TaskDir '<任务目录>'
```

> 建议渲到 `cache\` 中间件再搬到 E 盘，或直接渲到 E 盘；**不要渲进 `deliverables\`**。

第 3 步是**自动**执行的固定步骤，不额外问用户：

```powershell
& 'C:\Project\永劫无间\scripts\cleanup_after_master.ps1' -TaskDir 'C:\Project\永劫无间\123\<编号>.<素材文件名>'
```

**交付闸门（删任何东西之前先证明成片已落地）**：脚本先在 `E:\Cujian导出\` 找
`<素材名>*.mp4`（非空）。**找不到就拒绝删除、一个字节都不删**，并报 `[BLOCKED]`
——因为丢成片的代价远大于留几个 GB。这是数据丢失护栏，优先级高于省磁盘。

| 删（可再生，非证据） | 留（证据 + 编号依据） |
|---|---|
| `preview\` 审片预览 | **任务目录本身**（`123\README.md` 取号规则读它，删掉会导致编号复用） |
| `cache\` 4K 分段渲染中间件 | `timeline\` 时间线与节目映射（只放 JSON，取证帧不许进这里） |
| `shots\` 分析用抽帧（可上千张） | `reports\` 审计 / 验收 / 门禁 / 逐点裁决 |
| `audio\` 转写用音频 | `analysis\` 探测与场景/音频活动 |
| `deliverables\*.mp4` **成片副本**（E 盘已有正本后） | `captions\` 外挂 SRT、所有根级文件 |

**为什么这么分**：849 实测整个目录 3.39 GB，其中 3.38 GB 是上面四样可再生重量，
真正值钱的是约 10 MB 的时间线与审计记录——那是"这段为什么留、那段为什么删、谁核过"的唯一依据。
删重量、留证据，目录壳留着给编号用。**不要再整目录手删**，那会把依据一起删掉。

脚本护栏（自带，缺一即拒）：`deliverables\` 无非空成片则只报 SKIP 不动手；任务目录不在 `123\` 直接子级则拒绝；
待删路径解析后不在任务目录内则拒绝；先写 `reports\cleanup_log_after_master.md` 再删（无 log 的删除视为违规）；可重复执行。

版本化命名与清理生命周期索引：预览 `preview\<序号>-review-vN.mp4`、字幕 `captions\<序号>-review-vN.srt`、时间线 `timeline\combat_episodes_vN.json` 三件套、验收 `reports\selfaudit/accept/reverify_<序号>_vN.md` 三分立、每次删除记 `reports\cleanup_log_vN.md`；成片仍为"源文件名 + cujian.mp4"。完整规则见 skill 内 `references/deliverables-and-qa.md` 命名与清理节。

## Agent skills

### Issue tracker

本项目使用本地 Markdown 记录工程任务（`.scratch/<slug>/spec.md` + `issues/NN-*.md`）。见 `docs/agents/issue-tracker.md`。

### Domain docs

单上下文：根目录暂不建 `CONTEXT.md`，术语先沉淀在各任务 spec 的 Glossary；确有不可逆词汇再走 domain-modeling。见 `docs/agents/domain.md`。

### Autopilot

后续工程开发默认使用 `autopilot` 全自动流程：理解、spec、拆票、构建、验证一轮走完；只有破坏性、对外可见或变更范围的决策才停下找人。视频剪辑仍以本文件和 `naraka-highlight-studio` 为准，autopilot 只用于项目本身的代码/文档修正。

**用 skill 工具按名字加载它，不要手抄绝对路径**——autopilot 及其子 skill 是用户级通用工程工具，由 harness 的用户级 skill 目录提供，本项目不存放也不修改副本。本项目跑 autopilot 时不写中央日志、不建任务标记（见 `docs/agents/autopilot-local.md` 项目本地化覆盖）。

### Skill 来源分两类（2026-10-06 起）

这个项目里 skill 有两个来源，**混为一谈会读错文件**，判据是「这份 skill 的规格是否只对本项目成立」：

| 类别 | 内容 | 存放位置 | 怎么读 |
|---|---|---|---|
| **项目资产** | `naraka-highlight-studio`、`ffmpeg-video-editor`、`ffmpeg-analyse-video-skill` | 项目内 `skills\`，**唯一来源** | 按项目相对路径 `skills\<name>\SKILL.md`；**不要在任何用户级 skill 目录里安装、复制或维护同名副本** |
| **用户级工具** | `autopilot` 及其子 skill、`issue-tracker` / `domain` 类工程 skill | harness 的用户级 skill 目录 | **用 skill 工具按名字加载**；本项目不存放、不修改其副本 |

两条补充：

1. **项目资产要用 harness 支持的方式登记一遍**，否则多数 harness 不会去项目根裸目录 `skills\` 里找（各家发现路径不同：`.<harness>/skills`、`.claude/skills`、`.agents/skills` 或配置项）。本机 opencode 的做法是在项目根 `opencode.json` 写 `"skills": ["./skills"]`。**若哪天项目 skill 集体不显示，先查这一项还在不在**，别急着把规则抄进别处。
2. **2026-10-06 之前项目 skill 集体隐形**，`docs\粗剪提示词.md` 因此被迫膨胀到 211 行当加载器。修好之后那份文件才薄回触发器。**别把它改回去。**

## 8. 高质量批量成片工作流

当用户要求 BGM 卡点、关键节点特效、音画同步、批量处理多把对局或只接收最终成片时，使用项目内专属工作流原型：

```text
C:\Project\永劫无间\skills\naraka-highlight-studio\SKILL.md
```

它负责把多把对局整理成批次，在有本地/用户提供 BGM 时分析实际音频，建立振刀/反打/击杀/大招/拆火等事件标记，生成节奏和效果时间线，并执行最终质量检查。项目内部仍保留可重建时间线、音频 stems、事件标记和缓存，用户交付默认只展示成片和必要的预览。

该 skill 的规范来源只有项目内这一个路径。不要在用户级 skill 目录再安装、复制或维护一份同名 skill。

> 本项目的 skill 分两类（项目资产 / 用户级工具），判据与读法见上文 **Skill 来源分两类**。

稳定规则写在 skill 中，个人风格写在 `style_profiles`，素材索引写在 `assets`，用户反馈写在 `feedback`。不要把某一首当前热门歌曲或一次性的特效偏好写死为永久规则。

e系列升级索引（只索引不展开）：防漏扫e1 / 防中断尾e2 见 skill 内 `references/complete-combat-roughcut.md`（参数与尾窗升级）；预览对抗审e3 / 极限并行e4 / 冻结门禁2.0 e5 见 skill 内 `references/roughcut-launch.md §2/§3.6/§3.7` 与 `references/deliverables-and-qa.md` 门禁节；设计原稿见 `123\workflow_upgrade\e1-e5`，合入记录见 `123\workflow_upgrade\merge_log_e.md`。零星合并g见 skill 内 `references/roughcut-launch.md §2.8`（岛式合并/搭桥/单裁决/三态台账）；设计原稿见 `123\workflow_upgrade\g-shard-merge.md`，合入记录见 `123\workflow_upgrade\merge_log_g.md`。

## 8.1 一整场完整战斗（2026-10-01 立，最高优先级判据）

**用户原话**：「我想要记录一整场完整的战斗。不管中间我去干啥，可能去舔包了、打药了，或者去拉扯了……中间可能有二三十秒我都是在观察的状态，其实那也算战斗的一部分。**我不想中间有断断档的时间，因为一断之后，战斗就不连贯了，观看体验就会很差。**」

三条硬规则（完整版与逐条实证见 `skills/naraka-highlight-studio/references/complete-combat-roughcut.md` §2.2.1）：

1. **战斗窗口内不许挖洞** —— `(engage_start, outcome_time)` 内不允许任何 `excluded_inside`。战术停顿要**包含进来**，不是挖掉。
2. **战斗窗口内不许切断** —— 相邻两场若战斗流程延续必须合并，间隙哪怕 6 秒也要包含。**洞清光了 ≠ 战斗没被切断，场边界本身也在切。**
3. **洞只许落在窗口外** —— `excluded_inside` 只能出现在 `outcome_time` 之后（结果后的大地图／结算面板）或 `engage_start` 之前（前置跑图）。

**判断一个面板删不删，看它在不在这场战斗的因果链里，不看它是不是面板、不看它几秒。**
这条取代了旧口径「删：……全屏 UI（除属收束环节的）」——旧口径把战斗中舔包/打药面板判成待清除 UI，
864 因此连续六版被用户否决。

机器执行（`qa_gate.py`）：`no_holes_in_battle`（默认 WARN，时间线声明 `"whole_battle_policy": "864"` 转 FAIL）
与 `no_zero_gap_pseudo_cuts`。回归测试 `scripts/test_whole_battle_gates.sh`。

**门禁是必要条件，不是充分条件。** 这两条只覆盖「战斗被挖断」和「战斗被切断」两种失效模式。
864 的 v6 在这两条上干净，但用户审片后说**它仍有问题、要整局重剪**——残留问题不在门禁射程内。
**`qa_gate.py` 全绿之后仍然必须看片**，不要拿门禁通过当冻结依据。

## 8.2 经验收纳机制（用户说「去收纳经验」就走这条）

每局的经验照常写在任务目录 `reports\workflow_notes_<任务目录号>.md`，
专题复盘写进 `docs\lessons\`。**汇总入口是 `docs\lessons\POOL.md`** —— 打开管理窗口看那一份就够。

```powershell
& 'C:\Project\永劫无间\scripts\collect_lessons.ps1'          # 扫描并打印待升级清单
& 'C:\Project\永劫无间\scripts\collect_lessons.ps1' -Write   # 追加新候选到 POOL 的待升级表
```

脚本会报告：经验源清单、哪些已吸收、**哪些待升级**、覆盖率（几个任务目录缺 `workflow_notes`）、
命名是否合规。

**两条硬规矩**（否则池子会退化成摆设）：

1. 每条吸收后**必须回填 POOL 的「吸收去向」列并把状态改成 `已吸收`**。没写去向的不算吸收。
2. POOL 的「教训」列**以原文标题加粗开头**——那是脚本判断"是否已吸收"的机器锚点。

**新增第 8 种审片角色：删除段审计员**（`roughcut-launch.md`）。
864 §4.1 的教训：7 路对抗审 + 4 遍自审 + 3 路验收，**没有任何一份任务书要求过查被删掉的区间**，
漏掉的那场战斗就躺在删除段里，而删除段的 `reason` 写得再详尽也不等于核验通过。每轮必须派一路。

## 9. 单次图片上限（全模型硬性红线，每轮持久有效，违者会话作废）

无论使用什么模型（含 `muse-spark-1.3-contributor-free` 及任何后续模型），上游单次请求携带的图片总数上限都是 50 张，绝对不允许超过任何一张。超过后上游直接失败、当前会话无法继续，只能换新窗口，因此必须事前限流，且该约束在每次对话的每一轮都有效。

计数口径是累计口径：上游按一次请求内携带的全部图片结算，包括历史轮次已看过的图加上本轮新增（`Read` 图片 + `get_app_state` 截图 + `screenshot` + `zoom` 裁图后再次判读）。只数“本轮新增”是不够的——每批只看 5 张、连续多批累加也会爆掉（`sess_03bfff9d` 即因此作废）。

强制执行顺序（看图前必须先做预算，不做预算不准看图）：

1. 先用 `ls`/`dir` 数好本轮要看的图片总数（如 `thumb_*.jpg`、`detail_*/*.jpg`、`contact_*.jpg`），把数字写出来；再运行 `scripts\check_image_budget.ps1 -ImageDir <缩略图目录> -AlreadySeen <历史已看数>` 打印分轮计划。总数 >50 或累计会超 50，必须先拆成多轮，拆完每轮各自重新计数。
2. 单轮新增预算：每轮新 `Read` 的图片不超过 10 张（常规每批 4–10 张）；单轮内所有图片工具加总仍不得超过 50 张。同一轮不得为“省事”合并多批。
3. 需要看超过 10 帧时，优先用 `scripts\make_contact_sheet.ps1` 拼成联系表（一张联系表只算 1 张）；需要逐帧时用 FFmpeg 先抽稀（如 1/10fps 缩略图），只对边界前后小批量补帧。
4. 若某次分析确实需要超过 50 张，拆成多个单轮依次执行，每轮结束先写出中间结论（如 `shots/verify/` 核实记录），下一轮按累计口径调小预算后再继续；历史已看图太多时开新窗口继续。
5. 本条与模型名称无关：即使上游模型更换，50 张红线仍然有效；任何文档不得将其写成仅适用于某一模型的临时限制；如有冲突以 50 张上限为准。

失败教训（回归记录）：曾因一次性单独提交 53 张图片导致上游返回失败、会话作废；`sess_03bfff9d` 则因小批量多轮累加超 50 同样作废。宁可拆多一轮，不可多看一张。
