# 18 · 真实案例调研：别人怎么把「素材 → 成片」从 10 小时压到 1 小时以内

> **调研人**：18 号子调研员（案例向）
> **日期**：2026-10-05
> **问题**（用户原话）：「我现在一个视频甚至可能要剪 10 个小时才能给我一个答案，实在是太慢太慢太慢太慢了。」
> **对照基线（本次任务给定，不重新测）**：19 min 素材 / 13 min 成片 / 一条视频 10 h；纯等待 **46.5%**（29.07 h）、审片 17.2%、时间线合成 7.7%、返工 4.7%、机器重活仅 **3.1%**（1.91 h）。
> **同目录邻居报告**（不重复它们，只在必要处对照）：`01-video-llm.md`、`06-one-prompt-to-film.md`、`16-timeline-ir.md`、`19-skill-architecture.md`、`20-vlm-game-eval.md`。

---

## 0 一页结论

| # | 结论 | 强度 |
|---|---|---|
| 1 | **最快的一类不是「AI 剪得快」，是「根本不剪」**——游戏自己吐出事件时间戳，剪辑器只负责把事件前后各切一段。生产系统（Overwolf）把这件事压缩成**一个 JSON 里每个事件的三个数字**（`past` / `future` / `pending`）。 | 【文档】 |
| 2 | **「一句话出成片」这件事已经商品化了（OpusClip Pro 起有 `Prompt to clip`），但没人公开过延迟数字**——OpusClip 自己的定价页只卖「相对更快」，不卖分钟数。 | 【文档】+【未找到】 |
| 3 | **行业头部工具的延迟口碑是坏的**：302 条 Trustpilot 里 22% 一星，头号 complaint 是「视频卡住几小时、甚至永远处理不完」。 | 【文档】 |
| 4 | **「把这类工作压到几十分钟」在公开世界里的唯一可信数字形态是「43 个片段、约一小时以内」，且来自厂商自引的单条 App Store 评论**，不是基准、不是论文、不可核实。 | 【文档】 |
| 5 | **永劫无间不在任何事件 SDK 的支持名单里**（Overwolf 58 款游戏 / 15 款支持 auto-highlights，均无）；本机也**没有任何本地游戏事件日志**。所以「直接读事件」这条路对我们是封死的。 | 【文档】+【实测】 |
| 6 | **开源侧几乎是空的**：按 GitHub API 搜「游戏高光自动剪辑」，星标最高的两个相关仓库是 3 star 的学生项目。**未找到**任何可抄的开源生产级 pipeline。 | 【实测】 |

**给本项目的一句话**：我们不是「AI 剪得不够快」，我们是**缺一层「事件 → 毫秒时间码」的检测器**，导致所有裁决都退化成人看联系表。

---

## 1 方法与可信度声明（先说清楚这次搜到什么程度）

**这一节必须先读**，否则下面的「未找到」会被误读成「不存在」。

| 通道 | 状态 |
|---|---|
| 内置 `websearch` 工具 | **全程 401 失效**（首次调用成功后即断）。已重试 5 次、含 45 s 退避，全部失败。 |
| DuckDuckGo（html / lite）、Brave、SearXNG（searx.be / opnxng）、Marginalia、百度 | 传输错误 / JS 挑战 / CN 本地化污染，**不可用** |
| Bing（global，英文模式） | 可连通但**返回 "There are no results"**（多次不同关键词复现，判定为该出口被降级） |
| `api.github.com` | ✅ 可用（但相关性差，见 §5） |
| `api.openalex.org` | ✅ 可用（拿到论文元数据 + 摘要倒排索引） |
| `export.arxiv.org` API | **持续 429**（4 次），但 `arxiv.org/abs/<id>` 单页可用 ✅ |
| `hn.algolia.com` | ✅ 可用（**检索无相关结果**，见 §5） |
| 普通网页 `webfetch` | ✅ 可用（本报告大部分一手材料来自这里） |

**结论覆盖面**：一手厂商文档 + 官方 API 文档 + 论文元数据，覆盖良好；**独立第三方评测、YouTube 创作者实测视频、论坛帖几乎没覆盖到**。所以「未找到」= 本次通道下未找到，不是「世界上不存在」。

---

## 2 案例一（最强）：Overwolf auto-highlights —— 别人真的把这件事做成了产品

**链接**
- API 文档：https://overwolf.github.io/api/media/replays
- **auto-highlights 支持游戏 + 配置文件语义**：https://overwolf.github.io/api/media/replays/auto-highlights
- 支持游戏状态总表：https://overwolf.github.io/status
- API 索引：https://overwolf.github.io/api

### 2.1 它怎么做到「不剪」【文档】

三件套：

1. **常驻环形缓冲**：`buffer_length` 毫秒级循环缓冲，**上限 40 秒**（`ReplayVideoOptions.buffer_length`，"max 40 seconds"）。
2. **游戏事件推送**：`overwolf.games.events` —— 官方描述原文 "be notified when certain interesting events happens … This could be a death, a kill, an item purchase or anything else we're able to log from that game"。
3. **事件落地成文件**：调 `turnOn({highlights:{enable:true, requiredHighlights:["death","assist","victory"]}})` 之后，**什么都不用按**。命中事件时自动落盘，回调 `onHighlightsCaptured` 直接给：
   - `media_url` / `media_path`（成品文件路径）
   - `start_time`（毫秒 Unix 时间戳）、`replay_video_start_time`
   - `raw_events: [{type, time}]` —— **事件类型 + 事件自己的毫秒时间**

官方样例数据里，`start_time=1576572986453`、`replay_video_start_time=1576572986699` —— **事件与视频起点对齐到 246 ms 级**。【文档】

官方对 `past/future/pending` 三个字段的定义（`highlights.json` 原文示例）：

```json
"5426": { "events": {
    "death":  { "timing": { "past": 12000, "future": 3000,  "pending": 12000 } },
    "assist": { "timing": { "past": 12000, "future": 8000,  "pending": 12000 } } } }
```

- `past` = 事件前录多久
- `future` = 事件后录多久
- **`pending` = 等待下一个事件来「把几段合成一段」的窗口**

官方原文举例：**「如果有一个 Kill，紧接着有一个 Death，根据 Kill 的 pending 值，这两段会合并成一个 highlight 视频，而不是两段重叠的视频。」**【文档】

### 2.2 这为什么是本项目最该抄的一条【推断】

我们 AGENTS §8.1 的最高优先级判据是「一整场完整战斗、战斗窗口内不许挖洞、相邻两场必须合并、洞只许落在窗口外」。
Overwolf 用**一个 JSON 里每个事件的三个整数**表达了同一件事：

| 我们的概念 | Overwolf 的字段 |
|---|---|
| `engage_start`（接战前锚点） | `past`（12 s） |
| `outcome_time` + 收束（`source_end`） | `future`（3–8 s） |
| 「停顿 11 s < rejoin 12 就仍算同一场」（我们已量化为 `rejoin_window_seconds`） | `pending`（12 s） |
| `combat_episodes_vN.json`（我们手写的作战账本） | `raw_events:[{type,time}]`（机器吐的） |

**我们已经有 `rejoin_window_seconds` 这个标量**（`19.861` 时间线 notes 实测引用：「停顿 11 秒 < rejoin 12」）——所以「标量化」这条**我们已经做了一半**，不做不得领功。【实测】

### 2.3 支持范围与我们的位置【文档 + 实测】

- `overwolf.games.events` 覆盖 **58 款游戏**（`/status` 全部列出）。
- **支持 auto-highlights（自动落盘）的只有 15 款**：LoL、Dota 2、Fortnite、CS:GO、PUBG、PUBG Lite、R6、Apex、World of Tanks、RL、WoWs、HotS、Valorant、Overwatch、CoD Warzone。
- 大逃杀类别**在名单里**（PUBG / Apex / Warzone），事件类型实测返回 `["kill","knockout","death","knockedout","victoryRoyale"]` —— `knockout`（击倒）与 `victoryRoyale`（大吉大利）正是我们要的语义。
- **永劫无间不在 58 款里的任何一款。**【文档】

**本机实测**：不存在任何可读的游戏事件源。
```
C:\Users\Administrator\AppData\Local\naraka-toolkit-updater\installer.exe
C:\Users\Administrator\AppData\Roaming\Naraka Toolkit - ���ٹ�����\  ← 只有 Cache / Code Cache / DawnGraphiteCache
C:\ProgramData\Noraneko-1de4eec8-…\  ← 只有 updates.xml / parent.lock
```
`Naraka Toolkit` 是一个 Electron 应用（Chromium 缓存目录），**没有 stats / replay / 战斗事件数据库**。NetEase 目录下也没有。**没有 UE4 `Saved\Logs`（游戏本体未装在此机）。**【实测】

⇒ **「直接读引擎事件」这条路对永劫无间封死**（除非官方开放接口）。这与 Edithal 2025 论文「game engine integration requires expensive collaboration with game developers」的判断一致。【文档】

---

## 3 案例二：三条「拿到事件时间戳」的路线，成本被论文自己写清楚了

这是本次调研**信息密度最高**的一段，因为有作者亲口把三条路线的代价写下来了。

### 3.1 路线 A：引擎事件 —— 便宜，但需要厂商合作

见 §2.3。Edithal et al. 2025 原文：**"Traditional techniques for highlight detection such as game engine integration requires expensive collaboration with game developers."**【文档】

### 3.2 路线 B：OCR 屏幕上的击杀播报 —— 2015 年就有人做了【文档】

**Wei-Ta Chu, Yung-Chieh Chou（2015），《Event Detection and Highlight Detection of Broadcasted Game Videos》**
- DOI：https://doi.org/10.1145/2810397.2810398
- ACM DL（gold OA）：https://dl.acm.org/doi/pdf/10.1145/2810397.2810398
- 会议：*2nd Workshop on Computational Models of Social Interactions (HCMC)*，ACM，8 页
- 引用数 21（OpenAlex，截至 2026-08-26 更新）
- 会议论文作者单位：National Chung Cheng University（台湾）

摘要原文（从 OpenAlex 摘要倒排索引还原）：

> "Efficient access of game videos is urgently demanded due to the emergence of live streaming platforms and explosive numbers of gamers and viewers. In this work, we facilitate efficient access to game videos from two aspects: **event detection** and **highlight detection**. **By recognizing predefined text displayed on screen when some events occur, we associate events with time stamps for direct access.** We jointly consider visual features, events, and viewer's reaction, construct models to enable compact presentation of game videos. Experimental results show the effectiveness of our proposed methods."

一句话：**识别屏幕上事件发生时的固定文案 → 把事件绑定到时间戳 → 直接跳转。**

**这条路线的致命短板，作者自己写了**（Edithal 2025 转述）：**"OCR techniques which detect patches of specific images or texts require expensive per game engineering and may not generalize across game UI and different language."**【文档】

⇒ **对本项目的意义（推断）**：我们的 861 已经用手写数值签名做成了同一件事的中文版——`ann2 带红像素 ≥70000 且 plate_red ≥57000 且 bbox 高 ≈420px`（源：`123\19.861…\reports\tie1_verdict.md:35`）。**原理上就是路线 B**，而且比 OCR 更省（只数像素，不识字）。但它是**一次性的、写在单场时间线 notes 里的手工判据**，不是可复用检测器（详见 §6）。

### 3.3 路线 C：微调一个通用多模态模型 —— 跨游戏泛化，不用逐游戏写规则【文档】

**Vignesh Edithal, Le Zhang, Ilia Blank, Imran Junejo（2025-05-12），《Gameplay Highlights Generation》**
- arXiv：https://arxiv.org/abs/2505.07721
- PDF：https://arxiv.org/pdf/2505.07721
- 全文 HTML：https://arxiv.org/html/2505.07721v1
- 许可 CC-BY-4.0；作者机构 **AMD**（企业做的，不是学术玩具）

方法与数字（摘要原文）：

| 要点 | 原文 |
|---|---|
| 任务拆解 | "first **identifying intervals** in the video where interesting events occur and then **concatenate** them" |
| 模型 | finetuned **X-CLIP**（通用多模态视频理解模型）+ prompt engineering |
| 泛化性 | "generalizes across **multiple games in a genre without per game engineering**" |
| 准确率 | "detect interesting events in first person shooting games from **unseen gameplay footage with more than 90% accuracy**" |
| 小样本 | 训练时混入高资源游戏，**小数据集游戏明显更好** → 有 transfer learning |
| 部署 | **ONNX + 训练后量化**（"reduce model size and inference time"），**ONNX Runtime + DirectML 在 Windows 上推理** |

**这是「不写逐游戏规则」这条路唯一一个有 >90% 数字的公开结果。**（同目录 `20-vlm-game-eval.md` §6.1 已引用本文的 >90%，两处不冲突：一处是论文对「瞬时事件」判据的结论，一处是它对小样本迁移的结论。）

---

## 4 案例三（反面）：AI 剪辑服务的真实速度基准 —— 结论是「查不到，而且口碑很差」

### 4.1 OpusClip 官方**不公布任何延迟数字**【文档 + 未找到】

我把 https://opus.pro/pricing 整页抓下来了。`Processing speed` 这一栏，四个档位全文如下：

| 档位 | 官方原文 |
|---|---|
| Free | "Regular speed" |
| Starter | "Faster than Free and Trial" |
| Pro | "Faster than Starter" |
| Business | "Dedicated enterprise queue; Fastest processing with more powerful servers" |

⇒ **官方只卖「相对更快」，一个绝对分钟数都不给。**【文档】

**「OpusClip 处理 19 分钟素材要多久」= 未找到**（官方无数字，官方也不允许你按档位推算）。这是本次调研一个**有价值的否定结果**：不是「查起来麻烦」，是**这个数字在产品层面不存在**。

顺带抓到的 OpusClip 官方产品事实：
- AI clipping 的信号在定价页上明写五类：**by spoken words / by visual objects / by sound / by emotion / genre-specific curation model**【文档】——即**已经有「按游戏类别调过的模型」**，且 **`Reprompt clipping to finetune the results`**（对话式改结果）已是 Pro 档功能。
- **「一句话出片」已商品化**：Pro/Business 档的 AI copilot 明确列出 **"Prompt to clip"**（配合 Topics search / Reprompt）。【文档】
- 计费按**源视频分钟数**，不是输出片段数。19 分钟 = 19 credits。【文档】

### 4.2 唯一出现的「2–5 分钟」，来源是竞品评测，不是 OpusClip【文档 / 竞品口径，需打折】

https://www.ssemble.com/blog/opus-clip-review-2026（作者 Eric Lee，Ssemble CEO，2026-03-20）：

> "The entire process takes **2-5 minutes per video**. You typically get 5-15 clips from a single long-form video."

同一站另一篇（2026-03-20）给的是同一个数，并按 VOD 单价算成「**2-5 分钟 per VOD**」。

⚠️ **必须打折看**：Ssemble 是 OpusClip 的直接竞品，同一篇文里明确说「我们的剪辑质量和 OpusClip 相当、但价格是 1/4」。**一个竞品不会给你竞品测出更好的数字来打广告。** 另需注意 Ssemble 自己的产品页说的是「1 credit = 1 VOD **up to 20 min**」，所以「2–5 分钟」最多覆盖到 20 分钟量级——**我们的 19 分钟正好落在边界内**。【文档】

### 4.3 头部工具的延迟口碑是坏的【文档 / 用户报告，单向不可核实】

同一篇竞品评测对 302 条 Trustpilot 评论的分析（OpusClip 综合 4.0/5，**22% 一星**）：

> **"Processing failures and slowdowns — This is the #1 complaint in recent Trustpilot reviews"**
> - *"Videos hang for hours, and often never finish processing. What's worse is that their support team seems either unwilling or unable to help."* — Justin Bennet, 1★, February 2026
> - *"Been using Opus Clip for well over a year … but lately the system is really slow and so many failed projects."* — Kyle Hislop, 1★, March 2026

同页 5 星评论里出现的时间节省说法：*"game-changer for workflow"*、**"saves 10 hours per week"**（**用户评论，非测量；且该文语境是布道/播客剪辑，不是游戏对战**）。【文档】

### 4.4 Eklipse：唯一一个带具体数字的公开说法，但样本量 = 1【文档 / 单样本，不可核实】

https://eklipse.gg/features/automate-stream-clips（厂商官网自引评论，原文逐字）：

> *"This is a great app! … **after I did a stream it took about an hour or less to make 43 clips.** One of the first apps I've found that has actually worked."* — T, App Store review

**这是本次全部搜索里，唯一一个形如「N 小时 → 1 小时以内」的具体数字。** 但必须标注：① 一场**长度未知**的直播（Eklipse 主推 5 小时长直播）；② 43 个片段是 15–60 s 的竖版短视频，**不是一条 13 分钟的连续成片**；③ 厂商自引、无第三方复核。**不能拿它当我们的目标基线。**

Eklipse 页面里另几条与本项目相关的事实【文档】：
- **"The AI reads the gameplay, not just the audio"** —— 明确宣称读画面。
- **"Detection is tuned per category, because a Valorant round and a GTA heist do not peak on the same cues."** —— 即「按游戏类别调过」，并称覆盖 **3,000+ games**。
- **"Clips come back scored, so … A five-hour stream turns into **a shortlist worth posting**, not a folder you have to sift through yourself."** —— 交付物是**排序后的短名单**，不是一堆待筛文件。
- **"Detection and rendering happen in the cloud, so auto-clipping never steals frames from your game."**
- 流程是**下播后拉 VOD 再全量扫**，不是录制时切。

### 4.5 「一句话出成片」的公开 latency 数据【未找到】

| 问的 | 答|
|---|---|
| OpusClip `Prompt to clip` 多久出片？ | **未找到**（官方零数字，§4.1） |
| Eklipse / Vizard / Ssemble 的端到端 latency SLA？ | **未找到**（三家均只有相对档位或营销口径） |
| 任何公开 benchmark（给定输入时长 → 给定输出延迟）？ | **未找到**（§5 解释了为什么找不到） |

---

## 5 开源与社区侧：几乎是空的（诚实的否定结果）

**GitHub API 实测**（`api.github.com/search/repositories`，本次可用的唯一代码检索通道）：

| 仓库 | 星标 | 说明 |
|---|---|---|
| `mahdi-alkak-1/HighlightIQ` | **3** | TypeScript，"Automated gameplay highlight detection and clipping with review and YouTube publishing"，topics 含 `clip-generator/gaming/highlights` |
| `ClipFarmVB/ClipFarm` | **3** | **排球**高光生成器；YOLOv8-pose 动作检测 + 球轨迹跟踪；FastAPI + Celery + Next.js；2026-07 建，2026-10-05 仍在推 |
| `e-kemeny/automated-content-pipeline` | **0** | "detecting, clipping, processing, publishing gameplay highlights"，Python，2026-08 |
| `reisun/splat-highlight-pilot` | **0** | Splatoon 自动切片"编排器" |

**结论：未找到任何星标 ≥100 的「游戏录像自动剪辑」开源 pipeline。** 这个生态是**闭源的**（Overwolf / Eklipse / OpusClip 都不开源核心检测器）。ClipFarm 那个排球项目虽然只有 3 star，但它印证了**架构共识**：检测（专用小模型）→ 任务队列 → 服务化出片。【实测】

**Hacker News Algolia 实测**：查 `auto clip highlights twitch` 全文检索，**命中 1 条，且是完全不相关的帖子**。⇒ r/streaming、HN 这类社区**没有可引用的实战复盘**。（一个 Reddit 线索经首轮搜索摘要出现——r/streaming 有条讨论提到用「触发词自动检测 → 切周围 gameplay → 把触发词本身从成片里去掉 → 自动导出」的思路——但**我没能取回原帖正文，故不作为已核实案例**。）

---

## 6 本项目现状核对（我亲自 grep / 读的，不是转述）

这一节是「我们没做的 3 件事」的判定依据。全部【实测】。

### 6.1 没有任何检测器

```
grep -i "ocr|paddle|easyocr|tesseract|x-clip|xclip|clip_|classifier|onnx|open_clip"
  在 C:\Project\永劫无间\scripts\            → No matches found
  在 C:\Project\永劫无间\skills\naraka-highlight-studio\  → No matches found
```

`scripts\` 全部文件（无一与分析检测相关）：
```
audit_coverage_judgement.py     check_task_hygiene.ps1      make_contact_sheet.ps1
check_image_budget.ps1          check_task_numbering.ps1     read_episode_bounds.ps1
check_video_environment.ps1     cleanup_after_master.ps1     resolve_ffmpeg.ps1
collect_lessons.ps1             sanitize_stray_dirs.ps1      seg_render_master.sh
test_*.sh (×5)                  verify_master.sh
```
`skills\naraka-highlight-studio\scripts\` 全部文件：`analyze_bgm.py`、`build_batch_manifest.py`、`episode_geometry.py`、`export_edit_timeline.py`、`map_events_to_beats.py`、`qa_gate.py`、`validate_combat_timeline.py`、`validate_delivery.py` —— **全是校验/时间线工具，没有一个产出检测信号**。

⇒ **项目里没有任何一个脚本输出「事件 → 毫秒时间码」。**

### 6.2 已有的最强自动信号是「一次性手写 JSON」，不是脚本【实测】

`123\19.861永劫无间 2026-09-26 23-26-54\reports\tie1_verdict.md:35`：

> **真①签名：ann2 红像素 ≥ 70000、bbox 高 ≈ 420px、plate_red ≥ 57000。**
> 排除型签名：`solidrun` 数百（条状）或 `plate_red ≈ 红像素总数`（红压在亮底上 = 名牌血条）

同一份 notes 还记了这个坑（`:23`）：扫描带原设 `R_TOP = y330–520`，**整条切在横幅上方（真横幅在 y150–250）**，用它报「无播报」会得到**结构性伪阴性**。

产物落地在 `123\19.861…\shots\tie1\scan_d2_1560_1650.json`、`banner_d2_ann2.json` —— **JSON 在任务目录里，逻辑在 notes 里，没有脚本**。同一个签名在 `19.861` 的 v3–v9 七份 `combat_episodes_vN.json` 里被逐字复制。

⇒ **这已经是路线 B（§3.2）了，而且做得比 2015 那篇论文提到的 OCR 更省**（只数像素，不识字）。**它的问题不是效果，是它不是软件。**

### 6.3 分析脚本散落在任务目录，不在 `scripts\`【实测，同项目既有结论】

`.scratch\oneprompt\01-gap-analysis.md:67` 已记：`build_program.py` / `map_captions.py` / `transcribe.py` / `render_preview.py` / `freeze_kit.py` **全部躺在 `123\<id>\tools\`，不在 `scripts\`**。
`.scratch\oneprompt\06-script-consolidation.md:217-218`：**4 份 `transcribe.py` 里 3 份逐字节相同、864 改了 100 B**（"864 悄悄换了切段策略、无人知道原因"）；`detect_scenes.py`/`scene_rms.py`/`rms_only.py` **3 种形态**。

⇒ **同一个「换一种切段策略」的静默漂移，已经在两个不同脚本上各发生一次。** 这直接吃掉「时间线合成 7.7%」和「返工 4.7%」两块。

### 6.4 `hud_curve.py` 不存在【实测】

`.scratch\oneprompt\06-script-consolidation.md:248,271`：**"V2｜需要 OCR / 分类器 / 阈值才能给结论"**、**"`hud_curve.py` 需要还不存在的 OCR 能力，不是搬家"**。`.scratch\efficiency\04-automation.md:261` 同样把它排在最后一步「需要新建 OCR 能力」。

⚠️ **一处需要纠正的兄弟报告说法**：同目录 `20-vlm-game-eval.md` §5.3 标题写「本项目已在用 OCR / 像素」。**「像素」成立**（§6.2 的 `ann2`/`plate_red` 确在用），**「OCR」不成立**（全仓 grep 零命中，且 `hud_curve.py` 被明确标为「需要还不存在的 OCR 能力」）。结论层面不受影响，但**别把它当成 OCR 已经在跑**。

---

## 7 ★ 我们现在**完全没做**的 3 件事

判定标准：外部有一手来源、路线明确、成本可估、且**§6 核对确认我们零实现**。

---

### 【没做 1】产出「事件 → 毫秒时间码」的**检测层**，把预览视频从「裁决依据」降级为「复核手段」

**外部依据**（三选一，成本递增但都有公开数字/文档）：
- 引擎事件：Overwolf `overwolf.games.events` + `media.replays`【文档】——**永劫无间不在名单，且本机无事件日志【实测】，这条路封死**
- OCR / 屏幕文案识别：Chu & Chou 2015，https://doi.org/10.1145/2810397.2810398【文档】——作者警告「逐游戏工程昂贵、不跨 UI/语言」
- 微调通用多模态模型：**Edithal et al. 2025，https://arxiv.org/abs/2505.07721**【文档】——**X-CLIP 微调，未见过的 FPS 录像上 >90% 准确，跨同类别游戏泛化，无需逐游戏工程；ONNX + 量化 + DirectML 已在 Windows 上部署**

**我们现状**：§6.1 —— 全仓无 OCR / 无 VLM / 无分类器 / 无 ONNX；`scripts\` 里没有检测器。§6.2 —— 最接近的成果是写在单场 notes 里的一次性像素签名。

**为什么这是最贵的一项**：本项目 46.5% 纯等待 + 17.2% 审片的**上游就是它**。今天所有裁决都要先渲 720p 预览、再由人或 agent 读联系表，因为**没有任何机器产物能直接给出「这段是/不是战斗，从第几秒到第几秒」**。Overwolf 的对照是：事件一到，文件已经在磁盘上了。

**最小落地（推断）**：不做 X-CLIP。先把 §6.2 的 `ann2` 像素签名**收编成一个可回归的检测器**（输入 → 事件列表 JSON），回归集就用已有的 861/864 已知答案。这一步不需要任何模型，但会把「一次性 JSON」变成「软件」。

---

### 【没做 2】把「相邻两场要不要合并 / 战斗窗口多宽」从**逐次裁决**变成**每个事件的三个标量**

**外部依据**：Overwolf `highlights.json` 每个事件的 `past` / `future` / `pending`；官方原文对 `pending` 的定义就是**「kill 后 12 s 内来 death，两段合成一段而不是两段重叠」**【文档】
实现入口：https://overwolf.github.io/api/media/replays/auto-highlights（`highlights.json` 语义）
API 侧参数：https://overwolf.github.io/api/media/replays（`buffer_length` ≤ 40 s；`capture(pastDuration, futureDuration, …)`，`pastDuration` 上限 **600000 ms**）

**我们现状（必须诚实）**：**`rejoin_window_seconds` 这个标量我们已经有了**（`19.861` notes 实测：「停顿 11 秒 < rejoin 12 / 停顿 14 秒但无收束三步」）——所以「标量化」我们完成了一半。

**真正没做的是另一半【实测】**：
- `pending` 这种**「以某个事件为锚、向两侧吸收、且带合并语义」的窗口模型**我们没有；我们的 `engage_start`/`outcome_time` 是**逐场手写的终值**，不是从事件推导出来的。
- 864 被连续否决六版、`AGENTS §8.1` 被迫升级成「最高优先级判据」，根因就是**每场都要人重新裁决一次边界与合并**。

**可借的具体形态**：外部的做法不是「更聪明的判断」，而是**更笨的固定窗口 + 一个 pending 合并窗**，写在配置文件里、运行时无人在场判定。我们已经有 `rejoin_window_seconds=12` 这个数，缺的是把它变成**以事件为锚的窗口生成器**，让 `combat_episodes_vN.json` 从「人写的账本」变成「检测器的输出 + 人的例外清单」。

---

### 【没做 3】把审片从「全片看」改成「**排序后的短名单 + 例外裁决**」，并接受「一句话改边界」而不是「从零剪」

**外部依据**：
- Eklipse 官方交付形态：**"Clips come back scored … A five-hour stream turns into **a shortlist worth posting**, not a folder you have to sift through yourself."**（https://eklipse.gg/features/automate-stream-clips）【文档】
- OpusClip：**Virality Score**（1–100 预测互动潜力）+ **"Reprompt clipping to finetune the results"**（对话式改结果）+ Pro 档 **"Prompt to clip"**（https://opus.pro/pricing）【文档】
- OpusClip 的信号谱系本身就是可抄的判据清单：**by spoken words / by visual objects / by sound / by emotion / genre-specific curation model**【文档】
- 竞品评测记录的用户侧说法：*"saves 10 hours per week"*（用户评论，非测量）【文档】

**我们现状【实测】**：审片 17.2% + 返工 4.7%。现有流程是「渲全片预览 → 派多路对抗审 → 出 v(N+1) → 再审」，`19.861` 一场就留下 `tie1_verdict.md`、七版 `combat_episodes_vN.json`、大量 `reports\*`。**产物是「一堆报告」，不是「一个排序后的短名单 + 几个待裁决的争点」。**

**为什么这条能省时间（推断）**：审片成本的形状是 `O(需要人判断的点数)`，不是 `O(片长)`。今天我们让每场战斗都进了一次人眼；改成「机器先排序、只把 top-N 场和机器没把握的边界送人」之后，人看的量从「整场 19 分钟 × 若干路」降到「几个争点 × 若干路」。这也正好对上 `AGENTS §8.2` 新增的**删除段审计员**——它需要的正是「一个可排序的删除段清单」。

**顺便**：OpusClip 已经把「一句话出片」做成了 Pro 档商品（`Prompt to clip` + `Reprompt`）。**这条对我们的价值不是「用 OpusClip 出片」，而是「它证明了审片的交互形态应该是一次对话修正，而不是一次重剪」。** 【文档】

---

## 8 明确标注「未找到」的项（不编）

1. **OpusClip / Eklipse / Vizard / Ssemble 任何一个的端到端处理延迟 SLA 或公开 benchmark**：**未找到**。OpusClip 官方只给相对档位（§4.1）。
2. **「一句话出成片」类产品的公开 latency 数字**：**未找到**。
3. **任何针对「第三人称武侠 BR / 永劫无间」的高光检测评测或数据集**：**未找到**（与同目录 `20-vlm-game-eval.md` §7.1 一致）。所有公开 FPS 评测都是 CS2/Valorant/OW2/Apex/BF/PUBG/ARPG。
4. **星标 ≥100 的开源「游戏录像自动剪辑」pipeline**：**未找到**（§5）。
5. **r/streaming / HN 上带具体时间数字的实战复盘**：**未找到**（§5）。
6. **「检测 FPS 游戏『瞬时事件』判据」的公开实时吞吐数字（推理 fps / 端到端秒数）**：**未找到**。Edithal 2025 给了 >90% 准确率和「用 ONNX 量化降低推理时间」的方向，但**没给具体的每秒处理帧数**。
7. **YouTube 创作者实测视频**（如「我用 AI 把 5 小时直播剪成 10 分钟」）：**未取回**。首轮搜索摘要里出现过 Eklipse 的官方频道与第三方教程链接，但**本轮无搜索通道可复核，未取正文，故不列为已核实案例**。

---

## 9 全部链接（本次实际打开过的）

**一手厂商/官方 API 文档**
- Overwolf replays API：https://overwolf.github.io/api/media/replays
- Overwolf auto-highlights（`highlights.json` 的 past/future/pending）：https://overwolf.github.io/api/media/replays/auto-highlights
- Overwolf 支持游戏状态总表（58 款，无永劫无间）：https://overwolf.github.io/status
- Overwolf API 索引：https://overwolf.github.io/api
- OpusClip 定价（`Processing speed` 只有相对档位；`Prompt to clip`；五类 clipping 信号）：https://opus.pro/pricing
- Eklipse 自动切片（shortlist 交付形态、3000+ games、per-category tuning、单条 App Store 评论「about an hour or less to make 43 clips」）：https://eklipse.gg/features/automate-stream-clips

**竞品口径（打折看）**
- Ssemble《How to Clip Twitch Streams with AI in 2026》（2–5 min per VOD；per-video ≤20 min）：https://www.ssemble.com/blog/how-to-clip-twitch-streams-2026
- Ssemble《Opus Clip Review 2026》（2–5 min；302 条 Trustpilot 分析；「hangs for hours」一星评论）：https://www.ssemble.com/blog/opus-clip-review-2026

**论文**
- Edithal, Zhang, Blank, Junejo (2025)《Gameplay Highlights Generation》X-CLIP >90%、跨游戏泛化、ONNX+量化+DirectML：https://arxiv.org/abs/2505.07721
- Chu & Chou (2015)《Event Detection and Highlight Detection of Broadcasted Game Videos》OCR 屏幕文案 → 事件时间戳：https://doi.org/10.1145/2810397.2810398

**本项目内部一手证据**
- `123\19.861永劫无间 2026-09-26 23-26-54\reports\tie1_verdict.md:23,35`（ann2/plate_red 数值签名 + 扫描带切在上方的伪阴性）
- `123\19.861…\timeline\combat_episodes_v3..v9.json`（同一段 notes 被逐字复制七遍）
- `.scratch\oneprompt\01-gap-analysis.md:67`、`06-script-consolidation.md:217-218,248,271`
- `.scratch\efficiency\04-automation.md:261`、`10-roi-ranking.md:89`
- `AGENTS.md` §8.1（整场完整战斗三条硬规则）

---

## 10 收尾：一句话答复原始问题

**「有没有人把这类工作压到几十分钟？」**
—— **有一种人做到了，而且他们的做法不是「剪得更快」，是「在录的时候就切完了」**（Overwolf：环形缓冲 ≤40 s + 游戏事件 + 每个事件 `past/future/pending` 三个数字，事件一到文件已落盘，毫秒时间戳随文件一起给）。**这个前提对永劫无间不成立**（不在 58 款支持名单，本机无事件日志），所以我们必须走**路线 B/C 的替代品**：把已有的像素签名收编成检测器（Chu&Chou 2015 的中文低配版），或微调一个跨游戏模型（Edithal 2025，>90%，已有人做完）。
——**至于「AI 剪辑服务几十分钟出片」**：OpusClip 官方不公布延迟，其头部用户 complaint 是「卡几小时甚至永远不完」；唯一形如「1 小时以内」的数字是一条厂商自引的单条 App Store 评论，且是 43 个 15–60 s 竖版短视频，不是一条连续成片。**把它当参照会骗自己。**