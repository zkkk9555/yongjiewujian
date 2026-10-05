# 03 · 看图预算到底有没有害过我们 —— 事故史核查

> 任务单第 3 份。用户要求：**只讨论，不修改任何东西**。本单未改动任何项目文件。
> 方法：① 全库文本溯源（`rg -uu`，含 gitignore 内的 `.scratch\`）；② 直接读 opencode 会话库
> `C:\Users\Administrator\.local\share\opencode\opencode.db`（**复制件** 15.3 GB，只读打开），
> 逐条消息解析 652 个会话 / 35,392 条 assistant+user+system+synthetic 消息。
> 环境预检已跑：`[SUMMARY] ok=9 warn=1 blocker=0`。

---

## 0. 一句话结论

> **在本机可核查的全部历史里，这条规则从未拦住过任何东西，也从未救过任何一次会话。**
> 支撑它的两次「事故」在本库内**零第一手证据**：无错误消息、无状态码、无网关日志、无日期，
> 连伤亡人数自己都对不上。而同期 10,730 次真实读图里，最高的一个会话累计 50 张、**正常跑完**。

---

## 1. 「会话作废」记录逐条溯源：**全部是二手转述，第一手证据 0 条**

全库（含 `.scratch\`、`123\`、`docs\`）检索 `作废 / 报废 / 换新窗口 / sess_03bfff9d / 53 张`，
命中 34 处。**按「谁写的」分类，没有一处是当事人记录的事故报告。**

| # | 出处 | 原文（节录） | 性质 | 可核对性 |
|---|---|---|---|---|
| E1 | `IMAGE_LIMIT.md:26` | 「上一轮曾因一次性单独提交 53 张图片导致上游返回失败、会话作废，只能开新窗口；`sess_03bfff9d` 则因每批 5 张小批量多轮累加超 50 同样作废。」 | 规则文本自述 | ❌ 无错误消息、无日期、无转录 |
| E2 | `AGENTS.md:259` | 与 E1 **逐字相同** | 规则副本 | ❌ |
| E3 | `docs\WORKFLOW.md:109` | 与 E1 同义改写 | 规则副本 | ❌ |
| E4 | `docs\TROUBLESHOOTING.md:294–296` | 节标题「单轮一次提交超过 50 张图片导致会话作废」+ E1 同文 | 规则副本（**排版成"故障排除条目"，更像事故记录，实际不是**） | ❌ |
| E5 | `docs\粗剪提示词.md:131` | 「—— 这条曾让**两个**会话作废，别拿它冒险。」 | 规则文本 | ❌ 且**与 E6 口径冲突** |
| E6 | `skills\…\complete-combat-roughcut.md:229` | 「失败教训：53 张单轮作废、`sess_03bfff9d` 累加作废。」 | 规则副本 | ❌ |
| E7 | `.scratch\image-limit-enforce\NOTES.md:18` | 「upstream failure shape in `sess_03bfff9d` **proves** per-round-new is insufficient」 | **全库最早一次把 sess_03bfff9d 当论据使用**，由写 spec 的 Agent 转述 | ❌ 无任何引文 |
| E8 | `.scratch\image-limit-enforce\spec.md:11` | 「…yet a later round still submitted 53 images in one turn. Upstream failed and the session could not continue」 | 同上，英文复述 | ❌ |
| E9 | `.scratch\image-limit-50-hardline\spec.md:13` | 「Several sessions (`sess_fd6d3012`, `sess_47c354c9`, `sess_b3a79071`, `sess_729a549a`) hit this shape.」 | **4 个 ID 唯一出处**，就这一行 | ❌ 别处零复现 |
| E10 | `123\workflow_upgrade\{d1,e1,e3,e4,merge_log}.md`、`\.scratch\oneprompt\07-failure-and-rollback.md` | 「50 张会话作废 \| 53 张单轮、sess_03bfff9d 累加」等 | 下游**再次引用** | ❌ |
| E11 | `docs\lessons\archive\864-rejected-attempt\reports\*.md`（44 份） | 全部是**合规自述**（「累计 41 ≤ 50」「未越线」），**零份事故记录** | 反向证据 | — |

### 1.1 三个硬事实

1. **第一手证据 = 0 条。** 没有任何一处出现：错误消息原文、HTTP 状态码、API 响应体、网关日志、会话转录、发生日期。
   「作废」这个词在库里**只出现在规则自己身上**（E1–E10 全部是规则文本或其下游引用）。
2. **伤亡人数自相矛盾**：E5 说「**两个**会话」，E9 一句话点名 **4 个** ID，加上 53 张那次与 `sess_03bfff9d`，
   最多 6 个。规则的正当性建立在一个**连自己都写不一致**的统计上。
3. **5 个会话 ID 一个都不存在于本机会话库。** 逐个查 `session_v2`：

   ```
   sess_03bfff9d -> None      sess_fd6d3012 -> None
   sess_47c354c9 -> None      sess_b3a79071 -> None      sess_729a549a -> None
   select count(*) from session_v2 where id like 'sess_%'  ->  0
   ```

   本 harness 的 ID 形如 `ses_f134cf2c4ffdMDgUVGv3hONzaH`（`ses_` + 26 字符）。
   `sess_` + 8 位十六进制是**另一个 harness** 的格式，其转录不在本机。
   ⇒ 这些 ID **既不能证实也不能证伪**，它们是不可核查的引用。

---

## 2. 会话库实测（本机 652 个会话，2026-09-28 → 2026-10-05）

### 2.1 单条消息带图数（这就是"单轮"口径）

扫描全部 35,392 条消息，取每条里**真正以图片为参数的工具调用**（`read`/`filePath` 指向
`.jpg/.jpeg/.png/.webp/.gif/.bmp`），排除工具输出文本里的文件名回显：

| 每条消息图片数 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 10 | **>10** | **>50** |
|---|---|---|---|---|---|---|---|---|---|---|---|---|
| 消息条数 | 6286 | 1149 | 244 | 142 | 99 | 23 | 6 | 8 | 3 | **8** | **0** | **0** |

- 带图消息共 **7,968** 条，图片读图调用共 **10,730** 次。
- **单条消息最多 10 张 = 恰好等于项目自订的"单轮新增 ≤10"。**
  这不是巧合，是纪律**确实被执行了**；但也说明 10 是被守住的软约束，不是被撞出来的天花板。

### 2.2 单个会话累计带图数（这就是规则自称的"累计口径"）

| 排名 | 累计图数 | 会话 | 结局 |
|---|---|---|---|
| 1 | **50** | `ses_f134cf2c4ffdMDgUVGv3hONzaH` 「Scan seg8 [595,685)」2026-09-29 | **succeeded** |
| 2 | 49 | `ses_f0ef13568ffepkDcZWI7ZdMryH` 「Self-audit v1 four passes」 | succeeded |
| 3 | 48 | `ses_f15b7496fffeVIXQYSO5slnxec` 「Resolve seg4 seg5 conflict」 | succeeded |
| 4 | 46 | `ses_f0f51f9c5ffemuvX8Sglw4F1Xv` 「Re-audit oversized deletions」 | succeeded |
| 5–25 | 45…38 | （864/861/863/860 各路扫描员、自审、对抗审） | **全部 succeeded** |

**历史上离红线最近的一次，是一个会话累计正好 50 张——它跑完了。**
本 harness 的全部记录里，**没有任何一个会话累计超过 50 张**。

会话分布（同一次独立复算，34,457 条 assistant+user 消息、10,875 次读图）：

| 条件 | 会话数 |
|---|---|
| 全库读图会话 | **542** |
| 累计 ≥11 张 | 446 |
| 累计 ≥31 张 | 85 |
| 累计 ≥45 张（贴线 ≥90%） | **7** |
| 累计 ≥50 张 | **1**（峰值 = 50，无超限） |

### 2.3 会话结局分布与全部 provider 错误

`select idle_outcome, count(*) from session_v2 group by idle_outcome`：

```
succeeded 647 | None 3 | interrupted 1 | failed 1
```

**652 个会话里死过 1 个**：`ses_f100cb1e7ffeCCE810rfWz2IQ3`「Self-audit v3 four passes」，
2026-09-30 02:24:12，死因原文：

```json
{"type": "provider.internal", "message": "Upstream request failed: Endpoint is unavailable.", "status": 500}
```

**与图片毫无关系**（那一步它在写 Pass 1 的落盘文件）。

全库 provider 级错误**共 44 条，去重后只有 4 种**：

| 次数 | 类型 | 原文 | 会话是否死 |
|---|---|---|---|
| 41 | `provider.invalid-output` | `OpenAI Chat stream ended without finish_reason` | 否，全部续跑 |
| 3 | `provider.internal` | `Streaming response failed: [api_error] internal server error` | 否 |
| 1 | `provider.internal` | `Upstream request failed: Endpoint is unavailable.` (500) | **是（唯一一次）** |

**零条** `invalid_request`、零条 `too many image(s)`、零条 400/413/429、零条提到图片张数的错误。

---

## 3. 反例：看了很多图但没事的记录

| # | 反例 | 出处 / 数据 | 说明 |
|---|---|---|---|
| R1 | **累计 50 张的会话正常完成** | `ses_f134cf2c4ffdMDgUVGv3hONzaH`，50 张，`succeeded` | 正好压在红线上，没死 |
| R2 | 单轮 19 张连着看，自认违规，**什么也没发生** | `864-rejected-attempt\reports\adversarial_864_v3_adv6.md:204`：<br>「R5 那一轮我一次性产出了 19 张作废图并连续查看——**这已经踩到「单轮新增 ≤10」的边缘，是我的操作失误**…作废批我仍然逐张看了，正是这个过程才发现漏 `fps=`」 | **违规 19 张不仅没炸，还救了那轮报告**（据此发现三条错误面板结论） |
| R3 | 自审整轮累计 46 张（红线 50），跨 4 遍视角 | `selfaudit_864_v1.md:447`、`issue_list_v1.md:241`：「自审全程 46 张图（单轮峰值 4，累计 46 ≤ 50），帧覆盖 697 帧」 | 92% 贴线通过 |
| R4 | 单请求累计 45 张 | `seg7_scan_report.md:225`：「每轮新增 ≤10，单请求累计 45 ≤ 50，未越红线」 | 90% 贴线通过 |
| R5 | 三个任务 261 份报告，**零次**超 50 | `.scratch\image-budget\01-provenance-and-cost.md §3.1`（已复核目录清单） | 峰值 46（我方 DB 实测也是 50，见 2.2） |

**R2 是最有力的反例**：它是全库唯一一次**自认越过 ≤10** 的记录，后果不是会话作废，而是**产出了正确结论**。

---

## 4. 「651 会话里单条消息最多 10 张」是否属实

**属实，且我这轮独立复算了一遍（口径比它更严）。**

| 项 | 别的 Agent 的说法 | 本单实测（`opencode.db` 复制件） |
|---|---|---|
| 会话总数 | 651 | **652**（647 属本项目 + 5 属 `Default Project`） |
| 模型分布 | 650 × `space-bunny-free` | **651 × `space-bunny-free` + 1 × `muse-spark-1.3-contributor-free`** |
| 单条消息最多图片 | 10 | **10**（>10 的消息 **0** 条） |
| 覆盖时间窗 | — | 2026-09-28 20:00 UTC → 2026-10-05（UTC） |
| 累计口径峰值 | 未测 | **50（1 个会话）** |

差异只差 1 条会话（就是本会话自己）。**「从来没逼近过上限」这个说法要修正一处**：
按规则自称的**累计口径**，历史上确实逼近过——**峰值 50/50，零超限**。
按**单轮口径**，峰值 10/10，同样零超限。

> ⚠ 诚实标注一处覆盖缺口：`opencode.db` 最早的会话是 **2026-09-28**，
> 而 `IMAGE_LIMIT.md` 在建库（`83ec619 v1.001`）之前就存在，声称的两次事故可能发生在这之前。
> 但 **git 也答不了**：`git log -- IMAGE_LIMIT.md` 只有 1 个 commit（入库即存在），`AGENTS.md` 自述"v1.001 之前没有版本库"。
> 所以那段历史**在本机既无记录也无痕迹**——这正是问题所在：**它没有留下任何可供复核的东西。**

---

## 5. 这条规则最初是为了防什么（自述溯源）

### 5.1 规则自述的"敌人"

| 出处 | 自述 |
|---|---|
| `IMAGE_LIMIT.md:3` | 「**上游**单次请求携带的图片总数上限都是 50 张」——断言为事实，**零引文**（无网关文档、无配额页、无 provider 声明） |
| `IMAGE_LIMIT.md:5` | 「超过后**上游直接失败**、当前会话无法继续，只能换新窗口」 |
| `docs\粗剪提示词.md:21` | 「**唯一允许的重复是看图上限。** 因为违反它不是报错，是整个会话报废，代价太大，值得付这点重复成本。」 |

→ 8 份文档里的重复**是被 E5 这句话正当化的**。要动这条规则，先得动这句话。

### 5.2 演进两棒（都是"加固"，不是"起源"）

1. `.scratch\image-limit-enforce\` —— Gate 0 原文：`HIT: 50 present in AGENTS.md:121, IMAGE_LIMIT.md:3, …`
   → **做这个 spec 时，50 已经在 4 处文档里了**。它新增的是累计口径、≤10/轮、两个脚本。
2. `.scratch\image-limit-50-hardline\` —— `Keep 50 … and change it from a statement into an enforceable pre-flight procedure`。
   4 个会话 ID 就在这里第一次出现，且是**唯一一次**。

### 5.3 三条独立线索指向"这段文字是从别的 harness 搬来的"

| 线索 | 证据 |
|---|---|
| **工具名不存在** | 规则原文要求把 `get_app_state` 截图 + `screenshot` + `zoom` 裁图计入预算。**这三个工具在 opencode 里全都不存在**（本项目可用：`read`/`shell`/`grep`/`glob`/`edit`/`write`/`browser.*`）。 |
| **会话 ID 格式不同** | `sess_` + 8 hex（引用里的 5 个）vs 本机 `ses_` + 26 字符，命中率 0/5。 |
| **模型样本只有 1 条且无关** | 全库唯一一条 `muse-spark-1.3-contributor-free` 会话 = `ses_f003e926fffeq0yAw1wgyH6eIu`，标题「雷蛇鼠标驱动问题」，2026-10-03，**通篇没有一张图片**。规则自称的出处模型，在本机留下的唯一足迹与看图毫无关系。 |

### 5.4 唯一的执行手段是个打印机

`scripts\check_image_budget.ps1`：`[int]$Cap = 50` / `[int]$PerRoundNew = 10` 是**参数默认值**，
`Get-ChildItem -Filter $Pattern -File` **无 `-Recurse`**，超 Cap 只打印 `[PLAN]` 然后 `exit 0`。
（此段由 `.scratch\image-budget\01-provenance-and-cost.md §2` 实跑验证，本单读源码复核属实。）
**它不拦任何东西**，8 份文档里的"强制""硬红线"靠的是模型自觉。

---

## 6. 判定：这条规则救过我们吗？

> **没有。至少在本机可核查的全部历史里，它一次都没有救过任何东西。**

| 判据 | 结论 |
|---|---|
| 有第一手事故证据吗 | **0 条**。无错误消息、无状态码、无日志、无日期、无转录 |
| 事故描述自洽吗 | **不自洽**。"两个会话" vs 最多 6 个 |
| 引用的会话 ID 可核对吗 | **5/5 不存在于本机**，格式属另一 harness |
| 它拦下过超限吗 | **0 次**。10,730 次读图，峰值 50/50，零超限 |
| 它救过被它约束的会话吗 | **0 次**。唯一死掉的会话死于 `500 Endpoint is unavailable`，与图片无关 |
| 违反它的后果实测是什么 | **R2：单轮 19 张，没死，还因此发现了漏 `fps=`** |
| 全库唯一 provider 硬失败 | 500 Endpoint unavailable（1 次） |

**必须同时说清的另一半**（避免这份报告被当成"删规则的理由"）：

1. **它作为工作卫生是有效的**：261 份报告每路都记账，零超限；它逼出了联系表（863：560 帧 → 28 图，20×）
   与零看图数值判据（`POOL` L-013/L-014）。**这些成果该留。**
2. **真正卡住的一直是 ≤10/轮，不是 50。** 864 v3 的账：单轮峰值恰好 10 = 上限；50 在三个任务里从未成为约束。
3. **50 这个数从未被验证过，也从未被逼近过**（累计口径下有人正好摸到 50，通过）。
   它现在的正当性是"因为文档这么说，所以它是真的"——**这是信仰，不是证据**。

**风险方向要说对**：现行 50 是**保守方向的错误**（限制了一个没人证实存在的上限），
而不是危险方向的错误（放开了一个确实存在的硬限）。真威胁在别处
（harness 在 ~471,860 token 处自动压缩会把帧换成文字、`auto_resize` 缩到 2000px 吃掉 HUD 小字）
——见 `.scratch\image-budget\05-risk-analysis.md`。

---

## 7. 本单的方法与局限（照实写）

- **做了**：全库 `rg -uu` 溯源 34 处引用；复制并只读解析 15.3 GB 会话库，
  逐条解析 35,392 条消息的工具入参；统计每消息/每会话图片数；穷举全部 provider 错误；
  逐个核对 5 个会话 ID；读 `check_image_budget.ps1` 源码复核。
- **没做（不能做）**：没有修改任何项目文件；没有创建环境、没有安装任何东西；
  没有试图复现 50 张上限（本机网关侧证据不足，见 `.scratch\imgbudget2\02-current-model-limit.md`）。
- **覆盖缺口（唯一实质局限）**：`opencode.db` 只覆盖 2026-09-28 起。
  规则自称的两次事故若发生在此之前，本机无任何痕迹可查——**但那两次事故也没有在任何地方留下痕迹**。
  所以准确表述是：**"无法证实"，不是"已证伪"**。
- **临时文件**：分析脚本与 DB 复制件写在 `%TEMP%\opencode\dbq\`，不在项目目录内，可随时删。