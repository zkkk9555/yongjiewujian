# 06 · 市面上「一句话 → 成片」的产品/服务/框架，以及可借鉴的架构

> **视角**：外部市场调研。**本轮零图片**（AGENTS §9 预算消耗 0 张），未改任何项目文件（唯一写入是本报告）。
> **取证日**：2026-10-05 · 全部结论带链接。
> **用户原话**：「我就是想给出一套提示词，**它就能自动按照我的流程，给我输出素材的粗剪的预览片**。中间的过程我都不管，我就是要它效率最高、速度最快就可以了。」

**证据等级约定**（每条结论后面标）：`实测`= 我本机跑过 · `文档`= 官方文档/帮助页原文 · `推断`= 我从多处事实推出、未被直接证伪 · `未找到`= 查了但没查到，不编。

---

## 0. 一屏结论

```
现成方案能直接用吗        不能。一家都没有，而且方向是相反的。
                        商业品 100% 做「长视频 → 10 条竖屏爆款切片」，
                        本项目要的是「一整场战斗 → 连续 720p 审片预览」。
                        三条硬冲突：① 竖屏 9:16 vs 4K60 ② 烧录字幕 vs AGENTS §5 全外挂
                        ③ 挖洞取高光 vs AGENTS §8.1 战斗窗内不许挖洞。

唯一明确支持本游戏的产品   Eklipse（eklipse.gg）——帮助页白纸黑字列了 Naraka（永劫无间）。
                        但它输出竖屏爆款 + 烧录字幕，且未找到公开 API。

最值得借鉴的一个架构      vercel-labs/json-render 的「catalog → prompt 契约」。
                        模型只能输出组件注册表里有的东西，规格说明由注册表自动生成。
                        这正是 08 号终审「单源纪律」要的东西，市面已经做对了。

该替掉子 Agent 吗        不该。通用框架缺的那三项（断点续跑/超时换路/attempt 计数）
                        恰好就是本项目 taskstate.json + watchdog 要干的事，
                        但没有任何通用框架知道 images_seen 或 no_holes_in_battle 是啥。
                        该借机制（Temporal 的 Activity timeout+retry 语义），不借框架。

该换渲染引擎吗            不该。JSON→成片这一层已有成熟开源件（editly / cutagent /
                        ffmpeg-editlist / video-mix-with-codex），但**换引擎会丢掉
                        已验证的 4K60 NVENC 链路**（AGENTS §2「坏掉方向是安全」）。
                        正确动作是照抄它们的 EDL schema 形状，不换渲染器。
```

---

## 1. 商业产品：游戏录屏（非口播）适配度

### 1.1 结论先行

| 产品 | 对游戏画面的适配 | 证据等级 | 与本项目冲突点 |
|---|---|---|---|
| **Eklipse** | **唯一明确支持的**，且列了 Naraka | `文档` | 输出竖屏 + 烧录字幕；无公开 API |
| OpusClip | 声称支持（ClipAnything），但主打 viral shorts | `文档` | 同上 + XML 导出去接 NLE（等于承认自己不是终点） |
| Vidyo.ai / Quso.ai | **明确无游戏事件模型** | `文档`（第三方对比页） | — |
| Vizard | **明确要求有语音** | `文档`（官方帮助页） | 硬性排除 |
| Descript | 转录驱动，对视觉驱动剪辑不自然 | `推断`（第三方评测） | 同类 |
| Kapwing | prompt-to-edit，长文件友好（6GB/3h），有 MCP/API | `文档` | 云端编辑器，无游戏事件检测 |
| Premiere Pro 26.x | NLE + Smart Virals（= 内置 OpusClip） | `文档` | 创意判断仍归人；产物是 NLE 时间线不是预览片 |
| Eightify | 未取证（本轮未查） | `未找到` | — |

### 1.2 Eklipse —— 唯一点名 Naraka 的产品（最重要的一条发现）

`文档` [eklipse.gg/use-case/eklipse-game-highlights](https://eklipse.gg/use-case/eklipse-game-highlights) 原文：

> "Automatically detecting your epic moments, wins, headshots, and more, from **CS2, Dota 2, Apex, Naraka, and PUBG**."

**检测引擎架构（`文档`，[eklipse.gg/help/how-gameplay-intelligence-picks-moments](https://eklipse.gg/help/how-gameplay-intelligence-picks-moments)）** —— 这一段是本轮最有价值的架构情报，它把「什么算一个高光」拆成了四层：

> 1. **Advanced Moment Detection** — 用 game events、audio、action density、continuity 打分定位候选
> 2. **Scene-aware context** — 读屏上是什么，决定每个 clip 从哪开始、到哪结束
> 3. **Per-genre tuning** — 按体裁路由到不同检测逻辑（FPS / BR / MOBA / tactical / strategy）

其中一条打分规则值得抄：

> "A peak in your voice while **game audio is loud and action density is high** scores higher than the same voice peak during a quiet menu. This is what reduces false positives on reaction-driven streams."

> **推断** —— 这就是本项目 `whole_battle` 门禁想解决的东西的**正向版本**。
> `AGENTS §8.1` 是「战斗窗内不许挖洞」的**禁止式**表达；Eklipse 是「战斗窗内不许切断、且要靠音频密度确认战斗真的在继续」的**正向打分**。
> 本项目现在只有禁止式判据，缺一个「这段真的是战斗而不是舔包」的正面置信度。

**它的降级策略（`文档`）**：

> "Unsupported titles — if a game is not in the supported games list, the engine falls back to general action-detection logic. **Clip quality is lower than on supported games.**"

**对不上的地方**：
- 输出是 **9:16 竖屏 + AI 烧录字幕 + 直接发 TikTok/Shorts/Reels** → 与 `AGENTS §5`（全外挂、禁烧录）和 `§6`（4K60）**正面冲突**。
- 形态是**Windows 桌面应用 + 云端 VOD 扫描**（"available exclusively on Windows"）。
- **公开 API：未找到。** 文档里只有产品页和帮助页，没有开发者/API 页面。这条不要当可用依赖。

### 1.3 商业品的共同结构性错位

**所有主流工具的产品定义就是「repurpose」，即「挖洞取高光」。** 这与 `AGENTS §8.1` 是**目标层面的对立**，不是参数能调的：

| 商业品的默认目标 | 本项目 `§8.1` 的目标 |
|---|---|
| 每条 clip 独立成立、开头 3 秒有 hook | 一整场战斗连续、间隙 6 秒也要留 |
| 最大化 Virality Score / engagement | 零漏战（`no_holes_in_battle` FAIL） |
| 竖屏 9:16、脸部追踪重构图 | 4K60 横屏原构图 |
| 烧录动态字幕 | 外挂 SRT，零烧录像素字 |

`推断` —— 即使某个商业品愿意接 API，它的**打分函数本身就是朝「挖得更狠」优化的**。本项目要的「宁可多留 48 秒也不挖洞」在一个以 engagement 为目标的打分函数里表达不出来。这不是工程量问题，是目标函数方向问题。

### 1.4 明确说「需要语音」的硬证据

`文档` [Vizard 帮助页（2026-04-23 更新）](https://help.vizard.ai/en/articles/8767566-how-many-clips-can-ai-generate) 原文：

> "Our AI analyzes the **audio** in your video **for speech**. To get the best results, make sure your video contains **spoken dialogue**."
> "**The AI will not generate clips if the video lacks sufficient content.**"

这是本轮拿到的**最硬的一条排除性证据**：至少一家主流工具在官方文档里写明它的检测建立在语音上。

`文档` Vidyo.ai 的定位同样如此 —— [Eklipse 的对比页](https://eklipse.gg/compare/eklipse-vs-vidyo)（竞品写的，立场需打折，但引用的产品事实可查）：

> "Vidyo.ai / Quso.ai ... transcribes long-form video, scores segments by virality ... **Tradeoff: No game-event detection model, so silent gameplay highlights depend on commentary or manual selection.**"

> ⚠ 这条是**竞品撰写的对比页**，我标 `文档` 是因为它描述的是对方产品的事实，标 `推断` 是因为出处有利益立场。交叉验证：[vidyo.ai/blog](https://vidyo.ai/blog) 自述也是 "content repurposing" 定位，与之相符。

`推断` —— 结合 Vizard 的语音依赖 + Vidyo 的对话依赖 + OpusClip 官网把 ClipAnything 定位为「other AI clipping tool only works with video podcasts」的差异化，**「口播优先」是这一整类的默认架构**。Eklipse 是显式分岔出去的那一个。

### 1.5 意外发现：OpusClip 已经把「给 agent 用」做成了产品

这一条与本项目的 harness 直接相关。

`文档` [github.com/opus-pro](https://github.com/opus-pro) 组织下有 5 个仓库（2026 全年活跃）：

| 仓库 | 干什么 | 对本项目的意义 |
|---|---|---|
| `opus-skills` | 官方 SKILL.md + CLI，给 Claude Code / Codex / OpenClaw / Claude.ai 用 | **形态参考**：一个 17 星的 skill 仓库就能被 5 种 host 装 |
| `opusclip-mcp` | 托管远程 MCP server，OAuth，零本地构建 | 「把重活放云端、agent 只做编排」的模式 |
| `opus-video-studio` | 43 个开源视频模板 + motion 组件 + **local Remotion preview** | **形态印证**：商用方自己也走 Remotion 预览 |
| `ai-producer-plugin` | 剪辑口播视频 | 只做口播 |
| AgentOpus MCP | prompt → 视频生成 | 方向相反（生成不是剪辑） |

`文档` [opus-skills README](https://github.com/opus-pro/opus-skills) 有一条对本项目**直接适用**的纪律：

> "**Do not paste API keys into chat with the agent.** Chat content can be retained in transcripts, logs, and model context. Set the key in the shell environment instead."

`文档` 提交历史里有两条演进记录值得抄：
- `feat(opusclip): preview-first agent surface + explicit clip export v3.5.0`（2026-07-16）→ **preview-first 是先做的，explicit export 是后加的**
- `docs(opusclip): add agent-instruction guardrails to SKILL.md`（2026-05-15）→ 他们也在 SKILL.md 里补护栏

> `推断` —— 商业方做到 16M 用户、迭代了大半年，最后仍然要给 agent 补「护栏」并把「先给 preview」重构成第一面。这与 08 号终审「用户第一行是机器写的结论，mp4 不是」是同一个结论。**这是外部佐证，不是本项目原创洞察。**

---

## 2. 开源 / 自托管

### 2.1 最值得借鉴的一个：`vercel-labs/json-render`（本轮头号发现）

`文档` [github.com/vercel-labs/json-render](https://github.com/vercel-labs/json-render) · 演示站 [remotion-demo.json-render.dev](https://remotion-demo.json-render.dev/)（标语："**AI → json-render → Video**"）

它的架构恰好就是用户要的那件事，**四层**：

```
① catalog     defineCatalog({...})        ← 组件注册表，唯一真源
② prompt      videoCatalog.prompt()       ← 从注册表【自动生成】给模型的规格说明
③ spec        TimelineSpec (zod 约束)     ← 模型只能输出注册表里有的组件
④ render      Remotion <Renderer/>       ← 渲染
```

`文档` README 原文（catalog 自动生成 prompt）：

> "The systemPrompt = `videoCatalog.prompt()` — Returns detailed prompt with: Component descriptions and props / Transition types / Effect definitions / **Timeline spec format requirements**"

`文档` spec 形状（这一段可以直接当本项目时间线的格式参考）：

```json
{ "composition": { "id", "fps", "width", "height", "durationInFrames" },
  "tracks":  [ { "id", "name", "type": "video|overlay|audio", "enabled" } ],
  "clips":   [ { "id", "trackId", "component", "volume?" } ] }
```

### 为什么这是本轮最值得借鉴的一个

| 本项目已有的问题（08 号终审） | json-render 的答案 |
|---|---|
| 04 号和 07 号各有一份字段清单，**且已经不一致** | 字段清单只存在于 catalog 一处 |
| 12 字段清单 vs 11 列表头 vs 「26 个」标题里的 27 行脚注 | catalog 是唯一真源，其他全从它生成 |
| 「verify 判投影列名 ≠ schema 列名 → exit 2」这条规则要靠人记得写 | 结构上不可能不一致，因为是生成的 |

> `文档` Remotion 侧还有一条匹配的机制（[remotion.dev/docs/timeline/render](https://www.remotion.dev/docs/timeline/render)）：
> "the timeline state is being passed to the `<Player>` component. Whenever you are rendering… **make sure to specify the `inputProps` option and pass in the same payload that you passed to the `<Player>` component.** Note that this payload must be JSON-serializable."
>
> → **预览与成片必须共用同一个 payload**。这正是 `AGENTS §1`「最终成片从原始素材重新渲染」的对偶命题：本项目是「预览和成片必须共用同一份时间线 JSON」。08 号没有点名这一条，**建议补上**。

### 2.2 `revideo` —— 活着，但重心已商业化

`文档` [re.video](https://re.video/) 首页自述：

> "The next chapter of Revideo. The open-source framework for programmatic video creation lives on as the engine behind **Midrender**. … **The team behind Revideo now primarily works on Midrender.** Revideo's animation engine continues to be developed as part of Midrender, though **recent changes have not yet been upstreamed to the open-source repository.**"

`文档` 技术定位（[docs.re.video](https://docs.re.video/)，"Last updated on July 9, 2026"）：

> "open-source framework for programmatic video editing… lets you create video templates in Typescript and provides an API to render these video templates with dynamic inputs… **forked from Motion Canvas**"

`文档` 两条值得抄的性能设计（[redotvideo/revideo README](https://github.com/redotvideo/revideo)）：

> - "**Headless Rendering**… making it possible to deploy a rendering API to services like Google Cloud Run"
> - "**Faster Rendering**… We have sped up rendering speeds by enabling **parallelized rendering** and **replacing the `seek()` operation for HTML video with our ffmpeg-based video frame extractor**"

> **`推断` —— 第二条是本项目帧轴 bug 的同一类根因。** `08-final-verdict.md` 前置 3 判定帧轴误差 `+29 帧（+0.483 s）` 全部来自 `fps` 滤镜、`-ss` 本身零误差。Revideo 的做法是**彻底不用 seek 语义、换成按帧精确抽取**。这从第三方实现侧印证了 08 号「帧轴基准必须整个换掉」的方向，而且给出了换过去之后的样子。
>
> 但注意：Revideo 重心已转向商业产品 Midrender，上游同步会滞后。**不建议引入**，只抄设计。

### 2.3 `manim` —— 未取证，但按定位不适用

本轮未单独查 manim。`推断` —— manim 是**数学/讲解动画**的场景描述引擎（写 Python 描述动画帧），它的抽象层级是「一个 scene」，不是「一条可 trim 可 concat 的源视频时间线」。本项目的核心动作是**从 4K60 原素材按源时间码 trim + concat + 保留音轨**，manim 不解决这个。

> ⚠ 标 `未取证`：如果后续要下结论，需实查 manim 是否有 clip/片段级复用 API。**本报告不替它下结论。**

### 2.4 「JSON 时间线 → 成片」的现成开源渲染器（不只是 ffmpeg shell 拼接）

这一栏是**实打实能抄格式**的地方。四个，按贴近本项目的程度排序：

#### ① `Kiendt91/video-mix-with-codex`（2026-05，23★）—— 形态最接近本项目

`文档` [github.com/Kiendt91/video-mix-with-codex](https://github.com/Kiendt91/video-mix-with-codex)。README 原话：

> "**The AI layer drafts, repairs, or reviews edit decisions; FFmpeg, HyperFrames rendering, and QA remain local and deterministic.**"

它的 EDL 形状：

```json
{ "$schema": "./schemas/edl.schema.json",
  "shots": [ { "id": "shot-03",
               "source": "D:/media/source.mp4",
               "sourceStart": 42.2,
               "timelineStart": 5.35,
               "duration": 1.4,
               "reframe": { ... } } ] }
```

它还有三件本项目**恰好缺**的东西：

| 它的做法 | 本项目现状（08 号实测） |
|---|---|
| `Validate-Edl.ps1 -Edl edl.json` 独立校验脚本 | 校验散在 `qa_gate.py` 的 17 扇门里 |
| `qa:aesthetic -- -Edl edl.json` **独立 QA 命令** | 无单一入口 |
| `review/index.html` 静态审片页，含 **shot reasons / source timing / transition notes / QA status / contact sheets** | 预览是 mp4，理由散在 JSON 里 |

> `推断` —— 「AI 只做决策与评审，渲染和 QA 保持本地确定性」这条分工，与本项目 `AGENTS §4` 的固定工作流（自动标签只是筛选信号，不能单独证明）**是同一条纪律**。市面上的独立实现也这么切。

#### ② `cutagent`（PyPI 0.5.0）—— 唯一明写「for AI agents」的 ffmpeg 封装

`文档` [pypi.org/project/cutagent](https://pypi.org/project/cutagent)：

> "**FFmpeg for AI agents** — every command returns structured JSON with recovery hints. CutAgent is designed from the ground up for AI agents and programmatic video editing."
> "**Agent-First Payload Workflow**… run `cutagent capabilities` to get the full machine-readable schema of all operations, a quality checklist, a phased workflow, and recipe examples"

它的 EDL 用 `$N` 引用（比 shot 数组更灵活，支持复用）：

```json
{ "version": "1.0", "inputs": ["interview.mp4"],
  "operations": [
    { "op": "trim", "source": "interview.mp4", "start": "00:02:15", "end": "00:05:40" },
    { "op": "concat", "segments": ["$0", "$1"] } ],
  "output": { "path": "highlight.mp4", "codec": "copy" } }
```

> **`推断` —— 这个 `$N` 引用模型对本项目有一个具体用处：** `AGENTS §8.1` 要求「洞只许落在窗口外」，而 08 号实测的 `no_zero_gap_pseudo_cuts` 判据本质上是「不得用 0 秒 gap 伪造成场边界」。用「trim 片段 + concat 引用」两级表达而不是「一段带 internal holes 的区间」，能让「洞」在数据结构上**不可表达** —— 结构上不存在的字段不会在 `deleted_intervals` 里被漏登记。
>
> ⚠ 未实跑，只读 README。`AGENTS §2` 要求预检为准，引入前需实测。

#### ③ `mifi/editly` —— 最成熟的 declarative NLE

`文档` [npmjs.com/package/editly](https://www.npmjs.com/package/editly)：

> "a tool and framework for **declarative NLE** (non-linear video editing) using Node.js and ffmpeg"
> "**much faster and doesn't require much storage because it uses streaming editing**"
> 28 个版本 · "Beta" · 19 deps · README 里点名 Remotion 为替代方案

`推断` —— 「streaming editing 避免重编码和大量磁盘」和本项目 `AGENTS §2`「渲染器路径解析/中间件」关心的是同一件事。但**换 Node 栈 + 重编码链路的风险 >> 收益**，不建议引入；可抄的是它的 edit spec 字段命名（`outPath/width/height/fps/clips[].duration/clips[].transition/layer`）。

#### ④ `coderefinery/ffmpeg-editlist` —— 唯一处理**外挂字幕时间轴**的

`文档` [PyPI](https://pypi.org/project/ffmpeg-editlist) / [GitHub](https://github.com/coderefinery/ffmpeg-editlist)：

> "**Subtitles: The option `--srt` will make ffmpeg-editlist reprocess subtitles just like video segments (cut to the segments and adjust timestamps).**"
> "Give Table of Contents times relative to the source video, **output mapped to times in the output video automatically**."
> 自评："This is currently an **alpha-level utility**"

> `文档` —— 这条**正面回应 `AGENTS §5`**：「字幕时间轴跟随粗剪后的节目时间线」这件事有现成实现。本项目的 `map_captions.py`（08 号实测：4 份副本在 4 个任务目录里，19596 B 那份最胖）在做的事就是它。**但注意自评 alpha，且本项目已有验证过的实现 —— 判为「可读源码借鉴，不引入」。**

#### 未找到

- **`Shotstack`** 等托管 JSON 时间线服务：本轮只在第三方博客里看到一句提及，**未查其官方文档**，不列结论。
- **面向游戏录屏的 JSON 时间线渲染器**：**未找到。** 搜到的游戏方向开源项目（`crispy`、`VideoHighlighter`、`AutomaticHighlights`、`ai-game-video-generator`、`rfypych/video-highlight-detection`）全部是「用 ML 找高光」，没有一个做「按外部给定的 JSON 时间线精确渲染」。

### 2.5 MoviePy 的现状：已被甩开，别用在主链路上

`文档` 现状（PyPI JSON API 实时取）：

- 最新版 **2.2.1**，**2026-09-19** 发布（3 天前，仍在维护）
- `Development Status :: 5 - Production/Stable`，Python 3.10+
- v2 由 **@osaajani 主导开发**（v1 时期没有的头部维护者）
- FreeBSD ports 跟进到 `2.2.1_4`（2026-09-19）
- CHANGELOG 有 "Strongly improve performances to make them more consistent with those of v1"

`文档` 但它自己 README 写了两句要害：

> "This makes MoviePy very flexible and approachable, **albeit slower than using ffmpeg directly due to heavier data import/export operations**."
> "**Maintainers wanted! this library has only been kept afloat by the involvement of its maintainers, and there are times where none of us have enough bandwidth.**"

`文档` 性能根因（README "How MoviePy works"）：

> "MoviePy **imports media (video frames, images, sounds) and converts them into Python objects (numpy arrays) so that every pixel becomes accessible**"

**结论（`推断`，但依据是它自己的 README，不是我的印象）**：

1. **项目是活的**，不是弃坑。v2 有实质投入（性能修复、NumPy 2.x、ffmpeg writer 的 `pixel_format` 修复）。
2. **但它的架构与本项目主链路互斥。** 它把每一帧变成 numpy 数组。本项目要做的是 **4K60、3840×2160、NVENC 硬件编码**。1080p 级 MoviePy 都慢，4K60 走 numpy 往返基本等于放弃 NVENC。
3. **已被 `editly` / `cutagent` / `ffmpeg-editlist` / 直接 ffmpeg 在这个场景甩开** —— 不是「性能更好」意义上的甩开，是**它们不做像素往返**所以能走硬件编码，MoviePy 做不了。
4. **⚠ 与 `AGENTS §2` 铁律直接相关**：项目 venv 里**没有** MoviePy（预检只列 faster-whisper / PySceneDetect / Auto-Editor）。**不要为了「统一 Python 栈」去装它** —— 那会引入一个既慢又不能硬件编码的依赖，且违反「项目自带 > 系统正常安装 > 其他」的优先级。

### 2.6 顺带：开源游戏高光项目里有一条参数和本项目判据同名

`文档` [Flowtter/crispy](https://github.com/Flowtter/crispy)（MIT，156★）README 的技术栈参数：

> "`second-between-kills`: **Maximum time between kills to be considered part of the same highlight. If the time between two highlights is less than this value, they will be merged.**"

`推断` —— 这就是 `AGENTS §8.1` 第二条硬规则（「相邻两场若战斗流程延续必须合并，**间隙哪怕 6 秒也要包含**」）的**参数化形态**，而且是一个 156★ MIT 项目里已经在用的参数。

> **建议**：把本项目 `§8.1` 的「间隙 6 秒」从散文里的一个数字，正式化成一个**有名字、有单位、有默认值的参数**（`merge_gap_sec`），并在 `qa_gate.py` 里读它。理由是 08 号已识别的通病 —— 四份文件各有一份字段清单且已经不一致；同一个数字散在散文里迟早长出第二个值。
>
> ⚠ 只读了 README，未跑代码。crispy 是 2021 年的项目，依赖可能已腐。**只借参数形态，不引代码。**

---

## 3. Agent 编排框架：2026 年的选择，以及能不能替掉本项目的子 Agent

### 3.1 四个硬指标的横向表（按用户点名的四项）

| 框架 | 并行子任务 | 断点续跑（跨进程/重启） | 超时换路 | 人工介入点 | 证据 |
|---|---|---|---|---|---|
| **LangGraph** | ✅ concurrent primitive | ⚠️ checkpoint，**但不是 durable execution** | ❌ 需外接 | ✅ `interrupt()` 内建 | `文档` |
| **Temporal（+ LangGraph 插件）** | ✅ 跨框架子 Workflow | ✅ **原生 durable** | ✅ **`start_to_close_timeout` + `RetryPolicy` + heartbeat** | ✅ `interrupt()` 在 Activity 节点 | `文档` |
| **OpenAI Agents SDK** | ⚠️ handoff 线性强，并行/投票要自己建 | ❌ 官方建议配 Temporal/DBOS | ❌ | ✅ sessions | `文档` |
| **CrewAI** | ⚠️ role-based crews | ❌ 无 durable execution | ❌ | ⚠️ | `文档` |
| **Mastra** | 未细查 | 未细查 | 未细查 | 未细查 | `未找到`（仅知"Partial 开源"） |
| **opencode（本项目现用）** | ✅ `task` + `background=true` | ❌ | ❌ | ✅ 人工 @ | `文档`（源码） |

### 3.2 LangGraph vs Temporal —— 这场架空的**本质**（2026-06/07 两篇对打）

`文档` [LangChain 官方对比页（2026-06-16）](https://www.langchain.com/resources/langgraph-vs-temporal)：

> "Temporal handles durable execution… but When you are building AI agents, you need more than a runtime durability layer."
> 表：LangGraph `Payload/context limits ✔️` vs Temporal **`2MB cap`**；HITL：LangGraph `✔️` vs Temporal `custom signals`；Streaming：LangGraph `✔️` vs Temporal `❌`

`文档` [Temporal 官方回击（2026-07-16）](https://temporal.io/blog/temporal-langgraph-plugin-durable-execution) —— 这段值得逐字存档：

> "**Recovery is manual. LangGraph checkpoints state, but checkpoints are not durable execution.** A LangGraph run lives in a single process, so **if that process dies then the run dies with it.** The checkpoint preserves your data, not your execution."
> "**Human review stops the world.** When a LangGraph agent hits `interrupt()`, execution halts and the resume problem lands on you."
> "**Long-running work strains the execution model.** Agents that run for days, fan out to sub-agents, or carry growing state push hard on LangGraph's checkpointing, intermediate-state handling, and memory management."

`文档` LangGraph 自己的文档其实已经承认了 durability 是三档：

> `durability = "exit"` — "**Changes are persisted only when graph execution exits… intermediate state is not saved, so you cannot recover from system failures**"
> `durability = "sync"` — "**the most durable**… at the cost of performance overhead"

`文档` Temporal 的 Activity 配置（[docs.temporal.io](https://docs.temporal.io/develop/python/integrations/langgraph)）：

```python
"start_to_close_timeout": timedelta(seconds=30),
"retry_policy": RetryPolicy(maximum_attempts=3),
```

> 👉 **这就是「超时换路」的原生形态**：`start_to_close_timeout` 到点 → `RetryPolicy` 重试 → 烧完 `maximum_attempts` 走失败路径。
> 对照 `AGENTS` 里 `roughcut-launch.md §2.5` 的「约定轮次默认 3 轮」—— **08 号前置 4 点的矛盾（`§2.5` 的 3 vs 02 号的 attempt ≤ 2）在这里有一个现成的裁决形态**：
> `timeout` 是"这一格最多花多久"，`attempts` 是"这一格最多试几次"，**两者是正交的两个字段，不该共用一个数字**。
> Temporal 把它拆成 `start_to_close_timeout` 和 `maximum_attempts` 正是为了防这个混淆。**建议 08 号前置 4 按这个形状定死。** `推断`

### 3.3 能不能替掉本项目的子 Agent？—— 不能。三个理由

**理由一：通用框架不可能知道本项目的状态字段。**
02 号设计的 `taskstate.json` 里有 `lanes[].images_seen`、`ledger.recycle_fill_rate`、`coverage_complete`、`seams[]`。**没有任何通用编排框架的 schema 里有这些字段，也不可能有** —— 它们是《永劫无间》的领域知识。这是本项目的资产，不是通用框架能提供的。

**理由二：opencode 现在缺的东西，恰好就是 02 号要造的东西。**
`文档` opencode 源码（[packages/opencode/src/tool/task.ts](https://github.com/anomalyco/opencode/blob/dev/packages/opencode/src/tool/task.ts)）：

- `background=true` **是实验特性，被 flag 挡着**：`if (runInBackground && !flags.experimentalBackgroundSubagents) → 需要 OPENCODE_EXPERIMENTAL_BACKGROUND_SUBAGENTS=true`
- 子 Agent 深度默认封顶：`cfg.subagent_depth ?? 1`
- 后台任务启动后的固定文案："**DO NOT sleep, poll for progress, ask the task for status**"

`文档` 社区插件补的也是同一批洞（[AutomatorAlex/opencode-background-tasks](https://github.com/AutomatorAlex/opencode-background-tasks)，1★）：`bg_task` 扇出、`bg_task_list`、`bg_task_reconcile`、`bg_task_question_list` / `bg_task_question_reply`（后台任务回问主会话）、`mode: shared|isolated` 工作区策略。

> ⚠ 另一个插件（[kdco/background-agents](https://www.opencode.asia/ecosystem/plugins/background-agents)）把超时写死为 **15 分钟**、且子 Agent 只读。

> `推断` —— **1★ 插件在补 `bg_task` 扇出，说明这是真需求；但「15 分钟超时」对这个项目是灾难性的**（08 号记录的 861 单局 7.83 h、单路渲染常超 20 分钟）。
> **换框架解决不了这个问题，因为这个项目需要的超时是「按路族计数的 3 次尝试」，不是「15 分钟墙钟」。**

**理由三：换框架要重写已验证的东西。**
`AGENTS §2` 的环境铁律 + `§7.1` 的清理脚本 + 08 号实测的 17 扇门 + 35 份历史时间线的回归基线 —— 全部建在 opencode + PowerShell + Python venv 上。**换框架的收益（一个通用 checkpoint）远小于重写这些的成本。**

### 3.4 那么该借什么？—— 只借机制，不借框架

| 借 | 从哪借 | 落到本项目哪 |
|---|---|---|
| `start_to_close_timeout` / `RetryPolicy` 正交拆分 | Temporal Activity | 08 号前置 4：把 `§2.5` 的「3 轮」拆成 `timeout_sec` + `attempts_max` 两个字段 |
| 「Structured plan as durability mechanism」 | Cloudflare [long-running-agents.md](https://github.com/cloudflare/agents/blob/main/docs/agents/long-running-agents.md) | `taskstate.json` 的 `phase` + `next_actions` |
| 「Agent self-reviews before you see it」 | OpenMontage | 08 号批 4 的 P6（主 Agent 零图 + 派一路去看） |
| catalog 自动生成 prompt 契约 | json-render | 08 号批 5a 的「单源纪律」实现方式 |
| 预览与成片共用同一 payload | Remotion `inputProps` | **新增建议**，见 §2.1 |

---

## 4. 「给素材 + 一句话 → 自动出预览」这个交互的最佳实践

### 4.1 收敛成六条（每条都有出处）

| # | 原则 | 出处 | 与本项目现状 |
|---|---|---|---|
| 1 | **Intent-First**：主界面是"你要什么"的大输入框 + 约束，不是功能导航 | [agentic-ux.com/framework](https://www.agentic-ux.com/framework)（2026-08-05） | ✅ 已经是（入口一句话） |
| 2 | **只问会改变计划的问题，然后收敛** | 同上："Ask only what changes the plan, then converge" | ⚠️ 08 号判定三道用户门在预览段已消，但 N1/N2/N3 三项点头未消 |
| 3 | **Partial output is honest progress; a spinner is a promise** | [scrimui.dev](https://scrimui.dev/inspiration/long-task-progress) | ✅ 08 号的心跳设计 |
| 4 | **失败时给 resume path，绝不给 blank slate** | 同上："show what completed, what failed and what will be retried… **never a blank slate**" | ✅ `taskstate.json` 的 12 行 resume 清单 |
| 5 | **重进会话时给自然语言 recap** | [UX Magazine](https://uxmag.com/articles/designing-for-autonomy-ux-principles-for-agentic-ai-systems)："While you were away, I confirmed your hotel and drafted your expense report" | ✅ 同上 |
| 6 | **Auto-Accepting Plans：便宜的步骤不问** | [Kapwing 2026-03 release notes](https://www.kapwing.com/help/release-notes-march-2026)："we added auto-accepting logic when Kapwing AI plan is inexpensive, less than 40 credits" | `推断` → 本项目的对应形态：**只读步骤不问，只写/只删步骤必须问** |

### 4.2 分几次汇报？—— 商业界的实际做法是「3 类消息，不是 3 次汇报」

`文档` [Kapwing 2026-02 release notes](https://www.kapwing.com/help/release-notes-february-2026) —— 一家做了 prompt-to-video 的公司，把它拆成了三种不同的消息通道：

> "Under the hood, we also improved **long-running AI workflows so users get notified when jobs finish instead of waiting around and refreshing tabs.**"
> "Notifications to Kapwing AI for long-running processes so that you can **get a ping when your video is ready to preview.** Notifications save you time and mindshare so that you can **multitask rather than staring at your computer screen.**"

`文档` Cloudflare 的 agent 模型给了第四种：**wake up on schedule**（"Wakes up on schedule to check deadlines and send reminders"）。

`文档` OpenMontage 的流程图给了第五种：**self-review before user sees it** —— "then **reviews its own output by extracting frames and transcribing audio to catch issues before you even see them**. Every creative decision gets your approval."

> **`推断` —— 合起来是这五条通道，本项目只应该有一条半：**
>
> | 通道 | 本项目 | 依据 |
> |---|---|---|
> | 心跳（无结论、可关闭） | ✅ 已有 | 08 号 §5「不许问，默认发，用户回『不用』才关」 |
> | 完成通知（产物可播） | ✅ 已有 | 交付那一行 |
> | **定时自检唤醒**（watchdog） | ⚠️ 需批 N1 | 08 号 5c |
> | 自审在用户之前 | ⚠️ 需批 P6 | 08 号批 4 |
> | 需要人拍板时中断 | ✅ 三项点头 | N1/N2/N3 |
>
> **关键判据（本轮新证据支持）**：Kapwing 明确把「通知」和「等待刷新页」对立 —— 通知的价值是**让人能离开屏幕**。
> 这从外部证实了 08 号那条判据：「心跳不含任何可播放产物、不含结论、不可回复交互 → 它是通知不是请示」。
> **一条不能让人离开屏幕的消息，就不是心跳，是打扰。**

### 4.3 「一版过」的外部定价：所有产品都承诺不了

`文档` [PremiereCopilot 2026-06 指南](https://www.premierecopilot.com/en/blog/ai-video-editing-premiere-pro)（第三方评测）：

> "In 2026 it genuinely does **about 80% of the timeline work**, and the gap between 'AI gimmick' and 'AI that saves you a day' has gotten huge."
> "**Being honest, because trust is the whole game here: AI does not yet replace an editor's judgment on pacing, story, and emotional beats — it gets you a fast first cut, not a finished film.**"
> "It produces a real, editable timeline, **not a locked export**. **What it can't do is make the creative calls: pacing, story, emotion. That's still you.**"

`推断` —— 成熟商业软件（Adobe，投入最大）到 2026 年 6 月的官方口径是「**给你一个快的一版，不是成片**」。
本项目 08 号判定「能到 85%，剩 15% 是语义漏战只能看片」，与这个外部口径**高度一致**。

> **这句话可以直接进 08 号的对外说明**：不是本项目做得差，是这一类问题的行业上限就在这儿。

---

## 5. 给本项目的具体建议（按「回报 / 成本」排序）

### ★ 建议 1：把 `§8.1` 的「间隙 6 秒」参数化（成本最低，收益明确）

**依据**：`推断` + `文档`（crispy 的 `second-between-kills` 已证明这个参数形态可行）
**动作**：在 `config/` 下建一个参数真源，名字带单位（如 `merge_gap_sec`），`qa_gate.py` 和 `roughcut-launch.md` 都从它读。
**理由**：08 号已识别的通病是「同一个数字散在多份文件里已经不一致」。散文里的数字迟早长出第二个值。

### ★ 建议 2：照抄 json-render 的 catalog → prompt 契约，作为 08 号批 5a 的实现方式

**依据**：`文档`（json-render README）
**动作**：批 5a 不只是"写 12 个字段的 JSON"，而是**写一个生成器**，从 schema 产出 ①12 行 resume 清单 ②verify 检查项 ③台账表头。
**理由**：08 号批 5a 的验证标准里那条「verify 判投影列名 ≠ schema 列名 → exit 2」是**兜底**；生成器让这件事**不可能发生**。兜底不如结构。

### ★ 建议 3：新增一条硬规则 —— 预览与成片共用同一份时间线 payload

**依据**：`文档`（Remotion 官方 `inputProps` 说明）+ `推断`
**动作**：在 `AGENTS.md` 或 `naraka-highlight-studio` 里加一句，形态类似「预览和成片必须从同一份 timeline JSON 渲染；任何一侧改了 cut_list，另一侧必须同步并重渲」。
**理由**：`AGENTS §1` 已有「成片从原始素材重新渲染」（防放大），但**没有**「防时间线分叉」。这两条是不同方向的护栏，后者目前是空的。

### ★ 建议 4：按 Temporal 的形状拆 `§2.5` 的重试数字（顺手解决 08 号前置 4）

**依据**：`文档`（Temporal `start_to_close_timeout` + `RetryPolicy`）
**动作**：`timeout_sec`（这一格最多花多久）与 `attempts_max`（这一格最多试几次）分成两个字段，再定 08 号前置 4 要的数。
**理由**：现在两份文件各有一个数（3 / ≤2）且都「已核实」，说明**这个数字被当成了同一个语义的两份实现**。它其实是两个语义。

### ★ 建议 5：**不要**引入 revideo / MoviePy / editly / cutagent（成本高、收益负）

**依据**：`文档`（revideo 重心转 Midrender；MoviePy README 自述慢且维护带宽不足；editly/cutagent 未实测）
**动作**：只读源码借鉴 EDL 形状，不装包。
**理由**：`AGENTS §2` 的环境铁律 —— 项目里已有的东西最优先，且 venv 里**没有** MoviePy 是有意义的现状，不是遗漏。换渲染引擎会丢掉已验证的 4K60 NVENC 链路，而 `08` 判「坏掉方向是安全」——**渲染器是这条链路上唯一一个换错了会静默产出错分辨率成片的环节**（08 号前置 4 已实测：`extract_frames.ps1` 的默认值会静默产出 0 帧还不报错）。

### ⚠ 建议 6：Eklipse 只当**判据来源**，不当依赖

**依据**：`文档`（支持 Naraka，但输出竖屏+烧录字幕；未找到公开 API）
**动作**：把它的四层检测（game events / voice+game audio+ambient / action density / scene-aware 边界 / per-genre tuning）写成参考，**不要**接它的服务。
**理由**：`AGENTS §5` 禁烧录、`§6` 要 4K60，两条都和它的输出形态冲突；且无 API。**它的价值是它那套「什么算高光」的四层拆法，以及那条"语音峰值 × 游戏音频响度 × 画面动作密度三者同时高才加分"的反误报规则。**

---

## 6. 未找到 / 未取证（明确不编）

| 项 | 状态 |
|---|---|
| Eightify 对游戏画面的适配 | `未找到` —— 本轮未查 |
| manim 是否有片段级（trim/concat）复用 API | `未取证` —— 本轮未单独查；只有基于其定位的 `推断` |
| Eklipse 的公开 API | `未找到` —— 只有产品页与帮助页，无开发者文档 |
| Mastra 的四项硬指标 | `未找到` —— 仅知"Partial 开源"，未细查 |
| Shotstack 等托管 JSON 时间线服务 | `未找到` —— 仅第三方博客一句提及，未查官方文档 |
| 任何「面向游戏录屏的 JSON 时间线渲染器」 | `未找到` —— 搜到的游戏向开源项目全部是「用 ML 找高光」 |
| 各商业品的**价格** | **一律未取证。本报告不写任何价格数字。**（唯一例外：Kapwing/Descript 的价格来自第三方评测文章，已标出处且未在结论中依赖） |
| `cutagent` / `video-mix-with-codex` / `crispy` 的**实跑** | 未跑，只读 README。引入前须按 `AGENTS §2` 先跑预检 |

---

STATUS: DONE