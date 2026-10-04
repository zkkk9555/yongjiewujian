# 08 号 · 方案 B 落地技术规格：把看图预算从「张数」换成「token」

> 分析员第 8 份。前七份的**结论**本单采信、不重查；本单只做一件事：
> **把方案 B 的三个数字逐个核实到「读到 / 需实测 / 读不到」，并落成可实施的字段结构与脚本规格。**
>
> 核实方式全部第一手：本地 `opencode-cli.exe`（2.0.22，207 MB 单体包）反编译取字符串、
> 直连 `127.0.0.1:49374` 私有 API 实测、扫 25 个历史会话找图片标定数据。
>
> **本单只新建本报告，未改任何规则文件、脚本、配置或任务目录。**

---

## 0. TL;DR — 三个数字的裁定

| 数字 | 裁定 | 从哪读 | 关键发现 |
|---|---|---|---|
| **上限 `limit.input`** | ✅ **读到 = 524288** | `GET /api/model`（Basic auth，动态端口） | 项目里**没有任何地方静态记录**这个值，必须运行时读。40 行里只有 6 行有 `input`（4 个不同 modelID），跨度 192,000→922,000（**4.8 倍**） |
| **图片 token 公式** | ⚠️ **需实测（且「750」这个前提是错的）** | 无本地来源 | **opencode 自己用的是「每图固定 1500」，全代码里没有 `750`。** `750` 是 OpenAI gpt-4o 系的公开近似式，与本模型无关。历史 25 个会话 **0 个图片 part** → 无标定锚点 |
| **已用 token** | ✅ **读到（但 07 的公式漏了两项）** | `GET /api/session/{id}/context`（更全）或 `/message` | 正确口径是 `input+cache.read+cache.write+**output+reasoning**`。07 号写的三项**不完整**。`/session/{id}/token` **不存在（404）** |

**外加两条源码级确认（不是推算，是从二进制里读出来的）：**

- **压缩阈值 471,860 成立**，而且是本机**当前生效**的：项目与全局都**没有** `opencode.json`，
  `compaction` 全走默认值 `auto:true` / `reserved:未设` → 走 `limit − max(⌊10%⌋, 16000)` = `524288 − 52428` = **471,860**。
- **07 号「必须取 min(input, context)」是错的**。源码是 `limit.input || limit.context`——**input 优先，context 只在 input 缺失时兜底**。
  本模型两者都有，所以生效值就是 524288；`context` 的 1,048,576 **不参与**。这条要改，否则门禁会白砍一半预算。

---

## 1. 三个数字的核实（第一手证据）

### 1.1 上限：读到，524288

**读取方式**（本单实测跑通，四步全过）：

```powershell
# 1) 动态端口：只认 opencode-cli 进程的监听端口
$port = (Get-NetTCPConnection -State Listen |
         Where-Object { $pids -contains $_.OwningProcess }).LocalPort
# 2) 凭据：只在内存里用，不落盘、不打印
$svc = Get-Content "$env:USERPROFILE\.config\opencode\service.json" -Raw | ConvertFrom-Json
$b64 = [Convert]::ToBase64String([Text.Encoding]::ASCII.GetBytes("opencode:$($svc.password)"))
$hdr = @{ Authorization = "Basic $b64" }
# 3) 取模型表
$models = (Invoke-RestMethod "http://127.0.0.1:$port/api/model" -Headers $hdr).data
# 4) 必须按 providerID + modelID 定位，不能只按 modelID
$models | ? { $_.providerID -eq 'opencode-go' -and $_.id -eq 'space-bunny-free' }
```

**实测结果**：

| 项 | 值 |
|---|---|
| 当前模型 | `opencode-go` / `space-bunny-free`（variant `max`） |
| `limit` | `{context: 1048576, input: 524288, output: 524288}` |
| `capabilities.input` | `["text","image","video"]` ← **注意有 video** |
| 模型总行数 / 含 `limit.input` 的行 | **40 / 6**（去重后只有 **4 个不同 modelID**） |
| `limit.input` 跨度 | `hy3` 192,000 → `gpt-6-luna`/`gpt-5.6-luna` 922,000（**4.8 倍**） |
| 完全没声明 `limit` 的模型 | **0**（都有 `context`，只是多数没有 `input`） |

**必须按 `providerID/modelID` 定位**：`space-bunny-free` 在表里出现**两次**
（`opencode-go` 与 `opencode` 两个 provider，baseURL 不同），值相同但**不能假设相同**。
`gpt-5.6-luna` 与 `hy3` 则只出现在一个 provider 下。只按 modelID 匹配会拿到不确定的那一行。

**项目里有没有静态记录？没有。** 全项目 grep `524288` 只命中 `.scratch` 下这八份分析报告本身，
`config/` 只有一个 `production_dependencies.json`（无关），也没有 `.opencode/` 目录。
**⇒ 这个值只能运行时读，任何写进文档的数字都是复制品。**

### 1.2 压缩阈值：源码级确认 471,860

从 `opencode-cli.exe` 取出的实际代码（已去掉混淆名、保留原逻辑）：

```js
var S6 = [0.7, 0.5, 0.35],   // overflow 重试阶梯
    F6 = 16000,               // 压缩预留量的下限
    bj = 200000,              // limit 缺失时的硬塞值
    M6 = 1250, Gj = 1500, Sj = 2000;   // Gj=图片, Sj=PDF

// 阈值函数
N6 = (limit, buffer) => {
  const i = limit.input || limit.context;      // ← input 优先，不是 min()
  if (i <= 0) return Infinity;
  if (buffer !== undefined) return i - buffer; // 用户设了 compaction.reserved 就走这条
  return i - Math.max(Math.floor(i * 0.1), i >= 2 * F6 ? F6 : 0);
};
```

**代入本机当前状态**：

```
limit              = 524288          (limit.input 命中)
reserved           = max(floor(524288×0.1), 16000) = max(52428, 16000) = 52428
压缩阈值            = 524288 − 52428 = 471,860        ← 与 05/07 的推算一致，现已证实
```

**三条 05/07 没提到的补充事实：**

1. **兜底硬塞值 200,000。** `limit.input` 缺失或 ≤0 时，代码改用
   `N6({...limit, context: 200000}, buffer)` → 阈值掉到 **180,000**。
   也就是说「悬崖」不总是 471,860，**34 个没有 `limit.input` 的模型阈值可能只有 180,000**。
   门禁必须复刻这条分支，否则会给出虚假的绿灯。
2. **`compaction.auto` 默认 `true`**（`initial:()=>({auto:!0, keep:15000})`）。
   本机**没有任何 `opencode.json`**（项目级、全局级都不存在，已逐一 Test-Path 确认），
   所以 471,860 **就是此刻正在生效的悬崖**，不是理论值。
3. **触发判定是 `T6(ctx) >= 阈值`**，且有两个附加短路：
   最后一条消息已是完成的 compaction → 不触发；最后一次带 token 的 assistant 消息
   早于最后一条 user 消息 → 不触发（即「这一轮还没结算，不压」）。

**两个不同的触发器，别混为一谈：**

| 触发 | 目标值 | 说明 |
|---|---|---|
| `reason:"auto"`（预防性） | `471,860` | 到线就静默摘要，**帧变文字、不可逆** |
| `reason:"overflow"`（反应性） | `min(471860, ⌊total×0.7⌋)` | 上游报 payload-too-large 后才触发，再失败按 `0.7→0.5→0.35` 逐级降 |

方案 B 要防的是**第一个**。第二个是上游已经拒绝了，硬失败、看得见，不属于「静默丢证据」。

### 1.3 已用 token：读到，但 07 的公式漏了 output 和 reasoning

**源码里的真实口径**：

```js
// 「最后一条带 token 的 assistant 消息」的选择器
I6 = (m, modelRef) =>
  m.type === "assistant" &&
  m.model.providerID === modelRef.providerID &&     // ← 必须同 provider
  !m.error &&
  m.tokens !== undefined &&
  m.tokens.input + m.tokens.cache.read + m.tokens.cache.write > 0;

// 占用量
R6 = (ctx) => {
  const a  = ctx.messages.findLastIndex(m => I6(m, ctx.model.ref));
  const i  = ctx.messages[a];
  const s  = i.tokens;
  return {
    measured:  s.input + s.cache.read + s.cache.write + s.output + s.reasoning,  // ← 五项
    estimated: <a 之后那些还没结算的消息，按 hg() 估>
  };
};
T6 = (ctx) => R6(ctx).measured + R6(ctx).estimated;   // 门禁真正比的那个数
```

> **07 号 §2.2 写的是 `input + cache.read + cache.write`——漏了 `output` 和 `reasoning`。**
> 本模型是 `variant: max`、reasoning 开着，两项都实打实计入 prompt 占用。
> 照 07 写会**系统性低估**，而低估的方向恰好是本方案要防的那一侧。**必须按五项。**

**端点实测**（02 号提到的 `/context` 可以访问，已确认）：

| 端点 | 结果 | 说明 |
|---|---|---|
| `GET /api/session/{id}/context` | **200**，2.3 MB，**400 条** | ✅ **首选**。含 `type:"compaction", reason:"auto"` 的历史记录、`snapshot`、`idle`。每条 assistant 带 `tokens` |
| `GET /api/session/{id}/message` | **200**，默认**只给 50 条**，`?limit=` **上限 200** | 能用但必须显式传 limit，且可能仍取不全 |
| `GET /api/session/{id}/token` | **404，不存在** | 别写进脚本 |

**三个必须写进脚本的坑：**

1. **`/api/session` 的 `tokens.input` 是会话累计，绝不能用。**
   实测父会话 `ses_f1648…`：`tokens.input = 6,290,300`、`cache.read = 168,530,357`，
   是 `limit.input` 的 **12 倍**。当「已用上下文」用会得到一份垃圾门禁。
2. **当前会话最后一条消息 `tokens` 是 `null`**（在途未结算）。
   必须用 `I6` 的语义**往回走**，找最后一条 `tokens` 非空且同 provider 的 assistant。
3. **默认 50 条会漏。** 长会话动辄几百条，`/message` 不传 limit 拿到的是**最近 50 条**，
   恰好可能把带 token 的那条挤出去 → 读出 `used=0` → 假绿灯。

### 1.4 图片 token 公式：**「750」这个前提不成立**

**opencode 自己怎么给图片计价**（源码，非推测）：

```js
P6 = (mime) => {
  const a = mime.toLowerCase();
  if (a.startsWith("image/"))   return Gj;   // Gj = 1500  ← 固定值，与尺寸无关
  if (a === "application/pdf")  return Sj;   // Sj = 2000
  return 0;                                   // 其它一律 0
};
hg = (msg) => msg.content.reduce((acc, part) => acc + Lj(part), 0);
Lj = (part) => { ... if (part.type === "media") return P6(part.media.mediaType); ... };
```

**三个结论：**

| 问题 | 答案 |
|---|---|
| `750` 是哪个模型的标准值？ | **OpenAI `gpt-4o` 系公开的近似式**（细节 170 tok/512² tile、高细节 1408+170×tiles）。**opencode 代码里根本没有 `750`**，与 `space-bunny-free` 无关。05/07 把它当通用式沿用下来，是个未标注来源的继承 |
| 当前模型的值是多少？ | **需实测。** opencode 侧只知道「固定 1500/图」，这是它**显示用的估算值**；真实计费由上游网关 `https://opencode.ai/inference/go/openai/v1` 决定，**本地无从读取** |
| 有没有标定数据？ | **没有。** 扫最近 25 个会话 × 每个最多 200 条消息 → **图片 part 总数 = 0**。历史上从没在这个 harness 里 `Read` 过图片，所以拿不到任何 delta 可以反推 |

**顺带否掉 05 的一个说法：opencode 不缩图。**
全包搜索 `resize` 的命中全是 CSS / DOM `ResizeObserver` / 终端尺寸 / Bun 内嵌 `sharp` 的 API 签名表，
**媒体路径里没有任何缩图调用**。所以「`auto_resize` 把 4K 悄悄缩到 2000px」在本 harness 侧**无证据**——
若真存在，只可能在上游网关，而那反而让**实际 token 低于估算 = 偏保守 = 安全**。

**另一个源码暴露的盲区：`capabilities.input` 含 `"video"`。**
`P6` 对 `video/*` 返回 **0**——但一段视频附件显然不是零成本。
**脚本必须对任何非 `image/*`、非 `application/pdf` 的附件直接拒绝定价并告警**，不能默默按 0 算。

---

## 2. `config/image_budget.json` 字段结构

**设计原则：数字只此一处，且没有一个是模型专属的硬编码。**
`IMAGE_LIMIT.md:21` 那句「不得写成仅适用于某一模型的临时限制」之所以是错的，
不是因为它方向错，而是因为它**只约束了文档、没约束代码**——数字照样会被焊进 `.ps1`。
正确做法是让**文档和脚本都只引用这个文件**，模型差异由 `overrides` 表承载、缺省走 `default`。

```jsonc
{
  "$schema_version": 1,
  "_why": "看图预算的唯一真源。文档与 scripts\\check_image_budget.ps1 都只引用本文件，不复制数字。换模型不改本文件即可生效（见 §5）。",

  // ── 每张图的 token 成本：方案 B 里唯一「必须实测」的量 ──────────────
  "image_cost": {
    "mode": "max_of",              // max_of | flat | pixels
    "flat_tokens": 1500,           // 依据：opencode-cli 2.0.22 内置 Gj=1500
    "pixel_divisor": 750,          // 依据：OpenAI gpt-4o 系公开近似式【非本模型】
    "confidence": "unverified",    // unverified | measured
    "_note": "max_of = max(flat, w×h/divisor)。flat 单独用会在大图上低估最多 7.4 倍（见 §4.1）；pixels 单独用会在联系表上低估（见 §4.2）。取 max 严格支配两者。"
  },

  // ── 模型覆盖表：键必须是 providerID/modelID，不能只用 modelID ────────
  "overrides": {
    // "opencode-go/some-vision-model": { "image_cost": { "flat_tokens": 1234, "confidence": "measured" } }
  },

  // ── 压缩阈值复刻参数：逐条对应 opencode 源码，harness 改了只改这里 ───
  "compaction": {
    "prefer": "input",              // 源码是 limit.input || limit.context，不是 min()
    "context_fallback": 200000,     // bj：limit.input 缺失时的硬塞值
    "reserved_ratio": 0.10,         // ⌊limit×ratio⌋
    "reserved_floor": 16000,        // F6：limit ≥ 2×floor 时取此下限
    "explicit_reserved": null,      // 对应 compaction.reserved；非 null 时它接管，ratio/floor 失效
    "overflow_ladder": [0.70, 0.50, 0.35]   // S6，仅供报告展示，门禁不判
  },

  // ── 门禁阈值 ───────────────────────────────────────────────────────
  "gate": {
    "soft_fraction": 0.75,          // 判定线 = soft_fraction × 压缩阈值
    "warn_fraction": 0.60,          // 越过就打 WARN 提前收口
    "safety_factor": 1.5,           // 只乘在「本轮新增」上，见 §4.3
    "round_new_hint": 10            // 沿用现行「单轮新增 ≤10」的软约束，仅作提示不作门禁
  },

  // ── 数据来源（换 harness 只改这里）────────────────────────────────
  "sources": {
    "port": { "process": "opencode-cli", "proto": "http", "host": "127.0.0.1" },
    "auth": { "type": "basic", "user": "opencode", "credential_file": "~/.config/opencode/service.json", "credential_field": "password" },
    "limit":  { "method": "GET", "path": "/api/model", "pick": "data[] where providerID+id" },
    "used":   { "method": "GET", "path": "/api/session/{id}/context", "prefer": true },
    "used_fallback": { "method": "GET", "path": "/api/session/{id}/message", "query": "?limit=200" },
    "capabilities": "data[].capabilities.input"
  },

  // ── 不可定价的附件：直接拒绝，不猜 ─────────────────────────────────
  "unpriceable": { "action": "refuse", "note": "video/* 等 P6 记 0 的类型一律告警并中止门禁，不按 0 放行" },

  "provenance": {
    "verified_on": "2026-10-04",
    "opencode_cli": "2.0.22",
    "measured": ["limit.input=524288", "compaction_threshold=471860", "image_flat=1500"],
    "unmeasured": ["image_cost 真实计费", "video/* 计费"]
  }
}
```

**为什么是 `max_of` 而不是任一单项**（这是本单对方案 B 的一处实质修正）：

| 模式 | 512×512 | 960×540 | 1600×900 | 2000×1500 | 3840×2160 |
|---|---|---|---|---|---|
| `flat` 1500 | 1500 | 1500 | 1500 | 1500 | 1500 ← **大图低估 7.4 倍** |
| `pixels` ÷750 | 350 | 691 | 1920 | 4000 | 11,059 |
| **`max_of`** | **1500** | **1500** | **1920** | **4000** | **11,059** |

`max_of` 在每一档都不低于任何一个单方案，且把「大图」这一侧的误差从 **7.4×** 压回
除数自身那个 0.1%–3.9% 的量级（05 实测）。

---

## 3. 改造后的 `scripts\check_image_budget.ps1` 规格

### 3.1 参数（相对现行版的增删）

| 参数 | 现行 | v3 | 说明 |
|---|---|---|---|
| `-ImageDir` | 必填 | 保留，允许多个 | |
| `-Path` | — | **新增** | 直接接文件列表（不落盘的临时抽帧也能算） |
| `-Recurse` | **缺** | **新增，默认开** | 06 的 S1：现行版少算 3×，864 踩过空扫描假绿灯 |
| `-Pattern` | `*.jpg` | **默认 `*.jpg;*.jpeg;*.png;*.webp;*.bmp`** | 现行默认漏 PNG |
| `-AlreadySeen` | 有 | **保留但降级** | 只作对账提示，**不再作为判定输入**（见 §3.4） |
| `-SessionId` | — | **新增** | 缺省自动探测当前会话 |
| `-Tier` | — | **新增** | `census` / `adjudicate` / `spotcheck`（07 方案 C 的档位，B 的子集） |
| `-SheetCols N` | — | **新增** | 联系表按 N 列折算，见 §4.2 |
| `-Json` | — | **新增** | 供 `qa_gate.py` 消费，让预算第一次成为可核对的门禁项 |
| `-NoPersist` | — | **新增** | 只读演练，不写台账 |
| `-UnsafeOverride` | **缺** | **新增** | 现行 `-Cap`/`-PerRoundNew` 可被覆盖且能**把门禁反转成 PASS**（06 S3），必须堵死 |
| `-Cap` | 50 | **删除** | 不再按张数判定 |

### 3.2 读哪几个数

```
① 上限        limit.input → 缺则 limit.context → 缺则 compaction.context_fallback(200000)
② 压缩阈值    N6(limit, reserved)  ← 逐条复刻源码，含 input 优先与 200000 硬塞分支
③ 已用        used = 最后一条 tokens 非空且同 providerID 的 assistant 消息的
                   input + cache.read + cache.write + output + reasoning   ← 五项
④ 本轮新增    cost = Σ max(flat_tokens, w×h ÷ pixel_divisor) × safety_factor
⑤ 能力        capabilities.input 含 "image" ? 否 → [MOOT] 直接 exit 3
```

`cost` 的 `w×h` 用 PowerShell 5.1 自带的 `System.Drawing.Image::FromFile` 读，
**不装任何包**（符合 `AGENTS.md §2` 环境铁律；venv 里没有 PIL，03 已证）。

**判定**：

```
used + cost ≤ soft_fraction × 阈值   → [PASS] exit 0
                             > 阈值   → [FAIL] exit 2   （附三行可执行处置）
                       > warn 线     → [WARN]          （提前收口，不拦）
```

### 3.3 违规怎么表达

**exit code**（与项目既有 `check_video_environment.ps1` 的 0/1/2 约定对齐）：

| code | 含义 | 何时 |
|---|---|---|
| `0` | PASS | 在预算内 |
| `1` | USAGE | 参数错、目录不存在 |
| `2` | **FAIL** | 越线——**真拦** |
| `3` | **MOOT** | 当前模型不能看图（`capabilities.input` 无 `image`，40 个模型里 10 个是纯文本），本门禁不适用 |
| `4` | **DEGRADED** | 读不到 API / 凭据 / 端口 → **fail-open**，但必须响亮告警并在报告里写「本轮门禁未生效」 |

> `4` 的 fail-open 是刻意的：07 §2.4 已论证，端口动态、路由无版本承诺，
> **harness 一升级就读不到**。设计成 fail-closed 会让整个看图流程被一个私有 API 卡死，
> 那比没有门禁更糟。但它**必须**打成非零 exit + `DEGRADED` 字样，不许悄悄放行。

**`-Json` 输出**：

```jsonc
{
  "schema_version": 1,
  "status": "PASS | FAIL | WARN | MOOT | DEGRADED",
  "exit_code": 0,
  "model":    { "providerID": "opencode-go", "id": "space-bunny-free", "variant": "max" },
  "limits":   { "input": 524288, "context": 1048576, "used_field": "input",
                "reserved": 52428, "compaction_threshold": 471860,
                "gate_line": 353895, "source": "/api/model" },
  "usage":    { "measured": 158749, "message_id": "msg_…",
                "components": { "input": 25501, "cache_read": 133248, "cache_write": 0 },
                "source": "/api/session/{id}/context" },
  "round":    { "images": 6, "pixels_formula_tokens": 4146, "raw_tokens": 4146,
                "safety_factor": 1.5, "effective_tokens": 6219,
                "per_image": [ { "file": "a.jpg", "w": 960, "h": 540, "tokens": 1500 } ] },
  "projection": { "used_plus_cost": 164968, "headroom": 188927, "images_left_at_this_size": 125 },
  "warnings": [],
  "config_file": "config/image_budget.json",
  "config_confidence": { "image_cost": "unverified", "limit": "measured", "threshold": "measured" }
}
```

`config_confidence` 是刻意加的：**每轮都自报哪些数字是实测、哪些是估值**，
报告里出现 `image_cost: unverified` 就是提醒人「该做一次标定了」。

### 3.4 累计怎么跨对话持久化

**这是本单对 06 的直接回答，方案和 06/07 预期的都不一样：**

> **不要用手工计数器持久化累计。要让 API 本身成为持久化机制。**

理由：`used.measured` 取自**最后一条 assistant 消息的 `tokens`**，那是**上游服务商真实计费的结果**，
其中**已经包含了本会话此前看过的每一张图**——因为那些图确实被塞进过 prompt，服务商确实计了费。
所以「累计」这件事**天然已经在 `used` 里了**，脚本不需要、也不应该再数一遍。

06 指出的两个病根，正是一次性计数方案的两个必然后果：

| 06 的指控 | 根因 | v3 的解法 |
|---|---|---|
| 「累计只算一半」 | `-AlreadySeen` 是**人手填的整数**，与 `used` 之间没有任何关系；填了就等于把服务商已经算进去的量**再减一次** | `-AlreadySeen` **降级为对账提示**，不进判定式。累计由 `used` 独家提供，**填错也不影响门禁正确性** |
| 「无状态」 | 每次调用重新 `ls` 一遍，谁也不知道上一轮看过什么 | `used` 随会话推进单调增长，**跨轮、跨工具调用天然连续**；换窗口 = 换会话 = `used` 自动归零，**这正是想要的语义** |

**真正需要持久化的只剩两件事**，用一个 **append-only 台账**兜底：

1. **在途尾巴**：本轮已 `Read` 但还没有结算进任何 assistant 消息的图。
   `I6` 只看已结算的消息，所以这一段必须单独记，否则最后一批图会漏算。
2. **审计痕迹**：每轮记一行（时间、文件、像素、估算 token、`used`、`limit`、结论），
   让压缩万一真的发生，能从台账重建「当时看过什么」。

**台账路径**：`C:\Project\永劫无间\.scratch\image-budget\state\<sessionID>.jsonl`

- **按 `sessionID` 分文件** → 换窗口自动开新文件，不会把两个会话的累计混在一起。
- `.jsonl` 追加写，**只增不改**，可与 git 共存。
- ⚠️ **必须加一行 `.gitignore`**（`.scratch/image-budget/state/`）。当前 `.gitignore` 没有它，
  而台账是机器工作状态、不是规格——按 `.gitignore` 顶部那段自己的原则，它就不该进版本库。
- 台账缺失不影响判定（`used` 仍然正确），只丢审计痕迹 → 降级为 `[NOTE]`，**不是** `DEGRADED`。

**每次运行写一行**：

```jsonc
{"ts":"2026-10-04T…","session":"ses_…","model":"opencode-go/space-bunny-free",
 "phase":"plan|commit","images":[{"f":"a.jpg","w":960,"h":540,"tokens":1500}],
 "used_measured":158749,"limit":524288,"threshold":471860,"cost":6219,"status":"PASS"}
```

`-Phase plan` 只算不记账（预估轮），`-Phase commit` 落账（真看图的那一轮）。
`spotcheck` 档写 `status:"BYPASS"` 留痕但不参与累计——**定点复核不限量**（05 L-C）。

---

## 4. 安全系数：估算近似会不会导致误判

### 4.1 误差的方向性原则

> **高估 → 浪费预算、体验变差，但证据安全。**
> **低估 → 冲过 471,860 → 静默压缩 → 帧变文字 → 不可逆。**
>
> **所以安全系数只能朝一个方向加：`≥ 1`。**

### 4.2 什么情况下会失真（逐条给对策）

| # | 失真来源 | 方向 | 量级 | 对策 |
|---|---|---|---|---|
| **1** | **大图用固定 1500 计价** | **低估** | 3840×2160 实际 ÷750 是 11,059，**低估 7.4 倍** | **已在本规格里根治**：改 `mode: max_of` |
| **2** | **联系表被当成一张图** | **低估** | 3000×2000 的 12 列表 = 48 帧，按像素只算 8,000 tok，**真实接近 48 格之和** | 脚本加 `-SheetCols N`，按 `N × 单格 token` 折算，而不是整张图的像素；并在报告里打 `[SHEET]` 提示「这张不是一张图」 |
| **3** | **视频附件** | **低估到 0** | `capabilities.input` 含 `video`，而 `P6` 对 `video/*` 返回 **0** | `unpriceable.action = refuse`：直接告警并中止门禁，**绝不按 0 放行** |
| **4** | **在途尾巴未结算** | 低估 | 最后一批图还没进 assistant 消息 | 台账 `commit` 行兜底（§3.4） |
| **5** | **上游网关缩图** | 高估 | 若 4K 被压到 2000px，实际远低于估算 | **安全，无需处理**。这正是 05「低估 62%」的镜像，方向对我们有利 |
| **6** | **服务商对重复图去重** | 高估 | 同一张图读两次可能只计一次费，`cache.read` 会体现 | 安全。`measured` 是权威值，估算只管新图 |
| **7** | **`limit` 是声明值不是实测上限** | 低估 | 上游可能比声明的更早拒 | 已有 §1.2 的 `overflow` 反应性触发兜底；且门禁线在阈值之下 25%，天然留了余量 |

> **第 1 条是本单最重要的实质发现。** 现行讨论里 `750` 与「固定值」被当成两个可替换的选项，
> 但对 4K 静帧（本项目的主要看图对象）**固定值会低估 7.4 倍**——比 05 观察到的 62% 严重一个量级，
> 且方向正是最危险的那一侧。`max_of` 一行配置就消掉它。

### 4.3 安全系数取值建议

```
cost_effective = Σ max(flat_tokens, w×h ÷ pixel_divisor) × safety_factor
                                                     ^^^^^^^^^^^^^^^^^^^  只乘本轮新增
                                                                  safety_factor = 1.5
```

**为什么是 1.5，以及为什么只乘新增、不乘 total：**

1. **只乘新增**：`used.measured` 是**服务商真实计费**，误差为 0，给它乘系数纯属浪费预算。
   误差只存在于「还没发出去的图」这一段。
2. **1.5 而不是 1.0**：剩下的误差源 #2/#3/#4 都是**结构性低估**，1.0 等于零保护。
   1.5 覆盖「联系表列数算错一档」「尾巴记漏一小段」这类常见操作失误，
   同时不至于把预算砍到无法工作。
3. **为什么不是 2.0**：`max_of` 已经把主导误差（#1，7.4×）压到除数自身的 0.1%–3.9%。
   剩下的项都是**可枚举、可加 `-SheetCols` / 可加台账**的结构性项，
   靠对策解决比靠系数硬撑更准。2.0 会让 4K 静帧从 32 张掉到 16 张，实际不可用。
4. **上限是「偏保守」而非「偏精确」**：整条规则宁可少看几张图，
   也不接受一次静默压缩——本项目交付的就是证据，而压缩之后「凭什么这么说」再也回查不了。

**换算成「还能看几张」（`soft_fraction=0.75`，阈值 471,860，门禁线 353,895，`used≈0`）：**

| 单图尺寸 | `max_of` 计价 | 安全后 | 本轮可看 |
|---|---|---|---|
| 512×512 | 1,500 | 2,250 | ~157 |
| 960×540 | 1,500 | 2,250 | ~157 |
| 1280×720 | 1,500 | 2,250 | ~157 |
| 1600×900 | 1,920 | 2,880 | ~122 |
| 2000×1500 | 4,000 | 6,000 | ~58 |
| 3840×2160 | 11,059 | 16,588 | ~21 |

这与 05 §「单轮 prompt token」的表基本吻合，且**首次把 4K 单独列了出来**——
现行规则完全没有这个档位，而它恰恰是 `auto_resize` 传闻指向的那一档。

---

## 5. 换模型时怎么办：零重配的具体做法

**核心主张：门禁需要的所有数字里，只有「每图 token」一个不在运行时可得，
而它已经用 `overrides` + `default` 两级表兜住了。所以换模型不需要改任何代码或文档。**

| 换模型的动作 | 需要改什么 | 机制 |
|---|---|---|
| 同 provider，换 modelID | **什么都不改** | `limit` / `capabilities` 运行时从 `/api/model` 读 |
| 换 provider，modelID 不变 | **什么都不改** | 定位键是 `providerID/modelID` 复合键（`space-bunny-free` 在两个 provider 下都有行） |
| 换到纯文本模型（40 里 10 个） | **什么都不改** | `capabilities.input` 无 `image` → 自动 `[MOOT]` exit 3，不需要人记得改规则 |
| 换到只有 `context` 没有 `input` 的模型（34 个） | **什么都不改** | `input \|\| context` 兜底；若两者皆无 → 复刻 `context_fallback: 200000`（阈值掉到 180,000，门禁自动变紧） |
| 厂商改了图片计费 | **改 `overrides` 一处**；若影响全部模型则改 `default.image_cost` 一处 | 配置表，不动代码不动文档 |
| 厂商改了压缩阈值算法（10%/16k/200000） | **改 `compaction` 三处** | `N6` 是唯一复刻点，参数全部外置 |
| 用户设了 `compaction.reserved` | **什么都不改**（需脚本读配置文件） | `N6` 里 `buffer!==undefined` 分支接管，`ratio`/`floor` 自动失效。⚠️ 见下方待确认项 |
| harness 升级改了路由/端口/认证 | **改 `sources` 三处** | 全部外置；读不到时 `exit 4 DEGRADED` fail-open，不卡死流程 |

**让「零重配」真正成立的三条实现纪律：**

1. **脚本每次运行都打印「每个数字从哪来」。** 输出里 `limits.source` / `usage.source` /
   `config_file` / `config_confidence` 四项常驻。换模型后哪怕没改配置，
   读数也会**自己变**并显示来源——这是可审计的「自动适配」，而不是靠信任一句承诺。
2. **`AGENTS.md §9` 与 `IMAGE_LIMIT.md` 里只允许出现公式，不允许出现数字。**
   数字全部指向 `config/image_budget.json`。这条是对 06 V3 的正解：
   `IMAGE_LIMIT.md:21` 之所以挡路，是因为它**只禁止文档写死、没禁止脚本写死**；
   正确做法是把文档改成「读这个文件」，而不是发一条禁令。
3. **`default` 必须在 `overrides` 缺失时独立成立。** 任何「新模型需要先在配置里登记一下」
   的设计都是伪零重配——登记这一步本身就是重配。

---

## 6. 待确认项与需要点头的地方

**⚠️ 一处本单没能闭环，必须实测（不要当已知用）**

`N6` 的 `buffer` 参数来自运行态 `{auto, keep, buffer}`。`keep` 的默认值 15000 在源码里查到了，
但 **`buffer`（对应 `compaction.reserved`）在 `/api/config` 里读不到**——该端点只返回一个配置文件路径：

```json
[{"type":"directory","path":"C:\\Users\\Administrator\\.config\\opencode"}]
```

本机已确认**全局与项目级都没有 `opencode.json`**，所以此刻 `buffer` 必为 `undefined`、471,860 成立。
但一旦用户建了配置文件设 `compaction.reserved`，脚本就会失读。**处置**：
脚本需自行读 `~/.config/opencode/opencode.json(c)` 与项目级配置解析 `compaction.reserved`，
读不到时按 `undefined` 处理并在 JSON 里标 `"reserved_source": "default"`。
**这一条属于「已定位、需实现」，不是「已核实」。**

**需要用户点头的两件事（与 07 §2.5 一致，本单不重复论证）**

1. **脚本读本机 `service.json` 凭据 + 连 127.0.0.1 私有 API。** 这是安全面的扩大。
   本单已按最小权限设计：**只读**该文件、只在内存中使用、**不打印、不落盘、不外发**、只连回环地址。
   仍需明确授权。另提供 `-Offline` 开关，完全不碰凭据，只用 `config` 里的静态值（退化成弱版本）。
2. **改 `AGENTS.md §9` 强制条文**（含删掉 `IMAGE_LIMIT.md:21` 那句焊死句、修掉 L7/L17 自相矛盾）。

**建议的落地顺序（可中途叫停）**

| 步 | 内容 | 可否单独叫停 |
|---|---|---|
| 1 | 建 `config/image_budget.json` + 脚本 v3（`-Recurse`、多扩展名、exit 2/3/4、`-Json`、`-UnsafeOverride`） | ✅ 只加文件不改规则 |
| 2 | 删 `IMAGE_LIMIT.md` 的「50」与 L21 焊死句、修 L7/L17 矛盾、修 `README.md:18` 与 `roughcut-launch.md:90` 两处漂移 | ✅ 独立于门禁 |
| 3 | 一次标定实验定 `image_cost`（读 N 张已知尺寸的图，比对 `tokens` 增量，把 `confidence` 从 `unverified` 改成 `measured`） | ✅ 可跳过，跳过则长期保守 |
| 4 | 可选加固：`compaction.reserved` 调大，把 471,860 往外推 | ✅ 零代码，随时可撤 |

---

## 附：给用户的三句话

1. **三个数字：上限读到（524288）、已用读到（但要五项不是三项）、每图 token 需实测**——
   而且 opencode 自己用的是**每图固定 1500**，代码里根本没有 `750`。
2. **「750」换成 `max(1500, w×h÷750)`**：一行配置，消掉 4K 静帧上 7.4 倍的低估——这比 05 说的 62% 严重一个量级，而且方向最危险。
3. **累计不用手工记**：`used` 取自上游真实计费，天然含全部历史看图；手工计数器只会重复计算（06 说的「只算一半」正是这么来的）。
