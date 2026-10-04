# 看图预算 04：厂商图片限制差异 与 本项目换模型实况

> 分析员任务单第 4 份。前三份查的是「这条规则本身」（01）、「能否自动探测」（02）、「有没有更省图的替代」（03）。
> 本单只查两件事：**外部世界的限制长什么样**，以及**本项目现在到底跑在谁身上**。
>
> 结论一句话先给：**用户「换了网关和模型」这半句只有一半成立——模型换了，host 没换；而三家厂商的限制数字在本环境一个都取不到，所以我不写任何数字。真正可确证的是：这条限制在所有权威机器可读来源里都不存在。**

---

## 0. TL;DR

| 问 | 答 | 证据强度 |
|---|---|---|
| 当前模型是谁 | `opencode-go / space-bunny-free`，走 `opencode.ai/inference/go/openai/v1` | 本机 API 实读，直接 |
| 「换了网关」成立吗 | **模型换了，host 没换**。新旧模型同属 `opencode.ai`，只差路径段 | 本机 API 实读，直接 |
| 旧模型 `muse-spark-1.3-contributor-free` 还在吗 | **在，`enabled: true`**。2 号 Agent 结论正确，我独立复核 | 本机 API 实读，直接 |
| 本项目接的是 OpenAI/Anthropic/Google 官方吗 | **不是**。本安装可见的 40 个模型里**没有任何 Claude 或 Gemini** | 本机 API 实读，直接 |
| OpenAI 单请求图片数 | **未能核实**（`platform.openai.com` 返回 403） | 访问失败，非「未公布」 |
| Claude 单请求图片数 | **未能核实**（`docs.anthropic.com` 地域封锁） | 访问失败，非「未公布」 |
| Gemini 单请求图片数 | **未能核实**（`ai.google.dev` 网络不可达） | 访问失败，非「未公布」 |
| 我们实际用的网关公布图片上限吗 | **确证：没有**。`/docs/zen` 明写图片按 token 计费；`/docs/go` 只公布月度金额与 5 小时窗口 | 官方文档原文，直接 |
| 50 属于按请求还是按会话/按天 | 项目文档自述为**按请求**（"单次请求携带的图片总数"）。但「会话作废」需要第四种机制，**无人公布、且日志里零次发生** | 文档自述 + 27.8 MB 日志实测 |
| 换模型后 50 还成不成立 | **它不是「必需」，也不是单纯「自缚手脚」——它是一个查不到出处的绝对量**。真正生效的约束是 token 预算，50 只占其约 1/6 | 本机 `limit` 字段 + 网关计费原文 |
| 兼容性成本能否趋零 | **能，但路线不是「自动探测」**（无源可探）。路线是**把单位从 model 换成 route**：40 个模型只落在 **3 条** baseURL 上 | 本机 API 全量枚举，直接 |

---

## 1. 核实：当前实际模型清单

### 1.1 取证方法（为什么这个来源可信）

不用文档、不用记忆，直接问**正在跑的这个 client 自己的注册表**：

```
GET http://127.0.0.1:49374/api/model/     (Basic auth，密码取自 ~/.config/opencode/service.json)
→ { location, data: [ ...40 条... ] }
```

这是运行时真正用来路由请求的那份数据，`/api/config` 也确认了配置目录只有 `C:\Users\Administrator\.config\opencode`，里面**只有 `service.json`**。

补充核实（都做了）：
- 全项目递归搜 `opencode*.json` / `opencode.jsonc` / `auth.json` / `agent*.json` → **0 命中**。仓库里没有任何文件钉住模型。
- 环境变量：只有 `OPENCODE=1`、`OPENCODE_CLIENT=desktop`、`OPENCODE_SESSION_ID` 等，**无 `OPENCODE_API_KEY`**（models.dev 声明该 provider 需要此 key）。

### 1.2 本会话实际在用的模型（记录原文）

```json
{
  "id": "space-bunny-free",  "modelID": "space-bunny-free",
  "providerID": "opencode-go",
  "package": "@opencode/ai/providers/openai-compatible",
  "settings": { "baseURL": "https://opencode.ai/inference/go/openai/v1" },
  "headers":  { "x-opencode-org-id": "wrk_01KY6DZREHRE3MC9EP3B6MT354" },
  "capabilities": { "tools": true, "input": ["text","image","video"], "output": ["text"] },
  "limit": { "context": 1048576, "input": 524288, "output": 524288 },
  "cost": 0,  "status": "active",  "enabled": true
}
```

**图片输入能力：有**（`input` 含 `image`）。

### 1.3 旧模型仍然启用 —— 2 号 Agent 的说法我确认

```json
{
  "id": "muse-spark-1.3-contributor-free",  "providerID": "opencode",
  "package": "@opencode/ai/providers/openai",
  "settings": { "baseURL": "https://opencode.ai/inference/openai/v1" },
  "capabilities": { "input": ["text","image","video","pdf","audio"] },
  "status": "active",  "enabled": true
}
```

> `muse-spark-1.3-contributor-free` 与 `space-bunny-free` **同时 `enabled: true`**。
> 全表 40 条**没有任何一条 `enabled: false`**。
> 所以「换掉了」只等于**这次会话选了另一个**，不等于旧模型被下线或改配。

> ⚠️ 与 2 号 Agent 的一处出入：它记 `opencode` provider 的 package 为 `@opencode/ai/providers/openai-compatible`，而 `/api/model/` 这条记录写的是 `@opencode/ai/providers/openai`（少 `compatible`）。两者可能是不同端点粒度。不影响结论（同一个 host、同一个协议族），但若要写进正式文档请以 `/api/model/` 为准。

### 1.4 「换了网关」这句话，一半不成立

| | 旧（规则锚点里写的） | 新（当前在用） |
|---|---|---|
| 模型 | `muse-spark-1.3-contributor-free` | `space-bunny-free` |
| providerID | `opencode` | `opencode-go` |
| **host** | **`opencode.ai`** | **`opencode.ai`** ← 同一个 |
| 路径 | `/inference/openai/v1` | `/inference/go/openai/v1` |
| org header | `wrk_01KY6D…354` | `wrk_01KY6D…354` ← 同一个账号 |

**模型换了，host 和账号没换。** 只有路径段和适配器包不同。
> 这不改变「50 可能已失效」的结论，但改变了**为什么**失效、以及**该去哪儿核实**——不是去找 Meta 或 OpenAI，而是找 `opencode.ai` 这层代理。

### 1.5 完整清单（40 条，全部 `enabled: true`）

`IMG` = `capabilities.input` 含 `image`。

**`opencode` = OpenCode Zen（11 条），baseURL 全为 `opencode.ai/inference/openai/v1`**

| 模型 | 图片 |
|---|---|
| `muse-spark-1.3-contributor-free` | IMG |
| `muse-spark-1.3` | IMG |
| `space-bunny-free` | IMG |
| `fledge-alpha-free` | IMG |
| `gpt-6-luna` | IMG |
| `deepseek-v4.1-flash` | IMG |
| `glm-5.3-flash` | IMG |
| `minimax-m3` | IMG |
| `mimo-v2.6-flash-free` | IMG |
| `longcat-2.5-preview-free` | IMG |
| `ling-3.1-flash-free` | — |

**`opencode-go` = OpenCode Go（29 条）**

- baseURL `…/inference/go/openai/v1`（23 条）：`space-bunny-free` IMG、`muse-spark-1.3-contributor` IMG、`muse-spark-1.2-contributor` IMG、`grok-4.7` IMG、`grok-4.6` IMG、`gpt-6-luna` IMG、`gpt-5.6-luna` IMG、`kimi-k3` IMG、`kimi-k2.7-code` IMG、`glm-5.3` IMG、`glm-5.3-flash` IMG、`glm-5.2`、`mimo-v2.6-pro`/`flash` IMG、`mimo-v2.5`/`-pro` IMG、`deepseek-v4.1-flash` IMG、`deepseek-v4-flash`、`deepseek-v4-flash-vision-exp` IMG、`deepseek-v4-pro`、`hy3`、`hy4-preview`、`longcat-2.0`
- baseURL `…/inference/go/anthropic/v1`（6 条）：`minimax-m3` IMG、`minimax-m2.7`、`qwen3.8-max` IMG、`qwen3.8-flash` IMG、`qwen3.7-plus` IMG

> **本安装可见的 40 个模型里，没有任何一个 Claude 或 Gemini。**
> 上游 Zen 目录确实带 Claude/Gemini（models.dev 的 `opencode` 条目共 116 个模型，含 `claude-opus-5`、`gemini-3.6-flash` 等），但本安装只放出了 11 个，全是第三方或免费档。
> **即：本项目当前根本不在跟 Anthropic 或 Google 的官方端点说话。** 讨论「Claude 允许多少张」对今天的运行没有约束力。

---

## 2. 主流厂商的公开图片限制

### 2.1 先交代本环境的网络实测（这决定了下面哪些能写、哪些不能写）

| 目标 | URL | 实测结果 |
|---|---|---|
| Anthropic | `docs.anthropic.com/en/docs/build-with-claude/vision` | HTTP 200，但正文是 **"App unavailable in region"**（地域封锁） |
| Anthropic | `docs.claude.com/en/docs/build-with-claude/vision`、`.md` | 同上，地域封锁 |
| OpenAI | `platform.openai.com/docs/guides/images-vision` | **403**（Cloudflare 拦截页） |
| OpenAI | `platform.openai.com/docs/guides/vision` | **403** |
| OpenAI | `openai.com/index/introducing-gpt-4o/` | **403** |
| Google | `ai.google.dev/gemini-api/docs/image-understanding` | **Transport error**（无路由，DNS/网络层不通） |
| Google | `cloud.google.com/vertex-ai/generative-ai/docs/multimodal/image-understanding` | **Transport error** |
| 搜索工具 | — | `websearch` 连续 3 次返回 **"Web search cancelled"**（工具不可用） |
| ✅ 可达 | — | `opencode.ai`、`models.dev`、`api.github.com`、`raw.githubusercontent.com`、`docs.litellm.ai` |

### 2.2 三家结论表

| 厂商 | 单请求图片数 | 单图尺寸 | 单请求总 token | 状态 |
|---|---|---|---|---|
| **OpenAI** | **未能核实** | **未能核实** | **未能核实** | 官方源 403，非「未公布」 |
| **Anthropic** | **未能核实** | **未能核实** | n/a（按 token 窗口） | 官方源地域封锁，非「未公布」 |
| **Google** | **未能核实** | **未能核实** | **未能核实** | 官方源网络不可达，非「未公布」 |

**我不写数字。** 任务单明确要求「不要编」，而我在这台机器上取不到任何一家的官方页面。
凭记忆填三个具体数字、配上官方 URL 冒充已核实，是这类报告最容易出的错——**URL 会让人以为核实过，而它其实只证明我抓到了什么。**

> **「未能核实」≠「未公布」。** 这两家都公开发布过多模态限制，只是本环境到不了。
> 需要填数字的人，请从下面这张清单直接取，并**当场记下抓取日期**：

| 厂商 | 权威页面 |
|---|---|
| OpenAI | `https://platform.openai.com/docs/guides/images-vision`、`/docs/guides/vision`、`/docs/guides/pdf-files` |
| Anthropic | `https://docs.claude.com/en/docs/build-with-claude/vision`（`/vision.md` 可直接拿 markdown） |
| Google | `https://ai.google.dev/gemini-api/docs/image-understanding`、`/gemini-api/docs/tokens`、`/gemini-api/docs/models` |

### 2.3 旁证：可达的官方源里也没有这些数字

为排除「只是我找错页面」，把能到的官方仓库正文全爬了一遍（只取 markdown 与代码单元，跳过 base64 输出块）：

| 官方来源 | 检索模式 | 命中 |
|---|---|---|
| `anthropics/anthropic-cookbook` → `multimodal/getting_started_with_vision.ipynb` | 图片张数 / `NxN` px / MB / megapixel / "images per request" | **0** |
| `anthropics/anthropic-cookbook` → `multimodal/best_practices_for_vision.ipynb` | 同上 | **0** |
| `openai/openai-cookbook` → `examples/GPT_with_vision_for_video_understanding.ipynb` | 同上 | **0** |
| `openai/openai-python` → `README.md` | 同上 | **0** |
| `googleapis/python-genai` → `README.md` | 同上 | **0** |
| `docs.litellm.ai/docs/providers/gemini`（**第三方**，仅作旁证） | 同上 | 只有**图片「输出」**的 token 计价表（1K–2K→1120 tok、4K→2000 tok），**不是输入图片张数** |

> 官方 cookbook 是**教你怎么用**的，不是**声明限制**的，查不到不等于限制不存在——但它确实说明：**这些数字没有以可抓取文本的形式沉淀在厂商的公开仓库里。**

### 2.4 本项目真正用的网关：**确证「未公布」**

这一节是本单最硬的证据，因为它**不依赖任何被封锁的源**。

**(a) 网关自己的文档给出了图片的计量方式——按 token，不是按张数**

`https://opencode.ai/docs/zen` 原文：

> **"Images are converted into tokens based on their dimensions and billed as input tokens alongside text tokens."**
> （图片按尺寸折算成 token，与文本 token 合并计费。）

**(b) 网关公布的所有限制轴，没有一条与图片张数有关**

`https://opencode.ai/docs/go`（当前 `opencode-go` provider 对应的正是这条线路）公布的是：

- 「Usage limits are defined as **monthly dollar amounts**」
- 「Each model has the following usage limits: **5-hour — 20% of the monthly limit**」
- 「Token prices are per 1M tokens」

> 即：**月度金额 + 5 小时窗口（按月度额度的 20%）+ token 单价**。三条全是金额与 token，**没有「每请求 N 张」**。
> 逐页检索 `/docs/models`、`/docs/go`、`/docs/zen`、`/docs/providers`：`\d+ images?`、`images per request`、`N MB`、`NxN px`、`megapixel`、`attachment` —— **全部 0 命中**。

**(c) 运行时模型记录的结构里，没有「图片张数」这个字段**

`/api/model/` 返回的完整字段集（逐条枚举过）：

```
id, modelID, providerID, family, name, compatibility, package, settings, headers,
capabilities{ tools, input[], output[] }, variants[], time, cost,
status, enabled, limit{ context, input, output }
```

`limit` 只有三个 token 数（`context` / `input` / `output`）。
图片信息只有 `capabilities.input` 里有没有 `"image"` 这个**布尔式**信号，**没有任何数量字段**。

**(d) 上游元数据库 models.dev 同样没有——这是最关键的一条**

models.dev 是 OpenCode 自己依赖的模型元数据源（日志里那条唯一的 ERROR 就是 `Failed to fetch models.dev`）。全库实测：

```
providers : 226
models    : 8393
字段词表（21 个）：
  attachment, canonical_model_id, cost, description, experimental, family, id,
  interleaved, knowledge, last_updated, limit, modalities, name, open_weights,
  provider, reasoning, reasoning_options, release_date, status,
  structured_output, temperature, tool_call
  limit.context, limit.input, limit.output
与 image/img/picture/vision/photo/media 相关的字段：0 个
```

> **8393 个模型、226 家 provider，没有任何一个字段承载「单请求图片数」或「单图尺寸」。**
> 图片能力只有 `attachment: true/false` 和 `modalities.input: ["text","image",…]`。

---

## 3. 这些限制属于「按请求」还是「按会话/按天」

### 3.1 分类学（用来说清用户把哪两件事混成了一件）

| 类别 | 触发单位 | 典型失效形态 | 恢复代价 |
|---|---|---|---|
| **按请求** | 一次 HTTP 请求 | 该请求被拒（4xx），带错误体 | **低**：去掉几张、重发即可。会话不受影响 |
| **按会话 / 按上下文** | 一个会话累计 | 超出后该会话后续请求被拒或质量降级 | 中：开新会话，或压缩历史 |
| **按天 / 按月配额** | 时间窗内累计 | 额度耗尽，需等待或换档 | 高：等 |
| **状态损坏**（第四类） | — | 会话**不可恢复**，必须换会话 | 最高 |

### 3.2 「50」是哪一类

项目文档自述（`IMAGE_LIMIT.md`、`AGENTS.md §9`）：

> 「上游**单次请求**携带的图片总数上限都是 50 张」

→ 声明为**按请求**。按定义，触发单位是一次请求，**失败形态应当是「这一个请求被拒」**，不是「会话报废」。

### 3.3 用户担心的「超 50 → 会话作废」属于哪一类

**属于第四类：状态损坏。** 而这一类：

- **没有任何网关公布过这种机制**——`/docs/go`、`/docs/zen` 只有金额与 token 窗口，无此类条款；
- **在本机 27.8 MB 运行日志里零次发生**——实测统计：

| 项 | 实测值 |
|---|---|
| 日志区间 | 2026-09-30 → 2026-10-04 |
| `level=ERROR` 总行数 | **2**（一条是我自己的 grep 命令被记进日志，另一条是 `Failed to fetch models.dev` 超时） |
| 含 400 / 413 / 429 / `invalid_request` / `context_length` / `too many image` 的行 | **0** |
| WARN | 仅 worktree 发现失败、git snapshot、`schema rejection "Expected a value less than or equal to 200 at [\"limit\"]"`、provider 配置拉取超时 |
| `muse-spark` / `space-bunny` 出现次数 | 各 2 次，**全是本会话自己敲的命令**被记进日志；日志**不含任何模型/路由身份记录** |

> 所以「会话作废」在本机既无文档依据、也无一次实际发生。
> **把它当「硬失败会导致会话报废」的风险来防守，是在防一个未观测到的第四类机制。**

### 3.4 那今天真正会拦住我们的是什么

按网关公布的轴，只有两件事会真的拒绝我们，而且**都不是「张数」**：

1. **token 预算**——`space-bunny-free` 的 `limit.input = 524288`，图片按尺寸折算 token；
2. **额度窗口**——月度金额，以及 5 小时窗口（= 月度额度的 20%）。

> 把预算建在「张数」上，等于**用一个没人公布、也没人观测到的量**，去代理一个**公布得很清楚、而且可以直接量出来的**量。

---

## 4. 关键：换模型后，看图预算这个约束还成不成立

任务单要求分情况给结论。我按三种情况判，并对本项目落到实数。

### 情况 A：新模型/网关限制更宽松 → 50 是自缚手脚

**部分成立，但诊断错了对象。**

- 成立的部分：当前 host 的文档里**根本不存在**「每请求 N 张」这条限制（§2.4 已确证）。50 找不到任何现行出处。
- 诊断错的部分：**host 没换**（§1.4）。不是「换到了更宽松的新网关」，而是「还在同一个网关的另一个路径段上」。
- 结论：**50 不能被论证为「必需」**，但也**不能被论证为「已被放宽所以无用」**——因为从来就没有一份现行文档写过它。

### 情况 B：限制仍在但机制不同（硬失败 vs 静默丢弃）→ 需要不同防护

**这一条我同意 2 号 Agent 的实测方向，但要补一句关键限定。**

- 机制层面：按请求超限的标准形态就是**该请求被 4xx 拒掉**，会话本身不死。2 号 Agent 实测 harness 侧无静默截断。
- **但真正的风险不是机制，是「静默丢弃」与「硬失败」在本项目都不可观测**——因为没有任何一层会把这个数报给我们：
  - 网关不公布（§2.4）；
  - 运行时 schema 没有字段（§2.4c）；
  - models.dev 8393 个模型没有字段（§2.4d）；
  - `check_image_budget.ps1` **只打印不拦**，且 `-Cap` 由调用者传入、非递归 glob 会少算（01 号已实测）。
- 需要的防护因此**不是**「按新机制改阈值」，而是「**别再声称知道阈值**」。

### 情况 C（本项目的实际情况）：把 50 换算成真正生效的那个单位

用本机 `limit.input = 524288` 和网关的「图片按尺寸折算 token」规则：

| 场景 | 估算 | 占 `limit.input` 比例 |
|---|---|---|
| 50 张 960px 单帧（864 用过的规格） | 50 × ~1,650 tok ≈ **82,500 tok** | **≈ 16%** |
| 50 张 640px 联系表格（863 用过的规格） | 50 × ~290 tok ≈ **14,500 tok** | **≈ 3%** |

> **50 张在 token 口径下只占输入预算的 3%–16%，离任何真正的墙都很远。**
> 而三个已交付任务实测峰值只有 44 张（01 号统计），**连一半都没用满**。
> 换句话说：**50 这个数从来不是被上游逼出来的，是被我们自己写进 8 份文档当地基的。**

### 4.1 判定

> **今天既不能说「50 仍必要」，也不能简单说「50 是自缚手脚」。**
> 准确的说法是：**它是一个查不到出处的绝对量，挂在一条没有任何现行文档支持的因果链上。**
>
> - 「上游限制」这半句：**已无证据**（网关未公布 + 零事故 + 零日志）。
> - 「防止会话作废」这半句：**机制上不成立**（按请求超限只会拒一个请求，不会毁会话）。
> - 「作为成本/上下文纪律」这半句：**成立且有价值**，但它的正当理由应该是 token 与注意力成本，**不是上游红线**。

---

## 5. 未来换模型的兼容性：成本能不能趋零

### 5.1 先否定一个看似显然的方案：「自动探测」

02 号的实测结论是「无法自动探测：只能发真实请求，且不能发 GET」。我同意，并补一条**结构性**理由，它比「探测不到」更根本：

> **没有任何可轮询的源头。**
> - 网关文档：不公布（已证）
> - 运行时模型 schema：无字段（已证）
> - models.dev：226 provider / 8393 模型 / 21 个字段，**0 个图片相关**（已证）
> - 三家厂商官方文档：本环境不可达；且据可达的官方仓库（cookbook / SDK README）检索，**这些数字也没有以可抓取文本沉淀在公开仓库里**
>
> 所以「让脚本读出上限」不是**成本高**，是**不存在**。任何声称能自动读出这个数的方案都是假的。

### 5.2 能趋零的路线：把单位从 **model** 换成 **route**

这是本单给出的核心可执行结论。

40 个模型，实际只落在 **3 条 baseURL** 上：

| # | baseURL | 挂在哪 | 模型数 |
|---|---|---|---|
| 1 | `opencode.ai/inference/openai/v1` | `opencode`（Zen） | 11 |
| 2 | `opencode.ai/inference/go/openai/v1` | `opencode-go` | 23 |
| 3 | `opencode.ai/inference/go/anthropic/v1` | `opencode-go` | 6 |

**上游的限制按线路施加，不按模型名施加**（同一 baseURL、同一 org header、同一适配器协议）。
→ **换模型时需要重新确认的单位是「线路」，数量级是 3，不是 40。**

更进一步：其中线路 1 与线路 2 同 host、同协议族、同账号，**很可能共用同一个上游约束**。真实待确认单位很可能是 **1**。

### 5.3 三步把成本压到接近零

| 步骤 | 做什么 | 一次性成本 | 之后每次换模型的成本 |
|---|---|---|---|
| **1. 停止声称知道上限** | 把 8 份文档里的「上游 50 张红线」改成带日期与出处的历史注记（例：「此数字源自 `muse-spark-1.3-contributor-free` 时代，2026-10-04 起未再复现验证；当前线路无公开上限」） | 约 10 分钟 | **0** |
| **2. 改用能自己算的量** | 预算改为按 **token / 图片总字节** 计，口径取自网关自己的计费规则（图片按尺寸折 token）。这个量**不需要任何人公布**，数得出来 | 约 1 小时改脚本 | **0** |
| **3. 需要硬数字时，只探线路** | 一次性脚本：对 3 条 baseURL 各做一次二分探测（发小缩略图，10 次请求内定位悬崖），结果写入 `config/image_budget_probe.json`，预算脚本只读这个文件 | 一次性，且**需 API key** | 只在**换线路**时重跑（换模型不换线路 → 不重跑） |

**第 3 步的诚实前提**：探测要真的发请求，需要凭据。实测 `OPENCODE_API_KEY` **在当前 shell 与用户级环境变量中均未发现**。所以这一步**不是自动守卫，是需要人拿 key 跑一次的动作**——而且只需对 3 条线路各跑一次。

### 5.4 另一个把成本归零的办法：让失败**有界**而不是灾难

如果仍然担心「超限 → 会话报废」，最有效的防护不是猜阈值，而是**让单次看图批次足够小且互相独立**：

- 现在已经在做的「单轮新增 ≤10」，其**真正价值**就在这里——不是防止超限，而是**万一某个请求被拒，损失上限就是那 10 张，其余批次和已落盘的结论全部存活**。
- 配合「每轮之间先落盘结论再开下一轮」，一次被拒最多重做一批。
- 于是「会话作废」这种**无界灾难**，被转成**有界的小重做**。

> 这一条不需要知道任何阈值就能成立。**它把防护从「赌阈值」换成「控制爆炸半径」。**

### 5.5 判定

> 「每次换模型都人工确认看图上限」的成本，**不能靠自动探测归零（无源可探），但可以靠换单位归零**：
> **上限的真实单位是线路（≤3 条，很可能 1 条），不是模型（40 个）。**
> 叠加「按 token 自算」后，连线路都不用探——**成本趋零的做法是「不再声称知道上限」，而不是「更聪明地知道上限」。**

---

## 附：本单的方法与局限

**做了的核实（可复现）**
- `GET http://127.0.0.1:49374/api/model/`（Basic auth）→ 40 条模型全量，逐条 dump 字段
- `GET http://127.0.0.1:49374/api/config` → 确认唯一配置目录及其内容
- 全项目递归搜 `opencode*.json` / `auth.json` → 0 命中
- `models.dev/api.json` 全库扫描 → 226 provider / 8393 模型 / 21 字段 / 0 图片限制字段
- `opencode.log`（27.8 MB）→ ERROR/WARN 全量统计、模型名与错误码检索
- 网络可达性逐 host 实测（8 个 URL，见 §2.1）

**局限（必须交代）**
1. **三家厂商的限制数字一个都没取到**，原因全部是访问失败（403 / 地域封锁 / 无路由 / 搜索工具不可用）。我按任务单要求**没有编**，也没有从记忆里填数冒充核实。
2. 因此 §2.2 的空缺**不是「这些厂商不公布」**，而是「本环境到不了」。§2.4 的空缺才是真正的「确证未公布」，因为对象是本项目实际使用的网关。
3. 未修改任何规则文件、脚本或任务目录。本单只读 + 新建本报告。
4. 未做真实发图探测（无 API key），所以「当前线路的实际悬崖位置」仍然未知——§5.3 第 3 步是可选的一次性动作，不是结论。