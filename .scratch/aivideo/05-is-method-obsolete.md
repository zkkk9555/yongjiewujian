# 05 · 「多 Agent 并行抽帧读图」在 2026 年过时了吗？—— 逐项判定

> **用户原话**：「**有没有可能是因为我们现在用的这个方法有点落后了，跟不上最新的 AI 工具了呢？**」
> **取证日**：2026-10-05 · 本轮**零图片**（AGENTS §9 预算消耗 0 张）
> **本轮改动**：只写本报告一个文件，未动 `skills\` / `scripts\` / 任何任务目录。

**证据等级约定**（每条结论后面标）：

- `实测` = 我本轮自己抓取/跑过（HTTP 抓取正文、GitHub API 返回值、本机 ffprobe）
- `文档` = 官方文档/论文原文，本轮由搜索引擎或直抓取得原文段落
- `推断` = 我从多处事实推出，未被直接证伪
- `未找到` = 查了但没查到，**不编项目名、不编数字**

---

## 0. 一屏结论

```
用户的问题成立一半，而且是最痛的那一半。

真正过时的不是「多 Agent 并行分解」，是其中两件具体的事：
  ① 用「子 Agent 抽帧 → 人肉式读联系表 → 写散文报告」当语义裁决通道
  ② 派工 / 回收 / 换路靠人守，以及「14 路全回收才能合成」这个 barrier

不过时的（而且业界 2026 刚刚追上来的）：
  并行分解 · 分派契约 · 可回放证据 · 机器门禁 · 预览/成片同源
  —— 这五样我这一轮在 4 个独立项目里都找到了同构实现（§3）。

最严重的一条（本报告新增，与 20 号报告互补）：
  换掉①**不会**提高准确率。20 号实测零样本 VLM 在 FPS 交战判据上上限 57–71%，
  且低于「猜多数类」的情形已实测出现。
  ⇒ 「用视频大模型直接吃视频」解决的是**覆盖率和成本**，不是**语义天花板**。
     天花板要靠 20 号 §6.2 的非 VLM 硬判据抬，不是靠换模型抬。

最值得抄的一个做法（只一个）：
  hypecut 的「便宜信号先跑全片、贵模型只跑候选窗」级联。
  我们现在是反过来的：14 路贵裁决跑满 100% 时长，还必须全部回来才敢合成。
```

---

## 1. 2025–2026 业界做长视频理解的主流架构（不是逐帧读图）

### 1.1 主流架构一：**端到端视频原生 VLM + 结构化时间戳输出**（不是帧采样）

`实测`（本轮直接抓取 [docs.twelvelabs.io/v1.3/docs/guides/segment-videos](https://docs.twelvelabs.io/v1.3/docs/guides/segment-videos) 正文）—— TwelveLabs Pegasus 1.5 的 **video segmentation**：

> "Transform raw videos into **structured, timestamped data**. Define the types of segments you want to detect and the fields you want to extract… the platform automatically identifies segment boundaries and returns custom metadata for each segment in **JSON format**."

关键能力（原文要点）：

| 能力 | 原文依据 |
|---|---|
| 自定义分段类型 + 自定义字段 | "Define your own segments… specify custom fields" |
| 每段带 `start` / `end` 时间戳 | "Each segment includes a start and end time" |
| 单请求最多 **10 个**分段定义 | "Submit up to 10 segment definitions in a single request" |
| 每个定义最多 **20 个**字段，字段有类型（`string`/`boolean`/`number`/`integer`/`array`） | "Fields have a name, type… and a description. You can define up to 20 fields per segment definition" |
| 可限定每种分段只在某些时间窗内提取 | "Per-definition time ranges" |
| 可控最短/最长分段时长 | "Set minimum and maximum segment durations" |
| 容量：**最长 2 小时**（或 4 小时视频的某一段），共享上下文 **261,120 token**，输出上限 98,304 token | `实测` docs.twelvelabs.io/docs/concepts/models/pegasus |
| **无需预索引** | "Pegasus 1.5 analyzes videos directly from a URL, asset, or base64 string, **with no pre-indexing required**" |

`实测` TwelveLabs 还已把这一层包成 agent：Jockey 页面（[twelvelabs.io/jockey](https://twelvelabs.io/jockey)，Research Preview，已进 Claude Connectors 目录，暴露 `mcp.twelvelabs.io/jockey/mcp`）自述能力含：

> "**Instant Highlight Reels** — Point Jockey at a topic and get an **edit-ready cut** of your best moments back."
> "**Structured Data Extraction** — Define a JSON schema and get back **timestamped, machine-readable metadata** for every video."

> `推断` **这条与我们的形态差别是结构性的**：我们「14 路子 Agent 各自抽帧读图 → 各写一份散文报告 → 修线员把散文合成一条 JSON」。业界主流是「一次调用 → 直接返回带时间戳的结构化 JSON」。**中间那层「散文报告 + 人工/Agent 二次合并」在主流架构里根本不存在。**

### 1.2 主流架构二：**agentic video understanding**（模型自己决定看哪几帧）

`文档`（搜索引擎返回的 [ai.google.dev/gemini-api/docs/video-understanding](https://ai.google.dev/gemini-api/docs/video-understanding) 正文；我直连该域名三次均超时，故按 `文档` 而非 `实测` 记）：

> "By default, video inputs use **static processing (extracting frames at 1 FPS)**.
> Gemini 3.8 Flash, 3.7 Flash, 3.6 Flash, and 3.5 Flash Lite models also support **agentic video understanding**, where the model **dynamically explores the video timeline, selectively inspecting transcripts and adaptively adjusting frame rates and resolution on the fly based on the prompt**. Up to **88% more token-efficient and ~7% higher quality** on long-form content."

同一页还有两条对本项目直接相关的硬数字：

- token 成本：`文档` "**Approximately 300 tokens per second of video** at default media resolution, or **100 tokens per second** at low media resolution."；帧本身 258 token/帧（`MEDIA_RESOLUTION_HIGH` 280），音频 32 token/s，**每秒都会打时间戳**。
- 容量：`文档` "Models with a **1M context window** can process videos up to **3 hours** long by default (at low media resolution), or up to 1 hour at high media resolution."

> `推断` **「模型自己决定看哪几帧」这件事，就是我们 14 路子 Agent 在人工编排下做的事。** 区别是：他们把它做进了模型内部（一次调用、连续推进、无 barrier），我们把它做成了外部 14 个独立会话 + 人工派工 + 人工回收 + 必须全回收才能合成。
> `文档` 官方那句 "**general-purpose models sample frames and guess. Pegasus reasons continuously over the full temporal arc**"（twelvelabs.io 首页）——这是厂商自己承认：**抽帧+猜是旧范式，连续时序推理是新范式。**

### 1.3 主流架构三：**开权重侧的对应物**（可本地跑，但受显存限制）

`文档` [Qwen3-VL 技术报告 arXiv:2511.21631](https://arxiv.org/abs/2511.21631)：

> "natively supports interleaved contexts of up to **256K tokens**, seamlessly integrating text, images, and video… **handles books and hours-long video with full recall and second-level indexing**"（`文档` [QwenLM/Qwen3-VL README](https://github.com/QwenLM/Qwen3-VL)）
> 架构升级三条里有一条专打时序："**Text–Timestamp Alignment**… evolving from T-RoPE to **explicit textual timestamp alignment** for more precise temporal grounding"

`文档` 时序定位专用模型也已经成系列：TimeLens（CVPR 2026，TimeLens-8B 声称超过 GPT-5 与 Gemini-2.5-Flash）、TimeLens2（2B 即超过同尺寸 Qwen3-VL 基线 14.2 mIoU）、Open-o3-Video（arXiv:2510.20579，V-STAR 上 mLGM +24.2%）。

> `实测` **本机跑不动这条路的前半段**：本机 `nvidia-smi` 实测 **RTX 4060 Ti / 8188 MiB VRAM**。Qwen3-VL-8B 视频长上下文在 8GB 卡上不是可用方案（未实跑，不给数字）。**⇒ 开权重视频 VLM 这条路对本机是「知道存在但不可作为依赖」。**

---

## 2. 成熟开源项目：「输入游戏录像 → 输出高光」有没有现成的？

### 2.1 直接回答：**没有一个「成熟 + 活跃 + 输入游戏录屏 → 输出高光」三者兼具的项目**

`实测`（GitHub API 逐仓查 stars / pushed_at，2026-10-05 当日）：

| 仓库 | stars | 最后 push | 做什么 | 判定 |
|---|---|---|---|---|
| [Flowtter/crispy](https://github.com/Flowtter/crispy) | 158 | **2025-03-20** | 神经网络检测高光，支持 Valorant / LoL / OW2 / CS2 / The Finals | **已停更 19 个月**。且是 2022 年的工程，Python 3.8–3.10 |
| [Aseiel/VideoHighlighter](https://github.com/Aseiel/VideoHighlighter) | 152 | **2026-10-04（昨天）** | 本地 Ollama，信号时间轴 + 可解释报告 + 可续跑 Auto 流水线 | **活跃，但通用素材向，不针对游戏战斗语义** |
| [Yu-0312/hypecut](https://github.com/Yu-0312/hypecut) | 2 | 2026-09-05 | VOD → 高光卷 + 可解释 cut list + EDL 导出 | **2026-08-24 才建，最新最贴合，但 2 星、无社区** |
| [ybrightye/lemonade-replay-studio](https://github.com/ybrightye/lemonade-replay-studio) | 3 | 2026-06-10 | 本地 Lemonade STT+LLM，**明确以游戏录屏为目标**，产出 highlight reel + timestamped HTML moment map | 活跃但极小、未验证 |
| [mahdi-alkak-1/HighlightIQ](https://github.com/mahdi-alkak-1/HighlightIQ) | 3 | 2026-01-31 | gameplay highlight 检测 → Clip Studio 审核 → YouTube 发布 | 极小，未验证 |
| [yarikleto/cs-go-highlights](https://github.com/yarikleto/cs-go-highlights) | 54 | 2026-09-30 | 从 **CS:GO demo 文件**检测 kill series/ace/clutch → HLAE 重录 → 成片 | **架构完全不同**：吃 telemetry 不吃画面 |
| [sunysaurav/killclip](https://github.com/sunysaurav/killclip) | 0 | 2026-09-13 | 从**控制台日志**找击杀 → 切 clip/EDL/卡点混剪 | 0 星玩具 |
| [b429342/r6s_montage_generator](https://github.com/b429342/r6s_montage_generator) | 0 | 2025-07-12 | 彩虹六号 **killfeed OCR** 检测击杀 | 0 星玩具 |
| [rlmsinclair/montage_maker](https://github.com/rlmsinclair/montage_maker) | 0 | 2026-06-12 | killfeed OCR → TikTok 混剪 SaaS | 0 星玩具 |
| [meng12312927/yingzheng-video-workbench](https://github.com/meng12312927/yingzheng-video-workbench) | 1 | 2026-09-15 | **多 Agent 粗剪助手**，可审核决策 Harness，`CanonicalTimeline` 单一事实源 | **形态与我们最像，但 1 星** |

### 2.2 通用高光/剪辑方向（不是游戏专用，但形态可抄）

`实测` GitHub API：

| 仓库 | stars | 最后 push | 关键点 |
|---|---|---|---|
| [Anil-matcha/AI-Youtube-Shorts-Generator](https://github.com/Anil-matcha/AI-Youtube-Shorts-Generator) | **5242** | 2026-09-29 | 口播向短视频，非游戏 |
| [poseljacob/agentic-video-editor](https://github.com/poseljacob/agentic-video-editor) | 496 | 2026-04-14 | Gemini Agent 集群（Director / Trim Refiner / Editor / Reviewer）+ FFmpeg，**Agent 只出 EditPlan，渲染与 QA 本地确定性** |
| [line/lighthouse](https://github.com/line/lighthouse) | 272 | 2026-09-17 | LINE 出品，视频 moment retrieval + highlight detection 库，ICASSP 2026 |
| [MeiGen-AI/X-Cut](https://github.com/MeiGen-AI/X-Cut) | 35 | 2026-04-22 | 对话式剪辑 Agent + Remotion 实时渲染 |
| [qingningLime/Cliptolution](https://github.com/qingningLime/Cliptolution) | 124 | **2025-08-27** | 中文视频 Agent Demo，已停更 13 个月 |
| [LaihoE/demoparser](https://github.com/LaihoE/demoparser) | 728 | 2026-09-30 | **CS2 replay（.dem）解析器**——telemetry 路线的成熟件 |

### 2.3 学术侧：2026 年的游戏高光生成

`文档` [arXiv:2505.07721《Gameplay Highlights Generation》](https://arxiv.org/abs/2505.07721)（AMD，2025-05）——**这是我把整个问题搜下来最相关的一篇**：

- 路线：**把游戏录像切成 1 秒片段做分类**，微调 **X-CLIP**（不是通用大模型抽帧读图）
- 数据：自建 gameplay event detection 数据集，VIA 标注
- 结果：finetuned 模型在**未见过的** FPS 录像上 **>90% 准确率**；低资源游戏联合训练还显示迁移学习收益
- 部署：`文档` "we used **ONNX** libraries… post training quantization… **ONNX runtime with DirectML backend**… on **Windows OS**"

> `推断` **这篇直接否掉了「零样本大模型读图裁决」这条路，同时给了本机可行的一条替代**：4 分类（打/被打/正常/…）+ ONNX + DirectML + Windows，恰好落在本机 RTX 4060 Ti / 8GB / Windows 这台机器的能力区间里。
> ⚠ **但**：它的标注数据是 AMD 自建的、`未找到` 公开权重，`未找到` 可直接用于《永劫无间》的类目定义。**不能当依赖，只能当「这条路存在且 >90%」的证据。**

---

## 3. 别人的「从素材到成片」流水线长什么样？架构差在哪

### 3.1 五种架构的横向对照（全部 `实测` 抓取正文或 README）

| # | 架构 | 代表 | 判定语料的方式 | 输出 | 与我们差在哪 |
|---|---|---|---|---|---|
| A | **telemetry 优先**（游戏自己告诉你高光在哪） | [Overwolf replays API](https://dev.overwolf.com/ow-native/reference/media/replays)（`实测` 抓取正文）；[LaihoE/demoparser](https://github.com/LaihoE/demoparser) 728★；[cs-go-highlights](https://github.com/yarikleto/cs-go-highlights) | **不看画面**。游戏事件 API / demo 解析 | 直接是要录的那几段 | **最大的一条路**。Overwolf 原文："**There's no need to know/understand each supported game's mechanics, game flow, edge cases, timings, etc. Just request for any supported game highlight and OW will provide you with a video file**" |
| B | **视频原生 VLM → 结构化时间戳** | TwelveLabs Pegasus 1.5（`实测`）；Gemini agentic（`文档`） | 模型连续读视频，自己决定看哪帧 | **带时间戳的 JSON** | 消掉了「散文报告 + 二次合并」两层 |
| C | **专用小模型分类器** | AMD X-CLIP（`文档`） | 1 秒片段分类，专用微调 | 每秒一个标签 | 我们没有这一层。20 号报告的结论正好说明缺它的后果 |
| D | **级联：便宜信号全片 → 贵模型只跑候选窗** | [hypecut](https://github.com/Yu-0312/hypecut)（`实测` README） | 先全片跑廉价信号，再只对少量候选窗跑 CLIP/Whisper | reel + **可解释 cut list** + EDL | **我们要抄的就是这个（§5）** |
| E | **多 Agent 编排 + 机器门禁** | [VideoAgent](https://arxiv.org/abs/2606.23327) 30+ 编辑 Agent（`文档`）；[CutClaw](https://arxiv.org/abs/2603.29664) Playwriter/Editor/Reviewer（`文档`）；[yingzheng](https://github.com/meng12312927/yingzheng-video-workbench) `CanonicalTimeline`（`实测`） | 分 Agent 但**共享一次解析结果**，不各自抽帧 | 统一时间线 | **形态跟我们最近，且比我们少一层** |

### 3.2 「别人也这么做」的四处独立佐证（说明我们这几样**不是**土办法）

`实测` 抓到的原文，每一条都对应我们项目里一个既有机制：

| 我们的机制 | 外部同构实现（原文） |
|---|---|
| **可回放证据**（联系表 + 证据帧绝对路径 + 每条结论可回查） | VideoHighlighter README：`**Every run explains itself.** The report is the arithmetic behind each kept moment — the per-signal point breakdown, what fired, what scored well and still missed the cut.` ；hypecut README：`**Every decision is inspectable.** Each clip carries the per-signal scores that produced it. The JSON sidecar and the EDL export mean HypeCut can be your **first pass rather than your only pass**` |
| **AI 只出决策、渲染与 QA 保持本地确定性** | [poseljacob/agentic-video-editor](https://github.com/poseljacob/agentic-video-editor)：Director 搜素材索引 → 产 EditPlan → Editor 用 FFmpeg 渲 → Reviewer 打分。**没有一个 Agent 碰渲染器** |
| **模型不得自行批准/改状态** | `实测` yingzheng `docs/architecture.md` 原文：「**LLM 不能直接改变任务状态、批准计划或触发正式渲染。** 引文、需求映射、来源和检索分数**由代码补齐并校验，不信任模型自由生成的"证据字段"**」 |
| **单源时间线 + 版本作废下游** | `实测` yingzheng：「FFmpeg、剪映交接包和 OTIO **都消费同一个批准时间线**。Adapter 失败不得污染任务书或批准状态。」 |

> `推断` **§3.2 是本报告对「我们是不是落后了」最直接的回答**：我们担心落后的那几样（分派 brief、可回放证据、机器门禁、单源纪律），业界在 2026 年**独立地、分别地**做到了同一形态。**我们不落后在这些。**

---

## 4. 商业服务：有没有直接做这件事的？

### 4.1 游戏录屏方向：只有一家明确点名《永劫无间》，但形态与我们冲突

`文档`（引自同会话兄弟报告 [06-one-prompt-to-film.md](./06-one-prompt-to-film.md) §1.2，本轮未重复取证）：**Eklipse**（eklipse.gg）帮助页原文点名 "CS2, Dota 2, Apex, **Naraka**, and PUBG"。但：

- 输出 **9:16 竖屏 + AI 烧录字幕 + 直发 TikTok/Shorts/Reels** → 与 `AGENTS §5`（全外挂、禁烧录）和 `§6`（4K60）**正面冲突**
- 公开 API：`未找到`（只有产品页与帮助页，无开发者文档）
- `未找到`：任何一家公开 API 能接受「游戏录像 → 战斗段时间戳」的商用服务

### 4.2 通用视频理解 API：能力够，但**不适配本机素材**

`实测` 本机 ffprobe 抽样 `E:\OBS` 四个最新源文件：

```
2026-10-04 17-31-56.mp4 | 40 min | 4.23 GB | 2560x1440 @60/1 hevc
2026-10-04 17-12-16.mp4 | 40 min | 5.89 GB | 2560x1440 @60/1 hevc
2026-10-04 15-40-42.mp4 | 40 min | 5.63 GB | 2560x1440 @60/1 hevc
874英歌赛段        | 39.9 min | 4.84 GB | 2560x1440 @60/1 hevc
```

对照两个 API 的硬限制：

| | TwelveLabs Pegasus 1.5 | Gemini |
|---|---|---|
| 单文件体积 | `实测` "Public video URLs up to **4 GB** or local video files up to **200 MB**"；>4GB 需 multipart，>10GB 需分片 | `文档` File API "**20GB (paid) / 2GB (free)**" |
| 时长 | `实测` "up to **2 hours** long, or up to **4 hours** when you analyze only a portion" | `文档` 1M context "up to **3 hours**… at low media resolution" |
| 成本 | `未找到`（未查定价页，本报告不写价格数字） | `文档` "**~300 tokens per second** of video at default media resolution" |

> `推断` **体积这一条就卡住一半**：本机源文件 **4.2–5.9 GB**，超过 TwelveLabs 的 4GB URL 上限。走 Gemini 可行，但按 300 token/s 估，一段 40 分钟素材 ≈ **72 万 token**；按 low media resolution 的 100 token/s 估 ≈ **24 万 token**。⚠ 这两个数字是**我按官方 token 公式换算的估算，不是实测账单**，且 20 号报告已实测「720p 优于 1080p、1080p 反降」，**本项目喂 2560×1440 在语义上是反优化**——必须先降到 1280×720 再送。
> `推断` 但即使技术上打通，**§0 那条仍然成立**：换掉「读图裁决」不提高准确率天花板。所以这条路是**候选生成器**，不是**裁决器**。

### 4.3 「telemetry 优先」这条最省事，但对我们此路不通

`实测` 直接抓 [overwolf.com/games](https://www.overwolf.com/games/) 全量游戏列表（98 个条目）并逐名检索：Featured 列表为 `League of Legends / Roblox / Counter-Strike 2 / Hearthstone / Fortnite / New World / PUBG / DOTA2`，Installed 列表含 `Paladins / Black Desert / Warframe / War Thunder / SMITE / Warface …`。**检索 `Naraka` → 命中 0 次。**

- `实测` Overwolf **没有《永劫无间》**，`未找到` 任何永劫无间官方 replay/demo 解析器或公开数据 API
- `实测` 《永劫无间》是 Unity 引擎、无公开 replay 格式（`文档` 中文维基：引擎 Unity，运营方网易/24 Entertainment）

> `推断` **A 架构（telemetry 优先）在永劫无间上此路不通**，这不是我们方法落后，是我们**没有那条数据源**。这解释了为什么我们必须做 B/C/E——**是被数据条件逼的，不是选择落后**。这条要在对外说明里写清楚，否则容易被误解成「别人 5 分钟出片我们 10 小时」。

---

## 5. 逐项判定表：过时 / 不过时

> 判据：**过时** = 2026 已有更成熟形态取代它，且取代后有可量化收益；
> **不过时** = 无更优形态，或本项目受数据/硬件条件限制无法替换。
> 每行给「凭什么判」。

| # | 我们当前的做法 | 判定 | 凭什么判（等级 + 出处） |
|---|---|---|---|
| 1 | **用子 Agent 抽帧 + Read 读联系表，做语义裁决** | 🔴 **过时** | `文档` Gemini 已把「模型自己决定看哪几帧」做成模型内建能力（agentic video understanding，**88% token 效率提升 / 长视频质量 +7%**）；`实测` TwelveLabs Pegasus 1.5 直接返回**带时间戳的 JSON**，`实测` 厂商首页自认 "**General-purpose models sample frames and guess**"。**我们在人工复刻一个已被商品化的能力。** |
| 2 | **派工 / 回收 / 换路靠人守** | 🔴 **过时** | `实测`（同会话 06 号报告 §3）LangGraph / Temporal / OpenAI Agents SDK / CrewAI 四家都已把 durable execution + `start_to_close_timeout` + `RetryPolicy` 做成框架内建；`实测` 我们实测的病是「3 路被服务重启吞掉、无人换路」——**这是缺机制，不是缺纪律** |
| 3 | **14 路全回收才能合成（barrier）** | 🔴 **过时** | `实测` TwelveLabs 用异步 task（`task.wait_for_done()` 轮询）+ 流式 `analyze_stream`；`实测` poseljacob 的 Reviewer 是渲完即评，不等其他 Agent。**干等 9.3 小时是 barrier 造成的，不是分析造成的。** |
| 4 | **每个子 Agent 自己抽帧、自己定参照系** | 🔴 **过时** | `实测` 本项目 skill 文档自己记着「不要让每个扫描员各自推一遍——推错一位整路证据与秒点全部对不上，**而且错得无声**」。业界形态是**一次解析、多方消费同一个结果**（`实测` poseljacob：Director 搜**素材索引**后产 EditPlan，不重新解析） |
| 5 | **机器重活只占 3.1%，纯等待 46.5%** | 🔴 **过时（是症状不是病）** | `实测` `.scratch\efficiency\out_phase_attribution.txt` 实测：span 62.52h / idle **29.05h (46.5%)** / active 33.47h，其中 F 审片 17.2%、D 合成 7.7%、C 分段扫描仅 5.7%。**重活占比低说明瓶颈在编排与等待，不在分析。** |
| 6 | **并行按时间轴切段分解** | 🟢 **不过时** | `文档` VideoAgent（30+ Agent，`arXiv:2606.23327`，声称 87–95% 编排成功率、API 成本降 60%）与 CutClaw（`arXiv:2603.29664`，Playwriter/Editor/Reviewer）都是多 Agent 编排。**并行分解是 2026 学术主流，不是落后。** |
| 7 | **分派 brief / 角色契约 / 禁跨段** | 🟢 **不过时** | `文档` VideoAgent 用 "intent parsing filters relevant tools" 做工具过滤；`实测` poseljacob 给每个 Agent 固定单一职责（Director 只选、Editor 只渲、Reviewer 只评）。**同构。** |
| 8 | **可回放证据（联系表 + 证据帧路径 + 每条结论可回查）** | 🟢 **不过时（且业界刚追上）** | `实测` VideoHighlighter "**Every run explains itself**… per-signal point breakdown"；`实测` hypecut "**Every decision is inspectable**… JSON sidecar and the EDL export… **first pass rather than your only pass**"。**两家 2026 项目把这当卖点，说明它是对的且必要。** |
| 9 | **机器门禁 `qa_gate.py`** | 🟢 **不过时（但已知不够）** | `文档` VideoAgent 报告 87–95% 编排成功率 = **承认有 5–13% 失败率**。`实测` 我们的病是「删掉一整场 233 秒战斗、7/7 全绿」——**这是「门禁抓不住语义漏战」，不是「不该有门禁」**。业界同样没有能抓语义漏战的门禁（见 `未找到` §6）。 |
| 10 | **预览 / 成片同源、预览优先** | 🟢 **不过时** | `实测` yingzheng：「FFmpeg、剪映交接包和 OTIO **都消费同一个批准时间线**」；`实测`（06 号报告 §1.5）OpusClip 自己的 git 历史是 "preview-first agent surface **先做的**，explicit export **后加的**"。**我们和商业方同一个结论。** |
| 11 | **整场战斗不许挖洞（`AGENTS §8.1`）** | 🟢🟢 **不过时，且我们领先** | `实测` 检索到的所有游戏向开源项目（crispy / cs-go-highlights / killclip / r6s / montage_maker）**没有一个**表达「战斗窗内不许挖洞」；crispy 只有 `second-between-kills` 一个合并参数（`实测` README）。`文档` Eklipse 官网自己承认不支持的游戏 "**Clip quality is lower than on supported games**"。**这一条是本项目独有的资产，不要在任何「升级」里被简化掉。** |
| 12 | **字幕全外挂、禁烧录禁内嵌** | 🟢🟢 **不过时，且我们领先** | `实测` §4.1 的所有商用工具（Eklipse / OpusClip / 剪映 / Munch）默认**烧录**。**我们是唯一一条反方向的硬规则。** |
| 13 | **成片从原始素材重渲、4K60 NVENC** | 🟢 **不过时** | `实测`（06 号报告 §2.5）editly / cutagent / ffmpeg-editlist 都做 JSON→成片，但换渲染器会丢掉已验证的 NVENC 链路（`AGENTS §2`「坏掉方向是安全」）。**判：借 schema，不换渲染器。** |
| 14 | **用通用大模型零样本判「在不在交战」** | 🟡 **我们目前没做，且不该做** | `实测`（20 号报告 §2/§6）EgoEsportsQA GPT-5 总分仅 **71.58**（多选一）；GameVibe ~57% 且**低于多数类 67.2%**；FPS-Bench VLM **30% vs 人类 72%**。**这条路的天花板已被公开测量过。换模型不解决问题（1 号判定换的是通道不是判据）。** |
| 15 | **永劫无间没有 telemetry 源，仍靠画面** | 🟡 **不是我们的问题，但必须写进对外说明** | `实测` Overwolf 支持列表 98 个游戏名里检索 `Naraka` 命中 0；`未找到` 永劫官方 replay/demo 解析器或公开数据 API。**A 架构对我们不存在。** |

---

## 6. 未找到（明确不编）

| 项 | 状态 |
|---|---|
| 「输入游戏录像 → 输出高光」的**成熟且活跃**开源项目 | `未找到`。最相关的 crispy 已停更 19 个月（158★），hypecut 2026-08 才建（2★） |
| AMD X-CLIP 那篇的**公开权重 / 数据集 / 代码** | `未找到`（论文原文只说 "in-house dataset"） |
| 任何**公开 API** 能吃《永劫无间》录像并输出战斗段时间戳 | `未找到` |
| 永劫无间**官方 replay / demo 解析器或公开数据 API** | `未找到` |
| 任何商用服务在**战斗窗内不许挖洞**这一语义上有对应设计 | `未找到`。Eklipse 只有 "continuity" 作为**打分项**（`文档`），不是**禁止项** |
| Gemini **agentic video understanding** 官方页直抓 | `未尝试成功`（ai.google.dev 直连三次超时）。本报告按 `文档` 记（搜索引擎返回的官方页正文段落），未按 `实测` 记 |
| 各家 API 的**价格** | `一律未取证`。本报告**不写任何价格数字** |
| OpenAI / Anthropic 的原生视频输入 API | `未找到`（本轮多轮检索未取到官方文档；**不下结论**，仅记录「未取证」） |
| 「多 Agent vs 单 Agent 在长视频上的成本/质量消融」公开研究 | `未找到`（多轮检索无果） |

---

## 7. 给下一轮的一句话（不含执行，只含判定）

1. **用户的直觉是对的，但错位**：落后的是「读图裁决」和「人守编排」，不是「多 Agent 并行分解」和「证据可回放」。
2. **换视频大模型不能提高准确率**——20 号报告已把零样本 VLM 在 FPS 交战判据上的天花板实测在 57–71%，且低于多数类的情形出现过。**天花板要靠非 VLM 硬判据抬。**
3. **最值得抄的一个**：hypecut 的**级联**——便宜信号先跑满全片、贵模型只跑候选窗、每条决策带 per-signal 打分可导出 sidecar + EDL。它同时解掉「机器重活仅 3.1%」「14 路全回收才敢合成」「证据散在散文里」三条。
4. **不要动的**：`§8.1` 整场战斗不许挖洞、全外挂字幕、4K60 NVENC 母版、预览/成片同源。**这四条业界没有对等物，属于我们领先，简化它们是净损失。**
5. **对外说明要写清**：我们 10 小时 vs 别人 5 分钟，差在**永劫无间没有 telemetry 源**（实测 Overwolf 98 个游戏里没有它），不是差在方法。这一条不写清楚会被误读成落后。

---

STATUS: DONE
（本轮零图片；未修改 skills / scripts / 任务目录；唯一写入为本报告）