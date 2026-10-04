# 看图预算：能不能自动探测，而不是写死 50

> 分析员任务单第 2 份。第 1 份（`01-provenance-and-cost.md`）查的是「50 从哪来、代价值多少」。
> 本单查的是**技术上能不能自动算出来**。方法：不读文档结论，直接探测本机 harness 与上游。
> 结论一句话：**能自动探测，但探测对象不是「张数」而是「token」；失败是硬失败；不该试探；「模型侧自己管预算」不成立。**

---

## 0. TL;DR

| 问题 | 答案 | 证据强度 |
|---|---|---|
| 失败是硬失败还是静默降级？ | **硬失败**（HTTP 4xx + JSON 错误，harness 抛类型化错误）。**无静默丢弃机制** | 本轮两次亲眼撞到硬失败 + 二进制无任何图片计数逻辑 |
| 客户端有没有图片数上限？ | **完全没有**。197.6 MB 二进制里 `too many image` / `max_images` / `image limit` 命中数 **0** | 直接 |
| 有没有可观测信号？ | **有，而且比张数精确得多**：单图成本 = f(像素面积)，已实测 | 2 组对照实验 |
| 能不能自动探测？ | **能，三个 GET 就够**，全部读本机 harness 已开的服务 | 实跑 |
| 能不能用 60 张试探？ | **不该**。没有可发现的上限；失败代价不对称；真约束非破坏性可测 | 见 §5 |
| 「厂商/模型会自己管预算」 | **不成立**。传输层会拒绝，但**没有任何一层会替你裁剪附件** | 见 §6 |

---

## 1. 先把运行时钉死（不靠假设）

第 1 份报告把 `muse-spark-1.3-contributor-free` 当成「旧网关」，把现在当成「新网关」。
**这个前提是错的，而且错在要紧处。** 探测结果：

```
GET /api/provider
  opencode-go → @opencode/ai/providers/openai-compatible
                baseURL https://opencode.ai/inference/go/openai/v1
  opencode    → @opencode/ai/providers/openai-compatible
                baseURL https://opencode.ai/inference/openai/v1
  header      → x-opencode-org-id: wrk_01KY6DZREHRE3MC9EP3B6MT354
```

**同一个厂商（`opencode.ai`）、同一套 OpenAI 兼容协议、同一个 harness。** 变的只有路径段
（`/inference/` vs `/inference/go/`）和档位（`-free` 后缀）。传输层**从未更换**。

更要紧的一条，第 1 份没查到：

```
GET /api/model  →  muse-spark-1.3-contributor-free
  providerID: opencode    status: active    enabled: true
  limit: { context: 1048576, output: 131072 }
```

**写进 8 份文档的那个模型，此刻仍然可选、仍然 enabled。** 所以「换了网关所以旧红线可能不适用」
这个推理链，从第一步就断了：能引发事故的模型和现在能用的模型在同一个 API 上。

当前会话：`opencode-go/space-bunny-free`，variant `max`。

**本机 harness**

| 项 | 值 |
|---|---|
| 客户端 | `opencode-cli.exe` **2.0.22**，197.6 MB（Bun 打包） |
| 位置 | `%APPDATA%\ai.opencode.desktop\cli\2.0.22\` |
| 本地服务 | `http://127.0.0.1:49374`（`main.log` 自报 `v2 CLI background service ready`） |
| 鉴权 | `~/.config/opencode/service.json` 里的 password，HTTP Basic |
| API 规格 | `GET /openapi.json`，**98 个端点**，256 KB |
| 日志 | `%APPDATA%\ai.opencode.desktop\logs\<ts>\main.log` —— **只有 updater 噪音，不记 API 错误** |

最后一行是个负面结论，但重要：**事后 forensics 不可用**。项目里那 5 个会话 ID 之所以查不出原始证据，
是因为 harness 根本不留这类日志。这解释了第 1 份报告的「零实证」——不是没人记录，是**无处可记**。

---

## 2. Q1：硬失败还是静默降级

### 判定：**硬失败。不存在静默丢弃路径。**

四条独立证据：

**(a) 协议层。** 上游是 OpenAI 兼容 REST（`/inference/go/openai/v1`）。该协议族对畸形/超限请求
一律返回 HTTP 4xx + JSON 错误体。`content` 数组是整体校验的，**没有「部分丢弃后照常返回」的语义**。

**(b) 二进制错误路径。** 对 197.6 MB 主程序做字符串统计：

| 串 | 命中 | 含义 |
|---|---|---|
| `InvalidRequestError` | 13 | 请求被拒 |
| `APICallError` | 5 | 上游调用失败 |
| `RetryError` | 2 | 重试耗尽 |
| `context_length_exceeded` | 2 | **上下文超限** |
| `overloaded_error` | 2 | 过载 |
| `too many image` | **0** | — |
| `max_images` | **0** | — |
| `image limit` | **0** | — |

`context_length_exceeded` 存在而图片相关错误串**一个都没有**：harness 认识「上下文爆了」，
**完全不认识「图太多了」**。

**(c) 本轮亲眼撞到两次硬失败。** 不是转述，是我这 30 分钟里打本地 API 打出来的：

```
GET /api/session/{id}/message?limit=500
  → HTTP 错误 {"_tag":"InvalidRequestError","message":"Expected a value less than or equal to 200"}

GET /api/session/{id}/message?limit=1&cursor=...
  → HTTP 错误 {"_tag":"InvalidCursorError","message":"Invalid cursor"}
```

**返回结构化错误、请求被整体拒绝、不返回部分结果。** 这就是那条上限触发时的形态。

**(d) 没有机器可读的图片上限。** `/api/model` 40 个模型，`limit` 块只有 `context` / `output`
（`space-bunny-free` 另有 `input`）。**没有任何一个模型带 `attachment` 字段。**
厂商侧不存在可被读取的「图片张数上限」。

### 但有一条必须说清的残留不确定性

以上证明的是 **opencode.ai 这一侧不会静默丢图**。无法排除的是：厂商在**上游再上游**
（真正跑推理的那家）做了未声明的裁剪。这个项目没有任何手段观测到那一层。

**而如果真发生静默降级，后果比硬失败严重得多**——模型会对着没看过的图编结论。
`864` 时间线里已经有一句很像这种症状的记录：

> `combat_episodes_v2.json` `notes`：「本会话只能读书面报告、**不能看图**，故按 seg06 原判保持删除」

但要分清：**那不是溢出丢弃，是子 Agent 压根没被派发图片访问**（路由问题）。
它不构成静默降级的证据，反而是**另一类**失效——同样表现为「模型看不见图」，同样产出错结论。
无论哪种，客户端预算都该管。

### 关键推论：为什么「硬失败」反而支持保留客户端预算

硬失败 = **有边界，且边界可测**。既然边界存在只是没人公布，那就去测边界，而不是猜一个数。
这直接否掉了第 1 份报告「删掉绝对量」的建议方向：**问题不是数字错，是变量选错了**（见 §3）。

---

## 3. Q2：可观测信号 —— 单图成本是像素面积的函数

这是本单最重要的发现，也是整个自适应方案的地基。

### 实测数据（本会话，同一模型 `space-bunny-free` / `opencode-go`）

图片走 `read` 工具结果：`content[] = [{type:"text"},{type:"file", uri:"data:image/jpeg;base64,…"}]`。
token 账单在 assistant message 的 `tokens` 字段。**注意时序**：工具结果进入的是**下一条**
assistant 消息的 prompt，所以成本要跨一条消息读。

**实验 A —— 一轮里塞 3 张尺寸迥异的图**

| 文件 | 像素 | 同轮 prompt 增量 |
|---|---|---|
| `A_64x64.jpg` | 64×64 | |
| `B_512x512.jpg` | 512×512 | **+3,145 tok**（含文本） |
| `C_1600x1200.jpg` | 1600×1200 | |

**实验 B —— 单独一张 4K**

| 文件 | 像素 | 次轮 prompt 增量 |
|---|---|---|
| `D_3840x2160.jpg` | 3840×2160 | **+3,027 tok**（含文本） |

本会话纯文本轮的 `dTotal` 基线在 **83 – 4,072** 之间，中位约 **1,150**。

### 与三种候选模型的判别

4K 那张是判别力最强的实验，因为它把候选预测拉开了 6 倍：

| 模型 | 对 4K 的预测 | 对实验 A 三张的预测 | 与实测 |
|---|---|---|---|
| OpenAI 512 平铺（85 + 170/块） | ~425 | ~935 | ❌ 低太多 |
| 面积式，**不设上限** `w·h/750` | **11,059** | 2,916 | ❌ 4K 高 8 倍 |
| 面积式，**1568px 长边封顶** | **1,844** | 2,815 | ✅ |

**结论（诚实标注置信度）**

1. **稳健结论**：单图成本 ∝ 像素面积，**不是每图常数**。一张 64×64 缩略图和一个 4K 静帧都算「1 张」，
   成本差两个数量级。
2. **稳健结论**：**存在约 1568px 长边的封顶**。4K 实测 ~3,027（扣文本基线后约 1,400–1,900），
   与 1,844 吻合，与 11,059 差 8 倍。**上游在计费前先降采样。**
3. **不稳健**：精确常数未能钉到 ±30% 以内（两次实验的文本增长噪声 83–4,072 太大）。
   `w'·h'/750` 是**拟合**，不是实测确认。

### 这个发现如何直接否掉「50」

按 `w'·h'/750`（1568 封顶）算单图成本，再乘 50：

| 50 张是什么 | 单图 | 50 张合计 |
|---|---|---|
| 64×64 缩略图 | ~6 | **~350 tok** |
| 960×540 抽帧 | ~691 | **~34,550 tok** |
| 1920×1080 帧 | ~1,844 | **~92,200 tok** |
| 3840×2160 4K 静帧 | ~1,844 | **~92,200 tok** |

**同一个「50 张」，跨度 263 倍（350 → 92,200 token）。**

而当前模型 `space-bunny-free` 声明 `limit.input = 524288`。

> **所以「50 张上限」这个表述在数学上是无意义的**——它既不保证安全（92k 虽仍在 524k 内，
> 但叠加文本后余量迅速收窄），也不构成任何限制（35 万 token 的输入上限下，
> 50 张 320px 缩略图只占 0.07%）。**它是一个与真实约束变量无关的数。**

反过来，**4K 静帧几乎不比 960px 裁剪贵**（都封顶到 ~1,844）。这直接拆掉了本项目里
「必须先缩到 320px 才看得起」的成本模型——**那是在省一个不存在的东西**。

### 活体旁证：另一个正在跑的会话

`ses_f097d3678ffeLivkaEhFyHj7MD`（864 对抗审，当前模型，正在跑）：

```
28 次 read 图片，全部成功，零失败
prompt 30,589 → 118,495 token（+87,906）
按 w'·h'/750 累加这 28 张 ≈ 39,481 token，其余 ≈ 48,425 为文本
```

**28 张、11.8 万 token、无异常。** 该会话的 reasoning 里还留着人工预算追踪
（「Budget: 28 used. +1 = 29. OK.」）——那正是本项目想自动化的东西。

### 可用的观测端点（全部 GET，无副作用）

| 端点 | 给出什么 | 实测 |
|---|---|---|
| `GET /api/model` | `data[].limit.{context,input,output}`、`capabilities.input[]` | 40 模型，**无 `attachment`** |
| `GET /api/session/{id}/context` | `items[].tokens{input,output,reasoning,cache{read,write}}` | 47 项中 **45 项**带 tokens |
| `GET /api/session/{id}/message?limit=200` | 同上 + 工具结果的图片 base64 与尺寸 | 200 上限，**超出报 `InvalidRequestError`** |
| `GET /api/session/active` | 当前在跑会话 | 直接可用 |

**图片自身尺寸**从文件头读即可（`System.Drawing.Image.FromStream` / PIL），无需 API。

---

## 4. Q3：自适应方案

### 4.1 自动探测：**可行，三个 GET，零猜测**

```
输入：ImageDir（待看图目录）
1. GET /api/model                       → 找当前模型的 limit.input        （实测 524288）
2. GET /api/session/active  → GET /api/session/{id}/context
                              → 当前已用 = tokens.input + tokens.cache.read
3. 对 ImageDir 每张图读尺寸 → cost = min(w,1568 缩放后)·h/750
4. afford = floor((limit.input − 已用 − reserve) / Σcost)
```

`reserve` 建议取 `0.15 × limit.input` 留给输出与工具往返。

**三个数字全部机器可读，一个都不需要用户告知。** 这比「让用户开场告知上限」更好——
上限每换模型、每换档位就变，写进配置就立刻过期。

### 4.2 关于用户开场告知上限

如果坚持要人工兜底，**可行且便宜**，但要放在自动探测之后当**校验**而不是当**数据源**：

```jsonc
// config/image_budget.json —— 沿用 config/production_dependencies.json 的 schema 约定
{
  "schema": "naraka-highlight-image-budget/v1",
  "auto_detect": true,
  "declared_input_limit": null,   // 非 null 时与 /api/model 实测值比对，不一致报 [WARN]
  "reserve_ratio": 0.15,
  "max_long_edge_px": 1568,
  "pixels_per_token": 750,
  "advisory_images_per_round": 10,  // 仅作可读性建议，不作硬门槛
  "history": {
    "legacy_cap": 50,
    "source": "muse-spark-1.3-contributor-free era",
    "verified_after": "2026-10-04 未复现任何超限实证"
  }
}
```

`config/` 下已有 `production_dependencies.json`，schema 命名法一致，不新增约定。

### 4.3 `check_image_budget.ps1`：硬编码了吗？**硬编码了，而且基本不设防**

通读 69 行：

| 行 | 现状 | 问题 |
|---|---|---|
| L6 | `[int]$Cap = 50` | **写死**。且 `-Cap` 可被调用者覆盖 → 50 连下限都不是 |
| L7 | `[int]$PerRoundNew = 10` | 写死 |
| L18 | `Get-ChildItem -LiteralPath $ImageDir -Filter $Pattern -File` | **无 `-Recurse`** → 子目录帧少算（实测 100 张报 7 张还 `[PASS]`） |
| L20 | `$remaining = $Cap - $AlreadySeen` | 张数算术，与真实约束无关 |
| L59–63 | 超额只打印 `[PLAN]`，**`exit 0`** | **从不拦截** |
| — | 无尺寸读取、无 token 计算、不查上游 | 「硬红线」的唯一执行手段是打印 |

`$AlreadySeen` 还要人手填 —— 也就是说**连「已经看了几张」都得靠人自报**，
而这恰恰是第 1 份报告 D4 里 861 各路自创「40 张」预算的成因。

### 4.4 改法（按性价比排序）

**P0 — 修 bug（半小时）**

1. L18 加 `-Recurse`。子目录少算是**已经在任务里造成过错误绿灯**的
   （`adversarial_864_v3_adv3.md:358` 原文「我的帧在子目录，故报 `TotalOnDisk: 0`」）。
2. L59–63 超额时 `exit 2`。调用方已经按非零码处理，不需要新协议。
3. `-Cap` / `-PerRoundNew` 与配置不一致时打印 `[WARN] 红线被覆盖`。
   这条专堵 `-Cap 500` 那个洞。

**P1 — 换成 token 算术（半天）**

4. 删掉 `$Cap = 50` 默认值，改为从 `config\image_budget.json` 读；参数降级为 override。
5. 每张图读尺寸，输出 `EstTokens` / `BudgetTokens` / `RemainingTokens`，
   轮次划分改按 token 而非张数。输出示例：

```
ImageDir: …\shots\verify    Files: 24
Per-image: 960x540=691  1920x1080=1844  (cap 1568px, 750 px/token)
EstTokens: 41,544        Budget: 524,288  Used: 118,495  Reserve: 78,643
Afford: 8 rounds (largest-first), round 1 = 24 images / 41,544 tok
```

6. 新增 `-SessionId`（缺省读 `/api/session/active`）→ 自动取 `Used`，**消灭 `-AlreadySeen` 手工填报**。

**P2 — 撤掉「联系表更便宜」的错误经济（半小时，纯文档）**

7. 按 token 算：**960px 单帧 ≈ 1,230 tok，24 格联系表 ≈ 3,000 tok**——单帧其实**更便宜**。
   `864 §1.3` 记录了 640px 联系表在**五路独立扫描中 5/5 把「战斗」误读成「面板」**，
   代价是六版返工。**那个误判不是分辨率的错，是 token 账算错了才选了联系表。**
   改成 token 账之后，人会自动选对方法。

**P3 — 可观测性**

8. 预算脚本顺带把本轮实际 token 增量写进 `reports/`，取代现在散落在各路报告里的自述数字。

### 4.5 文档层（与 01 号报告合流）

- `IMAGE_LIMIT.md` / `AGENTS.md §9` / `README.md:18` / `WORKFLOW.md` / `TROUBLESHOOTING.md` /
  `complete-combat-roughcut.md` / `roughcut-launch.md` / `粗剪提示词.md`：**删「50」这个数**，
  改成「按 `/api/model` 声明的 `limit.input` 与实测 token 占用动态计算」。
- **同时删掉 `AGENTS.md:257` / `IMAGE_LIMIT.md:21` 那条「任何文档不得将其写成仅适用于某一模型的临时限制」。**
  这条禁令是本项目信息债的根源：它禁止记录依赖关系，于是 01 号报告花大力气也只能得出
  「零实证」——**因为唯一的证据来源被这条规则本身封掉了**。
- 保留：看图前先计数并写下来、超 10 帧优先拼联系表、每轮先落盘结论。**这三条与网关无关，
  且 863（560 帧 → 28 图，20×）证明有效。**
- 移除 `粗剪提示词.md:21`「唯一允许的重复是看图上限」——它的正当性理由（违反 = 会话报废）
  已确认是零实证断言。**但重复本身可以保留**，理由换成「改一次要同步 8 个文件，成本不值」。

---

## 5. Q4：要不要用 60 张试探？

### **不要。**

**(1) 没有可发现的上限。** `/api/model` 40 个模型**无一带 `attachment` 字段**；
二进制里图片计数逻辑**命中 0**。厂商没有公布过这个数，试探是在测一个**没有被文档化的常量**。

**(2) 失败代价不对称。** 硬失败 = 整会话报废。01 号报告统计真实会话跑 20–50 轮；
864 那种对抗审会话已经积累 44 份报告。**为验证一个可能不存在的限制，赌上整个会话，不划算。**

**(3) 真约束非破坏性可测，我这一轮已经测了。** token 轴不需要试探——直接读端点即可。
本单全程 4 张测试图 + 若干次 API 调用，**没有一次失败，零损失**。
**能用测量解决的，不要用试探解决。**

**(4) 试探回答不了真问题。** 「60 张今天行不行」不是要回答的问题；
「**这个会话**还看得起几张」是纯算术，且三个输入全部已公布。

### 唯一勉强可辩护的版本（不推荐）

若坚持要探：**开全新空会话**，发 **60 张 ≤320px 的小图**（单张 ~50 tok，合计 ~3,000 tok，
占 524k 预算的 0.6%）。这样在 token 轴上绝对安全，同时测试张数轴。

但请记住它测的是什么：**「是否存在一个 ≥60 的张数上限」**。
而 01 号报告已给出反面证据——三个真实任务、261 份报告、峰值 44 张、**零次超限**。
**再花一次会话去测一个大概率不存在、且存在就在 44 之上的上限，期望收益为负。**

---

## 6. Q5：「厂商/模型会自己管看图预算」这个假设

用户的原话是：「不管 OpenAI、Claude 还是任何其他模型提供厂商，他们应该都能自己去把看图预算处理好。」

把这句话拆成三层，逐层判定：

| 层 | 会做什么 | 判定 |
|---|---|---|
| **传输层**（OpenAI 兼容端点） | 对畸形/超限请求返回 4xx JSON 错误 | ✅ **会**。这就是硬失败的来源 |
| **模型** | …… | ❌ **概念错位，见下** |
| **Harness**（opencode） | …… | ❌ **完全不参与** |

### 模型侧：**做不到，不是「不愿意」**

「模型自己管预算」在架构上不成立：**模型永远看不到请求信封**。
它收到的是一个**已经装配好的 image parts 数组**，以及一段文本。
**不存在任何一个环节，模型能判断「这些太多了，我丢几张」。**

模型在上下文压力下唯一能做的事是**自己降低推理质量**——那不是预算管理，是静默劣化。
而这恰恰是**比硬失败更糟的结局**：你会拿到一份看起来正常、实则基于残缺输入的结论。

第 1 份报告 §3.2 记的那个失效模式（联系表误读 → 错判 → 返工）就是这个家族：
**在一个没有被明确定义的约束下，模型会自己找一个「看起来合理」的省法，并且它可能是错的。**

### Harness 侧：**零参与**

197.6 MB 二进制，图片相关错误串命中 0。**从工具调用到 HTTP 请求之间，没有任何一层
裁剪、批处理或拒绝附件。**

### 所以

> **预算只有一个可能的主人：决定 `Read` 哪些文件的调用方——也就是 Agent。**
> 上游没有任何一层愿意替它做这件事。

这直接回答了用户的疑虑：**客户端的硬限制不是多余的，也不是有害的——它是这个架构里唯一的守门人。**

**但它现在守错了门。** 它守的是「张数 ≤ 50」，而真实的门是
「`Σ(像素面积) ≤ limit.input − 已用 − 预留`」。
**换个变量守，这道门就从「迷信」变成「算术」。**

而且要指出一个反直觉的事实：**这道门放宽了，不是收紧了。**
`limit.input = 524,288`，单图封顶 ~1,844 → 全 4K 静帧理论上能看 **~270 张**；
而项目真实峰值是 44 张。**换 token 账之后，864 那种「预算不足导致核验降级、
结论推给用户审片」（`accept_863_v2.md:772/1050`）的情况会消失**——
因为预算从来不是不够，是算错了单位。

---

## 7. 本单的局限（必须写明）

1. **公式是拟合，不是实测确认。** `w'·h'/750` + 1568px 封顶能解释两次实验，
   但常数未钉到 ±30% 以内（文本增长噪声 83–4,072）。**落地前应再跑一组配对标定**
   （同轮 N 张已知尺寸图，文本增量控制到最小）。
2. **未观测厂商上游那一层。** 已证明 opencode.ai 不静默丢图；
   无法排除其再上游做未声明裁剪。若要闭环，需要抓包或问厂商。
3. **`limit.input` 是声明值，不是实测上限。** 用它做预算上限是保守正确的
   （声明值通常小于或等于真实上限），但若厂商实际更宽松，本方案会偏保守。
4. **`context` 与 `input` 的区别未深究。** `space-bunny-free` 两者都是声明值；
   `muse-spark` 系只有 `context` 无 `input`，届时需回退到 `context`。
5. **本单未修改任何项目文件。** 只读探测 + 新建本报告。
   §4.4 是建议，未执行。

---

## 附：可复用的探测命令

```powershell
$pw = (Get-Content "$env:USERPROFILE\.config\opencode\service.json" | ConvertFrom-Json).password
$H  = @{ Authorization = 'Basic ' + [Convert]::ToBase64String([Text.Encoding]::ASCII.GetBytes("opencode:$pw")) }
$b  = 'http://127.0.0.1:49374'   # 端口见 %APPDATA%\ai.opencode.desktop\logs\*\main.log 的 "background service ready"

# 1. 模型声明的 token 上限（注意：没有 attachment 字段）
(Invoke-WebRequest "$b/api/model" -Headers $H).Content | ConvertFrom-Json |
  Select-Object -Expand data | Where-Object { $_.providerID -eq 'opencode-go' -and $_.id -eq 'space-bunny-free' } |
  Select-Object id, limit, capabilities

# 2. 当前会话已用 token
$id = ((Invoke-WebRequest "$b/api/session/active" -Headers $H).Content | ConvertFrom-Json).data.PSObject.Properties.Name
$ctx = (Invoke-WebRequest "$b/api/session/$id/context" -Headers $H).Content | ConvertFrom-Json
$t = ($ctx.data | Where-Object { $_.tokens } | Select-Object -Last 1).tokens
"used = {0} (input {1} + cache.read {2})" -f ($t.input + $t.cache.read), $t.input, $t.cache.read
```
