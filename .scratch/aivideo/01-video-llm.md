# 01 · 长视频理解模型能否取代「抽帧 + 读图」

> 调研员角度：长视频 LLM/VLM 能力面。
> 调研日期：2026-10-05。所有结论标注 **实测 / 文档 / 推断 / 未找到**。
> 本机实测环境：`nvidia-smi` → **RTX 4060 Ti, 8188 MiB, driver 616.92**；RAM **31.11 GB**。
> 素材实测：`E:\OBS` 最近 8 个 4K60 原始文件 **4.23 GB – 5.99 GB**（单个）。

---

## 0 一页结论

| 问题 | 结论 | 依据等级 |
|---|---|---|
| 有没有能直接吃 19 分钟视频文件的模型？ | **有，至少 4 家**（Gemini / 阿里百炼 Qwen3.7-Qwen3.8 系 / 火山方舟 Doubao-Seed-2.x-pro / AWS Nova） | 文档 |
| 但源文件 4.2–6.0 GB，**全部超出各家上传上限**（50 MB / 512 MB / 2 GB） | 必须先渲代理 | 实测 + 文档 |
| 有没有直接输出「时间戳 + 事件」的？ | **有，而且这是官方示例提示词本身**（百炼、火山方舟文档里就是这个 prompt） | 文档 |
| 能吃多长？ | Gemini ~45 min(带音)/1 h(无音)；百炼 qwen3.8 系 **2 h**；火山方舟按 token 预算（≤80K）而非时长 | 文档 |
| 单请求多少帧？ | Gemini 1 FPS 固定；百炼 fps 可调 0.1–10，默认 2，`FPS_MAX_FRAMES=2000`；火山 fps 默认 1，帧数区间 **[16, 1280]**，**1280 帧 = 80K token ÷ 64 token/帧** | 文档 |
| 对**游戏画面**判读可靠吗？ | **未找到任何针对 FPS 游戏录像做事件/剪辑判读的评测**。最接近的三个都是「让模型去打游戏」，不是「让模型看懂已录好的对战」 | 未找到 |
| 项目自己的实测结论 | **640px 联系表会系统性把「战斗」误读成「面板」**，5 路扫描员无一幸免 | 实测（864） |
| **致命算术**：各家给整段 19 min 的 token 预算 ÷ 帧数 = **每帧只有 33–65 token ≈ 300–460 px 等效分辨率** | 而项目自己的硬规则是「定性必须 ≥960px，联系表只用于定位」 | 推断（基于文档数字） |
| 能不能取代抽帧读图？ | **不能取代「定性」，能大量取代「定位」**。最合适的用法是把它当**分诊器**：把 14 路扫描员从「全片逐段判读」压缩成「只在 AI 标红窗口做 960px 复核」 | 推断 |

**一句话**：云端长视频模型能在一次请求里把 19 分钟全看完，成本几分钱，但它**必然以 300–460px 等效分辨率看**——恰好落在项目已经用 864 任务实测证明「不够定性」的那一档。本地 8GB 跑得动 TimeLens2-2B/4B-GGUF，但只能吃约 3.7 分钟/请求，要切 6 段。两者都不能取代读图，只能取代「先粗后细」里的粗。

---

## 1 主流长视频 LLM/VLM：能吃多长、单请求多少帧

### 1.1 Google Gemini —— 唯一有「模型自己决定看哪」的产品化能力

**视频长度上限（Vertex AI 文档）**【文档】
- Gemini 3.1 Pro Preview / 3 Flash Preview / 2.5 Pro / 2.5 Flash 等：**带音频约 45 分钟，无音频约 1 小时**，每 prompt 最多 **10 个视频**，默认 **70 token/帧**
- Gemini 3 系列可选分辨率档：`MEDIA_RESOLUTION_HIGH` = **280 token/帧**
- Gemini 3.1 Flash-Lite Image：**无音频约 25 分钟**（128k 上下文封顶）
- File API 上传：**20 GB（付费）/ 2 GB（免费）** ← 本项目 5 GB 文件**能过**
- Gemini 2.5 起单请求最多 **10 个视频**（此前 1 个）

**抽帧与 token 公式**【文档】
- 默认 `static` 模式：**固定 1 FPS**，「timestamps are added every second」
- `media_resolution=low`：66 token/帧；默认档：258 token/帧（Gemini 3 前）；音频 **32 token/秒**
- 可设 `fps` 自定义采样；可用 `start_offset`/`end_offset` 切片
- 官方文档明确警告：1 FPS「**may miss details in videos with rapid motion or quick scene changes**」

**Agentic Video Understanding（本条是本次调研最重要的发现）**【文档 + 官方 blog】
- 2026-09-01 上线，支持模型：**Gemini 3.8 Flash / 3.7 Flash / 3.6 Flash / 3.5 Flash-Lite**
- 机制：`processing: "agentic"` → 服务端 **Think→Act→Observe 循环**，模型**按引用传视频**（初始只吃 metadata），然后
  1. **Transcript-first**：先读带时间戳的语音转写
  2. **Temporal zooming + 自适应 FPS**：只加载相关时间窗（如 14–16 秒），快速动作用 5–10 FPS，扫全局用 0.1 FPS
  3. **Audio track**：需要时抽音轨
  4. Observe → 再循环 → 综合
- 官方宣称（Gemini 3.7 Flash）：**token 最多省 88%、成本最多降 66%、准确率最多升 7%**
- 响应里会回传导航轨迹：`processing_call` / `processing_result`（或旧 API 的 `tool_type: "MEDIA_PROCESSING"`）
- 官方选型建议：**长视频 / 查询特定时刻 → agentic**；**< 5 分钟且要全片帧级精度 → static**

> **对本项目的致命细节**：agentic 的第一步是 **transcript-first**。永劫对局的音频是枪声/技能音/报点语音，语音转写信息量远低于「谁在打谁」。agentic 大概率会**跳过大量纯视觉战斗区间**。【推断，依据：官方 AI Studio 指南「Transcript-first: For spoken content or general orientation」+ 本项目素材以音效为主】

### 1.2 阿里云百炼 Qwen 系 —— 对中文/本项目最实用的一家

**视频时长与体积上限**【文档，`help.aliyun.com/zh/model-studio/vision`】
| 模型 | 视频时长 | 公网 URL 体积 |
|---|---|---|
| `qwen3.8` / `3.7` / `3.6` / `3.5` 系列 | **2 秒 – 2 小时** | ≤ **2 GB** |
| `qwen3-vl-plus` / `qwen3-vl-flash` / `qwen3-vl-235b-a22b-*` | 2 秒 – 1 小时 | ≤ 2 GB |
| 其他 Qwen3-VL 开源系列、`qwen-vl-max` | 2 秒 – **20 分钟** | ≤ 2 GB |
| `qwen-vl-plus`、其他 `qwen-vl-max`、Qwen2.5-VL 开源、QVQ | 2 秒 – 10 分钟 | ≤ 1 GB |
| 其他模型 | 2 秒 – 40 秒 | ≤ 150 MB |

- Base64 传入：编码后 < **10 MB**；本地文件路径：< **100 MB**
- 最多 64 个视频
- **音频理解：不支持对视频文件的音频进行理解** ← 与项目 faster-whisper 字幕链路天然互补，无冲突
- 图像列表传入（预抽帧）：qwen3.8/3.7/3.6/3.5 系列 **4–8000 张**；qwen3-vl-plus/flash **4–2000 张**

**抽帧与分辨率控制**【文档】
- `fps`：**取值 [0.1, 10]，默认 2.0**（每隔 1/fps 秒抽一帧）
- `max_frames`：**仅 DashScope SDK 可用**；超出时「自动在 max_frames 内均匀抽帧」
- 参考代码常量：`FPS = 2.0`、`FPS_MIN_FRAMES = 4`、**`FPS_MAX_FRAMES = 2000`**、
  `VIDEO_MAX_PIXELS = 640*32*32`（qwen3-vl-plus）或 `768*32*32`（其他）、
  **`VIDEO_TOTAL_PIXELS = 131072*32*32`**（qwen3-vl-plus）或 `65536*32*32`（其他）
- **帧分辨率随视频总长自动缩**：`total_pixels` 是全局硬预算

> **这是全部调研里最关键的一行**。19 min ÷ 2 fps = 2280 帧，被 `FPS_MAX_FRAMES=2000` 截到 2000 帧；
> 然后 `total_pixels` 65,536（或 131,072）÷ 2000 帧 ≈ **33（或 65）token/帧**。
> Qwen-VL token/像素 = 1/(32×32)，所以 33 token ≈ 184 px、65 token ≈ 258 px 的**短边等效**。【推断，基于官方公式】

### 1.3 火山方舟 Doubao-Seed —— 数字最透明的一家

**全部硬数字**【文档，`docs.volcengine.com/docs/ark/video-understanding`】
- **单视频最大 token：80K**（`max_video_tokens` 默认 **81920**）
- **抽帧数区间 [16, 1280]**；注释直接给算式：`80×1024 token ÷ 64 token/帧 = 1280 帧`
- 超帧数时降级规则：「按帧图像 **64 tokens**，时间间隔 视频时长/1280，均匀抽取 1280 帧」
- `fps` 字段默认 **1**，**最低 0.2**
- `min_frame_tokens` 默认 **384**，可调区间 **[64, 384]**
- 上传：默认存储 **512 MB**；传 `tos://` 到自建 bucket **2 GB**；Base64 **< 50 MB**（请求体 ≤64 MB）；公网 URL **< 50 MB**
- 时间戳格式（`doubao-seed-2.0` 及以后）：`<时间戳> second`，例 `4.0 second`
- 模型：`doubao-seed-2-1-pro-260628`（视频理解另有 Seed-Evolving）

> **19 min × 1 fps = 1140 帧 ≤ 1280，1140 × 64 = 72,960 ≤ 80K。刚好塞得下。**【推断】
> 但 `min_frame_tokens` 默认 384 会让 1140 帧远超 80K —— 必须显式压到 64。【推断】

### 1.4 明确**不能**直接吃视频的两家

- **OpenAI（GPT-4o / 5 系）**【文档 + Issue】：Responses API 的 `input_file` **不接受 mp4/webm/mov**。
  官方 cookbook 做法就是「用 ffmpeg 抽帧，然后当 image 数组发」。`openai/openai-node#1778`（2026-03-18）仍在请求原生视频输入，官方回复维持现状。→ **对 OpenAI 而言，「抽帧 + 读图」这一步无法绕过。**
- **Claude**【未找到官方文档；仅第三方 2026 年初文章称「Claude 模型不通过 API 支持直接视频输入」】
  → 标注为**未找到官方依据**。若要用 Claude，只能沿用官方 vision 路径（图片数组）。

### 1.5 快手可灵（Kling）等

**可灵是视频生成/编辑模型，不是视频理解模型。** 与本调研问题无关。【文档：`help.aliyun.com` 里的 Kling 条目全部是「图生视频/视频延长/参考生视频」】

### 1.6 其余

| 模型 | 视频直读 | 帧/时长上限 | 依据 |
|---|---|---|---|
| AWS Nova Lite/Pro | 是（AWS 有整篇「视频高光自动剪辑」方案） | **未找到** 具体帧数/时长/体积数字 | 未找到 |
| Kimi-K3 / GLM-5.3 / Qwen3.8-Max / Qwen3.8-Omni-Flash / Seed2.0-Pro | 未知逐项上限 | 只有 benchmark 分数（MMVU / LVBench），**没有帧数或时长规格** | 未找到 |

**LVBench 榜首（第三方聚合，2026-09）**：Gemini 3.8 Flash 87.1% > Gemini 3.7 Flash 85.4% > Qwen3.8-Max 81.8% > Qwen3.8-Omni-Flash 76.9%。
⚠ 该榜单只有 **5 个模型**、且被 BenchLM 排除在加权总分外 —— 参考价值有限。【第三方】

---

## 2 直接输入视频 → 输出「时间戳 + 事件」

### 2.1 官方示例就是这件事（可直接抄 prompt）

| 厂商 | 文档原文示例 | 链接 |
|---|---|---|
| **阿里百炼** | 「请你描述下视频中人物的一系列动作，**以 JSON 格式输出开始时间（start_time）、结束时间（end_time）、事件（event）**，请使用 HH:mm:ss 表示时间戳」 | `help.aliyun.com/zh/model-studio/vision` §视频理解 |
| **火山方舟** | 同上 + `是否危险（danger）` 字段 | `docs.volcengine.com/docs/ark/video-understanding` |
| **Vertex AI** | 「This sample shows how to add videos to Gemini requests…**return chapters with timestamps**」 | Vertex AI video-understanding 文档 |

→ **这不是「能不能」的问题，是「官方就教你怎么写」。**

### 2.2 「精确定位到某一秒」已经被产品化

- **Gemini Robotics ER 2**：`Moment finding` 能力，官方 prompt 就是
  `At what timestamp (in seconds) does the task reach successful completion? Return a JSON object: {"completion_time_seconds": <float>}`
  → 证明「返回秒级时间戳」是稳定的产品契约，不是提示词玄学。【文档】
- **Gemini Robotics ER 2 的 `Progress classification`**：把整段视频归到 `0-20% / 20-40% / … / 80-100%` 五档
  → **这个能力形态对本项目极有价值**：不要求模型给精确边界，只要求它给「进度档位」，容错高一个数量级。可用于「这场战斗走到哪了」的分诊。【推断】

### 2.3 开源侧：专门做「时间戳定位」的模型已经成熟

**TimeLens / TimeLens2（腾讯 ARC + 南京大学 MCG）** —— 这是本次调研对本地方案影响最大的发现。

| 项 | 内容 | 依据 |
|---|---|---|
| 许可 | **Apache-2.0**，HF 上有权重 | HF model card |
| 输入 | 视频 + 一句自然语言 query | 论文 |
| 输出 | **JSON 数组的 `[start, end]` 秒对** | HF model card |
| 模型 | `MCG-NJU/TimeLens2-2B`（Qwen3-VL-2B 底座）/ `-4B`（47.7 平均 mIoU）/ `-8B`（48.0）；上一代 `TencentARC/TimeLens-7B`（Qwen2.5-VL-7B）/ `-8B`（Qwen3-VL-8B） | HF / GitHub |
| 官方推理配方 | `fps: 2.0`, `min_pixels: 32*32`, `max_pixels: 480*480`, **`total_pixels: 128000*32*32`** | HF model card（4B） |
| 上一代评测默认参数 | **`FPS=2`、`total_tokens=14336`、`min_tokens=64`**；过滤数据目录名里含 `maxframes-448` | GitHub README |
| 长视频能力 | 论文正文举例：**在 93.7 分钟的视频里定位到 ~4750 秒处的事件**，并能召回同一事件在片中的 5 段稀疏复现 | 论文 §引言 |
| 准确度 | 2B/4B/8B 分别比各自 Qwen3-VL 底座高 **14.2 / 13.0 / 18.1 mIoU**；4B 平均比 `Qwen3.5-397B-A17B` 高 **7.5 mIoU** | 论文 |
| 七个 benchmark | Charades / ActivityNet / QVHighlights / **VUE-TR** / **VUE-TR-V2**（长视频） / **MomentSeeker**（问句形式） / **Ego4D-NLQ** | 论文 |
| 量化版 | **`mradermacher/TimeLens2-4B-GGUF`（Q4_K_M）已存在**，HF model tree 显示 2B/4B 各有 1 个量化 | HF |
| 依赖 | transformers 路径需 `flash-attn==2.7.4.post1`（编译）→ **Windows 上是麻烦**；走 llama.cpp / Ollama 可绕开 | GitHub README |

**这个模型族几乎就是本项目要的「时间戳定位器」的现成实现**，而且是 Apache-2.0。

**其他相关但未评估的**（列出，不背书）：Momentor、VTimeLLM、VTG-LLM、TimeRefine(WACV 2026)、MeCo(ICLR 2026)、Chrono(ICCVW 2025)、VideoMind、EVA、Video-R1。

### 2.4 成品服务（可直接买，但都不是为游戏设计的）

| 服务 | 定位 | 对本项目的硬限制 | 依据 |
|---|---|---|---|
| **阿里 影视传媒视频理解** | 异步离线，单视频 **≤1 小时 / <450 MB / ≤1080P**；多模态处理 **2.8 元/小时视频时长** + 大模型 token；含**角色识别** 0.03 元/分钟 | **450 MB + 1080P** ← 本项目 5 GB 4K 源必须先转码 | 文档 |
| **火山 AI MediaKit 智能剪辑（vibe-editing）** | 自然语言 → 多轨剪辑 → 云端渲染；含「精彩片段提取：识别强冲突、强情绪等高能片段」 | 面向 AIGC/影视二创 | 文档 |
| **火山 长视频理解（视频点播）** | 离线批量 | — | 文档 |
| **百度 智能集锦** | 影视/短剧向 | 面向剧集，非游戏 | 文档 |
| **七牛 视频剪辑 Agent** | 商业剪辑 Agent | — | 文档 |
| **AWS Nova 方案（AWS 官方博客）** | 给了两条路：**纯 VLM**（直接读全片输出高光起止点）与 **VLM + 多模态嵌入 MME**（先让 VLM 出高光描述，再把片子按 2–3 秒切片做 embedding 检索定位）。官方结论：**纯 VLM 适合中短片；超长视频对模型能力和提示词工程要求显著提升** | 无游戏专项 | AWS 官方博客 |

> AWS 那篇的**「VLM 出语义 + embedding 精确定位」双阶段**思路，和本项目 §3.2.3「代理视频 + 分层复核」是同构的，值得作为架构参考。【推断】

### 2.5 商业游戏剪辑工具：全都不是「看懂游戏画面」

| 工具 | 自述原理 | 依据 |
|---|---|---|
| **Eklipse** | 「relies mainly on **gameplay events, audio spikes, and scene changes**」，另有 Voice Command 手动兜底 | eklipse.gg 官方对比页 |
| **Choppity** | 「detects highlights through **audio analysis — vocal excitement, shouting, rapid commentary, emotional spikes**」 | choppity.com |
| **Insights Capture** | **录制时实时**用「game-specific AI」打标，宣称覆盖 10,000+ 游戏 | insights.gg |
| **WayinVideo** | 「combines game-specific AI with video understanding」，宣称覆盖 FPS/MOBA/大逃杀/RPG | wayin.ai |

> **关键观察**：这些工具的信号源是 **游戏 API 事件 + 音频能量 + 主播语音兴奋度 + 场景切换**，
> **没有一家声称「用视频理解模型看懂 FPS 战斗结构」**。
> Eklipse 的对比页甚至把「subtle highlights easier to miss」当成自己的差异化点来说明工具差异。
> → **「靠视频模型判读游戏战斗」这件事在商业上没有被验证过。**【文档（各家自述）+ 推断】

---

## 3 对游戏画面的判读可靠性

### 3.1 **未找到**：任何针对 FPS 游戏录像做事件/剪辑判读的评测

穷举了以下方向，均**未找到**「第一人称 HUD + 血条 + 伤害数字 + 技能特效」这种素材上的评测：

- FPS gameplay recording → highlight / event / editing benchmark：**未找到**
- 《永劫无间》或同类国产竞技游戏的 AI 剪辑实测：**未找到**（搜到的网易伏羲相关文章只讲游戏内反外挂与 AI 人机，2023 年，与剪辑无关）

### 3.2 找到的最接近物 —— 但全是「让模型去打游戏」，不是「让模型看懂已录好的对战」

| 基准 | 内容 | 与本项目的关系 | 关键负面结论 |
|---|---|---|---|
| **LMGame-Bench**（ICLR 2026） | 6 款游戏、13 个模型，Gym 式 API，模块化 harness（perception / memory / reflection） | **不可直接迁移**（是 agent 玩，不是读录像） | 报告原文：LLM「**struggle to understand game boards from only images**」；「**Gemini shows repeated failures in spatial parsing**. Even interpreting a simple board state visually is unreliable」；还暴露「low FPS problem」与「knowing-doing gap」 |
| **VideoGameBench** | 23 款 Game Boy/MS-DOS 游戏，零样本实时通关 | 同上 | 最好模型 Gemini 2.5 Pro 实时通关率 **0.48%**，lite 模式 **1.6%**；无模型到达 10 个测试关中的第 1 个 checkpoint |
| **Orak** | 12 款游戏，agentic 模块消融 + 微调集 | 同上 | — |
| Cradle / DSGBench / Balrog / LVLM-Playground | agent 玩 | 同上 | 论文表格已列 |
| **Video-MME**（CVPR 2025） | 通用视频 QA，30 个细类里**含 esports** | 最接近的通用视频 QA | 有 `Short / Medium / Long` 三档；长视频档普遍明显掉分；`w/ audio` 与 `w/o subs` 对比显示音频与字幕贡献很大 |

> **结论**：整个领域**没有**「录好的 FPS 对战 → 事件时间戳」这个任务的公开评测。
> 所有 game benchmark 测的是**控制能力**，不是**理解能力**；所有 long-video benchmark 测的是
> 「找一句话对应的时刻」（moment retrieval），**没有**一个测「这场战斗从 engage 到 outcome 的完整边界」。
> → **任何声称「模型能判读你的永劫录像」的方案，都是未经验证的。**【推断，基于以上穷举】

### 3.3 项目自己的实测（比任何公开评测都更贴题，且结论是负面的）

来自 `skills\naraka-highlight-studio\references\complete-combat-roughcut.md` §3.2.1：

> **640px 联系表会系统性地把「战斗」误读成「面板」。** 864 重剪轮 **5 路扫描员各自独立踩到，没有任何一路是看了联系表就下对的**：
> 紫色敌人血条读成「选择强化面板」、绳索摆荡读成「举弓瞄准 + 绿色弹道」、`1.6 恢复` 打药读成「法门面板已开」、持刃冲刺读成「疑为倒地」。

且：

> 永劫 HUD 上这些是常驻/临时提示文本，**位置与敌方名牌很接近，极易误读**：
> `攻击提升 / 防御提升 / 恢复 / 闪避 / 格挡 / 暴击 / 还阳·愈 / 护甲回复 / 灼烧`。
> 看到「某某 + 提升」这种结构一律先当**增益**处理，不当名字。

> 8× 放大复核后的真相：seg4「敌方名『怎么可能』在 250 与 334 两次出现 ⇒ 同一队」——逐字是「**吃什么饭**」，是**本方 ② 号队友**；seg6「敌方『双刀绝 Spank』红血条 ⇒ 同一场」——那是「**攻击提升**」增益横幅，不是敌方名牌。

而项目的硬规则已经写成：

> **联系表只用于「定位」，不用于「定性」。** 被标为「面板 / 舔包 / 补给 / 倒地 / 选人」的候选删除段，**必须先出 960px 单帧复核再定性**。

> ⚠ **注意执行主体是「扫描员 Agent + Read 工具」，即同代或更新的一代多模态模型，且用的是 640px。**
> 也就是说：**当前能力最强的模型在 640px 下就已经把紫色敌方血条读成「强化面板」了。**【实测】

**把云端长视频模型的等效分辨率代进去**（§1.2 算术：33–65 token/帧 ≈ 184–258 px；Gemini 低分辨率档 66 token/帧；火山 64 token/帧）：
→ **它们的默认观看分辨率比已被证伪的 640px 还低 2.5–3.5 倍。**【推断，基于文档公式 + 项目实测】

> **这是本报告最重要的一个数。它独立地、量化地解释了为什么长视频模型不能取代读图做定性。**

### 3.4 那什么信号是可靠的？

项目 864 已经找到了答案，而且**零看图预算**：

> **能用机器读数就不要用眼睛判读。** 864 裁决最有价值的一列证据不是画面描述，是**弹匣读数曲线**：
> ```
> 441–447 = 50/50 → 448 = 46 → 450 = 44/50 → 450–499 冻结 44/50 整整 50 秒
>         → 500 = 41 → 502 = 37（伤害 334）→ 504 = 34 → 510 = 31（伤害 156）
> ```
> **弹药只减 ⇒ 玩家在开火；弹药冻结 ⇒ 玩家没在开火。** 一眼给出「有没有在交战」的硬答案，**零看图预算**。

> **扫描员取证清单**：凡是「这一段到底在不在打」有争议，除逐帧三信号外**必须补一条 HUD 机器读数曲线**（弹匣数 / 体力值 / 队友血条数）作为第二独立信号。864 若一开始就有这条曲线，444–495 的争议根本不会产生。

**但 `.scratch\efficiency\04-automation.md` §5.2-d 同时警告**：

> 864 的曲线是**人读出来的正确答案**——这正好是天然的阳性对照集。
> 但 OCR 会读错 HUD（`攻击提升` vs 敌方名牌，见 864 §4.1）。
> **先在 861+864 的已知答案上跑，只报读数与不确定度，不报「是否开火」。**

→ 这条**和视频 LLM 是互补而非竞争关系**：HUD 读数曲线提供「有没有开火」的**零看图硬信号**，视频 LLM 提供「这一段大概在干什么、边界在哪」的**语义分诊**。两者都不足以单独定性。

---

## 4 云端 API：19 分钟 4K60 素材的成本与耗时（按 1 fps 抽帧）

### 4.1 前置硬成本：**必须先渲代理**【实测 + 文档】

`E:\OBS` 实测单文件 4.23–5.99 GB。而：
- 火山方舟：默认存储 512 MB / TOS 2 GB / Base64 50 MB / URL 50 MB
- 百炼：URL 2 GB / Base64 10 MB / 本地路径 100 MB
- Gemini File API：20 GB ✅ **唯一能直传 5 GB 的**

项目 §3.2.3 已有现成配方（864 实测 2 分 06 秒渲完，`nb_read_frames` 与源一致，`proxy_offset = 0`）：

```bash
ffmpeg -i <source> -vf scale=960:540 -fps_mode passthrough -c:v libx264 -preset veryfast <proxy>.mp4
```
19 min @ 960×540 约 **200–400 MB**，落在火山 512 MB / 百炼 2 GB 内。**本项目已有此步骤，改造成价为 0。**

### 4.2 token 算术（19 min = 1140 s）

| 路线 | 帧数 | 每帧 token | 帧 token | 音频 token | 合计 |
|---|---|---|---|---|---|
| Gemini static, `media_resolution=low` | 1140 | 66 | 75,240 | 36,480 | **≈ 111.7 K** |
| Gemini static, 默认档 | 1140 | 70（Gemini 3 默认） | 79,800 | 36,480 | **≈ 116.3 K** |
| Gemini static, `MEDIA_RESOLUTION_HIGH` | 1140 | 280 | 319,200 | 36,480 | **≈ 355.7 K** |
| Gemini **agentic** | 模型自选 | — | — | — | 官方：**最多省 88%** |
| 百炼 `qwen3-vl-plus`（fps=2） | 2000（被 `FPS_MAX_FRAMES` 截断） | **≈ 65**（131,072 预算） | ≈ 131 K | 不支持音频 | **≈ 131 K** |
| 百炼其他 Qwen3-VL 开源（fps=2） | 2000 | **≈ 33**（65,536 预算） | ≈ 65.5 K | 不支持 | **≈ 65.5 K** |
| 火山 `doubao-seed-2-1-pro`（fps=1） | 1140 | 64（须显式压 `min_frame_tokens`） | 72,960 | — | **≈ 73 K**（≤80K ✅） |

【推断，算术基于文档给出的 token 公式与上限；实际以 `countTokens` 为准】

### 4.3 费用

⚠ **价格来源混杂且互相矛盾**（官方页面在本环境多次 fetch 超时），下表标注来源，**使用前须自行到官方控制台复核**。

| 模型 | 输入 /1M | 输出 /1M | 19 min 一次输入成本 | 来源 |
|---|---|---|---|---|
| Gemini 3.5 Flash-Lite（AI Studio） | **$0.15** | $1.25 | **$0.017** | 第三方聚合（pricepertoken / cloudprice） |
| Gemini 3.5 Flash-Lite（Google 直连） | $0.54 | $4.50 | $0.060 | 同上 |
| Gemini 3.7 Flash（2026 年内促销价） | **$0.75** | $3.75 | **$0.088** | 第三方转述官方（gptunnel.ru，2026-08-15） |
| Gemini 3.7 Flash（2027 起标准价） | $1.50 | $7.50 | $0.174 | 同上 |
| Gemini 3.8 Flash（2026 年内促销价） | $0.75 | $3.75 | $0.088 | 官方页片段 `ai.google.dev/gemini-api/docs/pricing` |
| 百炼 `qwen3.7-plus`（输入 ≤256k） | 1.6 元 | 6.4 元 | **≈ 0.21 元** | 阿里云开发者社区（限时 8 折）；原价 2/8 元 |
| 百炼 `qwen3.7-plus`（256k<输入≤1m） | 4.8 元 | 19.2 元 | ≈ 0.63 元 | 同上 |
| 火山 `doubao-seed-2-1-pro` | **未找到** | 未找到 | 未找到 | — |
| 阿里 影视传媒视频理解 | 2.8 元/小时视频时长 + token | — | **≈ 0.89 元**（视频时长费）+ token | 官方文档 |

输出侧：19 min 的完整事件清单估 5–15 K token（**推断，无实测**），按 Gemini 3.7 Flash 促销价 ≈ $0.02–0.06。

> **结论：钱不是问题。** 一次全片扫描的输入成本在 **$0.02 – ¥1** 量级，比本地渲一份 4K 分段的时间成本还低。
> **即使跑 20 轮迭代，一局总成本也在 $1–¥20 量级。**

### 4.4 耗时

- **未找到** 19 分钟游戏素材的端到端 API 延迟实测。
- **推断**：static 模式 ≈ 116 K token prefill，Flash 级模型 prefill 吞吐按 10–20 K tok/s → **prefill 6–15 s**；agentic 模式要多轮工具调用（每次 seek 都要重新加载片段），官方文档已警告「长视频或复杂 prompt 时 agentic 更慢，建议用 streaming」，**推断 1–5 分钟**。
- 上传/下载：5 GB 文件上传按 100 Mbps 约 **7 分钟**；渲 960×540 代理仅 **2 分 06 秒**（864 实测）→ **先渲代理反而更快**。

---

## 5 本机可行性：RTX 4060 Ti 8GB + 31GB RAM

### 5.1 候选模型与实测/文档数字

| 模型 | 参数 | BF16 权重 | 8GB 可否 | 官方下载体积 | 依据 |
|---|---|---|---|---|---|
| `Qwen/Qwen3-VL-2B-Instruct` | 2.1 B | ~4.0–4.4 GB | ✅ 勉强 | **未找到精确值**（HF 页面本环境 fetch 失败） | 第三方 aquanode：BF16 权重 4.0 GB、含开销 4.8 GB |
| `MCG-NJU/TimeLens2-2B` | 2B（Qwen3-VL-2B 底座） | ~4.4 GB | ✅ | 未找到精确值，HF 显示有 1 个量化 | HF model card |
| `Qwen/Qwen3-VL-4B-Instruct` | 4B | ~8.8 GB | ❌ 超了 | — | 第三方：4B FP16 ≈ 8 GB 最小 |
| `MCG-NJU/TimeLens2-4B` | 4B | ~8.8 GB | ❌（BF16） | **`mradermacher/TimeLens2-4B-GGUF` Q4_K_M ≈ 2.5–3 GB（推断）** | HF 显示 4B 有 1 个量化 |
| `Qwen/Qwen3-VL-8B-Instruct` | 8B | ~16 GB | ❌ | — | 第三方：8B FP16 最低 18 GB |
| `TencentARC/TimeLens-8B` | 8B | ~16 GB | ❌ | — | GitHub |
| `Qwen3-VL-30B-A3B`（MoE） | 30B | ~24 GB(FP8) | ❌ | — | Qwen README |

**Ollama 侧（文档）**：`qwen3-vl:2b` **1.9 GB**、`qwen3-vl:4b` **3.3 GB**、`qwen3-vl:8b` **6.1 GB**，均标 256K 上下文。
⚠ 但 Ollama 页面明确标的是「**Text, Image**」，**未标 Video** → Ollama 是否支持 Qwen3-VL 视频输入：**未找到确认**。

**Qwen3-VL 系列通用规格**【文档】
- 全系原生 **256K** 上下文，可扩到 **1M**；`total_pixels` 官方建议 **< 24576×32×32**（避免输入序列过长）
- 官方 README 明确：「handles books and **hours-long video** with full recall and second-level indexing」
- 时间编码：每个视频时间片前置文本时间戳，例 `<3.0 seconds>`（Time–Timestamp Alignment）
- 官方 cookbook 视频示例参数：`max_frames=2048`, `sample_fps=2`, `total_pixels=20480*32*32`
- **要求 `transformers >= 4.57.0`**，否则报 "unrecognized architecture"

### 5.2 本地能吃多长（关键约束）

上一代 TimeLens 官方评测默认：**`FPS=2`、`total_tokens=14336`、`min_tokens=64`**，过滤数据目录名里写着 **`maxframes-448`**
→ **448 帧 ÷ 2 fps ≈ 224 秒 ≈ 3.7 分钟/请求**
→ **19 分钟要切 6 段**。【推断，基于官方脚本默认值】

TimeLens2-4B 官方配方 `total_pixels: 128000*32*32` = **128 K token**
→ 在 8GB 上**远超**（Qwen 自己的建议上限是 24,576）。**必须把 `total_pixels` 砍到 16 K–24 K 量级**，这会进一步降低每帧分辨率。【推断】

**吞吐**：
- **未找到** Qwen3-VL-2B / TimeLens2-2B 在 RTX 4060 Ti 上的视频实测速度。
- 旁证：社区报告 Qwen3-VL-4B CPU-only 吞吐 **0.5–2 tok/s**（31GB RAM 下 CPU 回退，**基本不可用**）；`localvram.com` 给的 Qwen3-VL-8B 在 RTX 3090 上 16.5 tok/s。【第三方】
- **推断**：4060 Ti 8GB（~26 TFLOPS FP16，带宽 288 GB/s）跑 2B 模型，输出应在 **15–40 tok/s** 区间；单次事件清单输出 2–5 K token → **每个 chunk 约 1–5 分钟**，6 个 chunk 串行 **10–30 分钟**。若要并行，2B 模型 4GB 权重 + 31GB RAM 可跑 2 路。
  ⚠ **这是推断，不是实测。必须先跑一个 chunk 校准。**

### 5.3 Windows 上的具体坑

- TimeLens / TimeLens 官方 README 要求 `flash-attn==2.7.4.post1`（源码编译）+ CUDA 12.4 → **Windows 原生编译是已知痛点**。【文档 + 推断】
- **绕开路线**：走 `llama.cpp` / `Ollama` 的 GGUF 路径（`TimeLens2-4B-GGUF` 已存在），不需要 flash-attn。
  ⚠ 但 **llama.cpp 的 Qwen3-VL 视频输入（mmproj）在本环境的可用性：未找到确认**，需实测。
- 本项目 `.video-tools\venv` 建在系统 Python 上（AGENTS.md §2.2），装 Qwen3-VL 需要 `transformers>=4.57.0` + `qwen-vl-utils[decord]` → **会污染现有 venv**。
  → 建议按 AGENTS.md 的环境铁律，**另建一个基于系统 Python 的 venv**，别塞进 `.video-tools\venv`。

---

## 6 对本项目的适配判断

### 6.1 能不能取代「抽帧 + 读图」？

| 子任务 | 现状 | 长视频模型能否取代 | 依据 |
|---|---|---|---|
| 全片粗筛（哪些秒段可能有战斗） | 14 路扫描员 + 联系表 | ✅ **能，且是最大收益点** | 分辨率算术 + agentic 能力 |
| 战斗窗口**定性**（这段到底在不在打） | 960px 复核 + 三信号 + HUD 曲线 | ❌ **不能**（300–460px 等效，低于已被证伪的 640px） | 864 实测 + token 算术 |
| `engage_start` / `outcome_time` **秒级边界** | 人工 + 多路对抗审 | ⚠ **只能提候选**，不能定案（TimeLens2 在 93.7 min 上能做到，但那是 benchmark 场景） | 论文 + 推断 |
| 战斗中停顿 vs 跑图的区分 | 四信号（敌我锁定/伤害数字/红血条/战斗语音） | ⚠ **HUD 读数曲线比 VLM 强**，且零看图预算 | 864 实测 |
| 敌方身份（同名 = 同一队） | 需 8× 放大逐字确认 | ❌ **明确不能**（864 两次都栽在「攻击提升」vs 敌方名牌） | 864 实测 |
| 删除段审计（`deleted_intervals`） | 人工 13 个 `delaudit_*` 脚本 | ❌ **绝不能自动化** | `04-automation.md` §5.2-a |

### 6.2 `04-automation.md` §5.2-a 已经把红线写死了

> #### (a) 🔴 最危险：**「删除段无战斗」自动判定**
> 「转写否定这一重不成立」，稀疏图/无语音**证不了"没发生战斗"**。把 `voice_index.py` 的关键词扫描升成门禁，就会把"无战斗词"直接翻译成"无战斗"，**产出一个必然出错、且带 PASS 标记的结论**。
> **正确形态**：门禁是 **"缺席审查"门**，不是 **"缺席战斗"门** —— 扫描结果只决定"要不要审"，不决定"审出没有"。

→ **任何把视频 LLM 输出直接当 `combat_*.json` 写入的改造，都会踩这条红线。**
→ 正确形态：**视频 LLM 的输出只写进 `reports\`，只用于决定「派哪几路扫描员去看哪几个窗口」。**

### 6.3 推荐架构（在现有流程上加一层，不替换）

```
源 4K60 MP4 (E:\OBS, 5 GB, 只读)
  │
  ├─[已有] ffmpeg 渲 960×540 代理 (2分06秒, proxy_offset=0)   ← 已有配方
  │
  ├─【新增·机器重活】三条零看图信号并行：
  │    A. faster-whisper 转写        (已有) ─┐
  │    B. PySceneDetect 场景变化     (已有) ─┤
  │    C. 弹匣/血量 HUD 读数曲线     (★新建, 04-automation §3 候选 #5)
  │                                        │
  │    D. ★云端 1 次 agentic 视频理解 ──────┤
  │       输入：代理 MP4 (200-400MB)
  │       输出：JSON events [{start_time, end_time, event, confidence}]
  │       模型：gemini-3.7-flash(agentic) 或 百炼 qwen3.7-plus
  │       成本：$0.09 – ¥0.63/局
  │                                        ▼
  │                              合并成「候选窗口台账」（单一可核文件）
  │
  ├─【改派工】14 路扫描员不再平分全片，改为按台账的冲突密度分配：
  │    · 台账高置信 + HUD 曲线支持 + 转写支持  → 只抽 3–5 帧做定位性核对
  │    · 台账冲突 / 低置信 / 缺失              → 全套 960px 复核（保留现有全部规则）
  │    · 台账完全无事件但 HUD 曲线有开火        → ★强制人工（防漏战，这是最危险的洞）
  │
  ├─【新增门禁】缺席审查门（不是缺席战斗门）：
  │    deleted_intervals 中任一段若命中 combat_hits，
  │    必须存在署名人工裁决记录，否则 FAIL
  │
  └─[已有] qa_gate.py / 预览渲染 / 多路对抗审 / 审片员 / 4K 出片
```

**改造后扫描员的工作形态变化**：
- 从「14 路各平分 19 分钟、逐段联系表判读」 → 「按台账重点复查 + 少量盲区抽查」
- **不减少任何一条现有硬规则**（960px 定性、8× 放大逐字、HUD 曲线第二信号、帧↔秒标定、代理回源复核）
- 14 路的**保留价值从「找战斗」变成「找 AI 和 HUD 曲线都漏掉的战斗」** —— 这才是漏战的唯一真实来源

---

## 7 改造代价

| 项 | 工作量 | 说明 |
|---|---|---|
| 云端 API 客户端脚本（上传 + prompt + 解析 JSON + 写 `reports\`） | **0.5–1 天** | 约 150–250 行 Python；已有 `resolve_ffmpeg.ps1`/代理渲染配方可复用 |
| 代理渲染接入固定工作流 | **0.5 天** | §3.2.3 配方已存在，只需在派工前固定调用 |
| HUD 读数曲线脚本 `scripts\hud_curve.py` | **1–2 天** | `04-automation.md` §3 列为候选 #5，估 25 min/争议段；**必须按 §5.2-d 先立阳性对照（861+864 已知答案），不足则 ABSTAIN** |
| 候选窗口台账 + 派工生成 | **1 天** | 台账 schema + `build_lane_plan` 改造（已有 3 份副本，见 §1 #15） |
| 缺席审查门进 `qa_gate.py` | **0.5 天** | 需补双向 fixture，防止再出「全绿假 PASS」 |
| TimeLens2-2B/4B-GGUF 本地试跑 | **1–2 天** | 含 Windows 上 flash-attn / llama.cpp 路线选择、venv 隔离、单 chunk 吞吐校准 |
| **合计（只做云端 + HUD 曲线）** | **≈ 3.5–5 天** | |
| **合计（再加本地 TimeLens2）** | **≈ 5–7 天** | |

**成本侧**：API 每局 $0.09–¥0.63；本地无 API 成本，只有电费和一次模型下载（TimeLens2-4B-GGUF 推断 2.5–3 GB）。

---

## 8 风险

| # | 风险 | 严重度 | 依据 | 缓解 |
|---|---|---|---|---|
| R1 | **把 300–460px 等效分辨率的模型输出当「定性」**，重演 864 的「战斗读成面板」漏战 | 🔴 致命 | 864 实测 + token 算术 | 硬编码进 prompt 与产出路径：只写 `reports\`，永不直接进 `combat_*.json` |
| R2 | **Gemini agentic 的 transcript-first 在枪声为主的素材上漏掉纯视觉战斗** | 🔴 高 | 官方 AI Studio 指南机制描述 + 素材特征 | 默认走 static 1 fps；agentic 仅作二次分诊 |
| R3 | **代理视频体积/时长超限**（火山 512MB / 50MB URL） | 🟠 中 | 文档 | 已有 960×540 配方，落到 200–400 MB，**渲完必须实测 `ffprobe` 体积** |
| R4 | **`min_frame_tokens` 默认 384 导致火山方案直接超 80K 报错** | 🟠 中 | 文档 | 显式设 `min_frame_tokens=64` + `max_video_tokens` |
| R5 | **成本与价格随时间剧烈波动**（3.5-Flash-Lite 输入价 90 天内从 $0.54 跌到 $0.15；Gemini 3.7 Flash 促销价 2027-01-01 到期翻倍） | 🟡 低 | 第三方价格追踪 | 单局成本量级 $0.1，波动不致命；写进 `reports\` 时记模型 ID + 日期 |
| R6 | **幻觉时间戳**（编造不存在的秒点） | 🟠 中 | INFACT(ACL 2026) 显示视频 LLM 在证据腐化下稳定性下降；VideoGAIA 显示前沿模型 agentic 视频理解 <60% | 输出必须与 PySceneDetect / HUD 曲线 / 转写**三路交叉**，不一致即 `needs_review` |
| R7 | **本地 8GB 装不下 4B BF16、Windows flash-attn 编译失败** | 🟠 中 | 文档 + 推断 | 优先 2B；4B 走 GGUF；本地方案**不作为第一优先**，先跑通云端 |
| R8 | **新增自动化引入新的假 PASS 源** | 🔴 高 | `04-automation.md` §5 全节 | 一律用「缺席审查门」形态；每个新门禁先立阳性对照 |
| R9 | **把「找战斗」外包给模型后，14 路扫描员变成橡皮图章** | 🟠 中 | 推断 | 保留「台账无事件 + HUD 有开火」区间的**强制盲区抽查**；台账本身不进 QA 判定 |
| R10 | **素材上传云端 = 素材外流** | 🟡 低 | — | 素材是自有游戏录像，无第三方版权；仍应在 `reports\` 记录上传了哪一局、哪一模型 |

---

## 9 可行性结论

### 9.1 云端

**可行。** 一条请求看完 19 分钟，成本 $0.09–¥0.63（Gemini 3.7 Flash agentic / 百炼 qwen3.7-plus），
Gemini File API 20 GB 甚至能直传 5 GB 原片（但仍建议先渲代理，代理更快更省）。
输出形态（JSON 时间戳 + 事件）是**官方示例提示词本身**，不是需要逆向的技巧。

**但它的天花板被两条硬约束钉死**：
1. 分辨率 300–460px 等效 —— **低于项目已实测证伪的 640px**
2. 没有任何公开评测证明它能判读 FPS 游戏战斗

→ **定位：最好的「分诊器」，不是「判读器」。**

### 9.2 本地

**勉强可行，只够做「时间戳定位器」，不够做判读器。**
- 能跑：`TimeLens2-2B`（BF16 ~4.4GB）或 `TimeLens2-4B-GGUF Q4_K_M`（Apache-2.0，下载约 2.5–3GB）
- 单请求上限约 **3.7 分钟**（448 帧 @ 2 fps），**19 分钟要切 6 段**
- `total_pixels` 必须从官方的 128K 砍到 16–24K（Qwen 自己的建议上限），分辨率进一步下降
- 速度**未实测**，推断 10–30 分钟/局；Windows 上 flash-attn 是坑，GGUF/llama.cpp 路线待验证
- 31GB RAM 的 CPU 回退只有 0.5–2 tok/s，**不可用**

### 9.3 一句话回答调研问题

> **长视频理解模型可以取代「抽帧 + 读图」里的「读全片找候选」这一步，但取代不了「960px 定性」这一步**，
> 而定性恰恰是本项目 864 任务实测证明**唯一不可省略**的那一步。
> 正确用法是把它插在**代理视频 → 候选窗口台账**这一层，让 14 路扫描员从「平分全片」变成「按台账重点复查 + 盲区抽查」，
> 并把省下来的预算全部投到 `hud_curve.py`（HUD 机器读数曲线）——**那才是零看图预算的真信号**。

### 9.4 建议的最小验证实验（1 天，决定是否继续）

在 **869 已有素材 + 864 已知正确答案**上跑一次，做三件事：

1. **渲 960×540 代理**（已有配方，2 分 06 秒），上传火山方舟，`min_frame_tokens=64` + `max_video_tokens=80000`，用官方 JSON-events prompt
2. 把返回的 events 与 **864 时间线里 5 场战斗的 `engage_start` / `outcome_time`** 逐场对：算「召回」和「边界误差（秒）」
3. **同时**把代理上的弹药读数曲线跑出来，看它能否在零看图预算下给出「有没有开火」

**判定标准**（先定，避免又造一个假 PASS 门）：
- 若 AI events 对 864 五场战斗**召回 ≥4/5**，且弹药曲线与 864 人工读数**一致** → 值得投 3.5–5 天改造
- 若任一项不达标 → **停**，不要把 300–460px 的输出接进 `combat_*.json`

> 这一步本身就是 `.scratch\efficiency\04-automation.md` §5 反复强调的「**先立阳性对照**」。

---

## 10 来源清单

**官方文档**
- Gemini 视频理解（静态/agentic、1 FPS、token 公式、File API 20GB）— https://ai.google.dev/gemini-api/docs/video-understanding
- Gemini 交互式视频理解（markdown 版，含 88%/66%/7% 数字）— https://ai.google.dev/gemini-api/docs/interactions/video-understanding.md.txt
- Vertex AI 视频理解（45min/1h、10 视频、70 tok/帧、MEDIA_RESOLUTION_HIGH 280）— https://cloud.google.com/vertex-ai/generative-ai/docs/multimodal/video-understanding
- Google 官方 blog「Introducing Agentic Video in Gemini」— http://blog.google/innovation-and-ai/models-and-research/gemini-models/introducing-agentic-video-in-gemini
- AI Studio「Agentic video understanding in Gemini」（transcript-first / temporal zooming 机制）— https://aistudio.google.com/learn/agentic-video-understanding-with-gemini
- Gemini Robotics ER 2（Moment finding / Progress classification）— https://ai.google.dev/gemini-api/docs/robotics-video-progress
- Gemini 官方定价 — https://ai.google.dev/gemini-api/docs/pricing（本环境 fetch 超时，价格来自其 markdown 版搜索片段 + 第三方）
- 阿里百炼 图像与视频理解（时长/体积/fps/max_frames/FPS_MAX_FRAMES=2000/VIDEO_TOTAL_PIXELS/音频不支持）— https://help.aliyun.com/zh/model-studio/vision
- 阿里百炼 影视传媒视频理解计费（1h/450MB/1080P、2.8 元/小时、角色识别）— https://help.aliyun.com/zh/model-studio/film-and-television-media-video-understanding-billing
- 火山方舟 视频理解（Files API 512MB/2GB、fps 默认 1、抽帧 [16,1280]、80K token、64 tok/帧、时间戳格式）— https://docs.volcengine.com/docs/82379/1895586
- 火山 AI MediaKit 智能剪辑 — https://docs.volcengine.com/docs/6448/2549864
- 火山 长视频理解（视频点播）— https://docs.volcengine.com/docs/4/1478242
- OpenAI Responses API `input_file` 不支持视频 — https://github.com/openai/openai-node/issues/1778 ; https://platform.openai.com/docs/guides/file-inputs
- OpenAI 官方 cookbook「抽帧 + vision」方案 — https://github.com/openai/openai-cookbook/blob/main/examples/GPT_with_vision_for_video_understanding.ipynb
- AWS 官方博客「使用 Amazon Nova 实现自动化视频高光剪辑」（纯 VLM vs VLM+MME）— https://aws.amazon.com/cn/blogs/china/automated-video-highlight-clipping-using-amazon-nova-model/
- Qwen3-VL README / 技术报告（256K→1M、total_pixels 建议 <24576、max_frames=2048、Time-Timestamp Alignment、transformers>=4.57.0）— https://github.com/QwenLM/Qwen3-VL ; https://arxiv.org/abs/2511.21631
- Qwen3-VL Ollama 模型页（2b 1.9GB / 4b 3.3GB / 8b 6.1GB，标注 Text+Image）— https://ollama.com/library/qwen3-vl

**TimeLens / TimeLens2**
- 论文 TimeLens2 — https://arxiv.org/abs/2607.17423
- TimeLens (CVPR 2026) GitHub（FPS=2 / total_tokens=14336 / min_tokens=64 / maxframes-448）— https://github.com/TencentARC/TimeLens
- TimeLens2 GitHub — https://github.com/MCG-NJU/TimeLens2
- 模型卡 2B / 4B / 4B-SFT — https://huggingface.co/MCG-NJU/TimeLens2-2B ; /TimeLens2-4B ; /TimeLens2-4B-SFT
- GGUF 量化 — https://huggingface.co/mradermacher/TimeLens2-4B-GGUF

**评测 / 负面证据**
- LMGame-Bench (ICLR 2026) — https://proceedings.iclr.cc/paper_files/paper/2026/hash/83a4ea71b13bc86308a2bd0b5e07fb61-Abstract-Conference.html ；slide（spatial parsing 失败、low FPS problem）— https://iclr.cc/media/iclr-2026/Slides/10007223.pdf
- VideoGameBench（Gemini 2.5 Pro 实时通关 0.48%）— https://opencv.org/videogamebench
- Orak — https://arxiv.org/html/2506.03610v3
- Video-MME (CVPR 2025，含 esports 细类、Short/Medium/Long) — https://openaccess.thecvf.com/content/CVPR2025/papers/Fu_Video-MME_The_First-Ever_Comprehensive_Evaluation_Benchmark_of_Multi-modal_LLMs_in_CVPR_2025_paper.pdf
- INFACT (ACL 2026，视频 LLM 幻觉/稳定性) — https://aclanthology.org/2026.acl-long.2062
- VideoGAIA (arXiv 2608.14718，前沿模型 agentic 视频理解 <60%) — https://arxiv.org/html/2608.14718v1
- ScaleLong (ICLR 2026，269 个长视频、avg 86 min，23 个 MLLM) — https://proceedings.iclr.cc/paper_files/paper/2026/hash/fa1cfe4e956d85e016b1f8f49b189a0b-Abstract-Conference.html
- SportMV-Bench (arXiv 2607.11844，体育视频 MLLM 瓶颈在细粒度感知而非推理) — https://arxiv.org/abs/2607.11844
- VBenchComp / Apple（打乱帧序不变性、语言先验）— https://machinelearning.apple.com/research/breaking-down

**商业游戏剪辑工具（自述原理）**
- Eklipse — https://eklipse.gg/compare/best-ai-gaming-video-editor
- Choppity（纯音频分析）— https://www.choppity.com/tools/free-ai-clip-maker/ai-clip-maker-for-gaming
- Insights Capture — https://insights.gg/blog/insights-vs-eklipse
- WayinVideo — https://wayin.ai/blog/eklipse-alternative

**项目内取证**
- `skills\naraka-highlight-studio\references\complete-combat-roughcut.md` §3.2.1（640px 把战斗读成面板，5/5 扫描员中招）、§3.2.2（帧↔秒标定）、§3.2.3（代理视频）、§2.2.1 R2-1/2/3（整场战斗不挖洞不切断）
- `.scratch\efficiency\04-automation.md` §1（144 个一次性脚本 / 17 类重复）、§3（15 个候选，最高 ROI 三项）、§5.2 a–e（新假 PASS 源清单，含 (d) HUD 读数 OCR）
- `.scratch\efficiency\` 其余 01–10 号报告
- `AGENTS.md` §2（环境铁律）、§8.1（整场完整战斗）、§9（单次图片 50 张红线）
- `E:\OBS` 文件体积实测（4.23–5.99 GB）

---

## 11 明确「未找到」的项

1. **任何**针对 FPS / 第一人称竞技游戏**录像**（而非 agent 玩游戏）做事件检测或剪辑判读的公开评测
2. Claude 官方文档中「不支持视频输入」的明文（只有 2026 年初第三方文章的说法）
3. Kimi-K3 / GLM-5.3 / Qwen3.8-Max / Seed2.0-Pro 的视频帧数上限与时长上限
4. AWS Nova 的帧数 / 时长 / 文件体积上限
5. 火山 `doubao-seed-2-1-pro` 的 token 单价
6. TimeLens2-2B / 4B 的 HF 精确下载体积（本环境 huggingface.co fetch 超时；只确认 4B 有 1 个 GGUF 量化）
7. Qwen3-VL-2B/4B 在 RTX 4060 Ti 上的视频推理实测吞吐
8. llama.cpp 对 Qwen3-VL **视频**输入（mmproj）的可用性确认
9. Ollama 的 `qwen3-vl` 标签是否支持视频输入（页面只标 Text, Image）
10. 19 分钟游戏素材的端到端云端 API 延迟实测
11. 19 分钟全片事件清单的典型输出 token 数
