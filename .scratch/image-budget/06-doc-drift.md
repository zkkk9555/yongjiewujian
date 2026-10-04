# 06 号 · 看图预算：文档冗余漂移 + `check_image_budget.ps1` 自身问题

> 站位：脚本缺陷 + 文档收敛。真源候选 = `IMAGE_LIMIT.md`（沿用 10 号结论）。
> 所有脚本结论均为**本轮实跑复现**，测试目录 `%TEMP%\opencode\ibtest`，未写入项目树。

---

## 1. `scripts\check_image_budget.ps1` 全文审读 + 实跑复现

脚本全文 69 行，`param()` 7 个参数，逻辑只有 4 段：数文件 → 算 `remaining` → 切轮 → 打印。
**它没有任何一处会因"超限"而 FAIL**，唯一会 `exit 1` 的条件是 `$remaining -le 0`（第 27 行），
即**已经用完**才拦，从不拦"将要用完"。

### 1.1 实跑矩阵（8 组，全部可复现）

| # | 调用 | 期望 | 实测输出 | 真实 exit |
|---|---|---|---|---|
| T1 | 60 jpg，默认 Cap 50 | 应拦下 | `TotalOnDisk: 60 / Cap: 50 / Remaining: 50 / RoundsNeeded: 6` | **0** |
| T2 | `-Cap 500` | 应告警 | `Cap: 500, Remaining: 500`（零告警） | **0** |
| T3 | `-PerRoundNew 60` | 应告警 | `FirstRoundNew: 50` → `Round 1: 50 images` → **`[PASS] fits in one round. Read at most the listed images this round.`** | **0** |
| T4 | 父目录（60 jpg 在 `flat\`、40 png 在 `sub\deep\`） | 应数到 | `TotalOnDisk: 0` → `[PASS] no images to review.` | 0 |
| T5 | 只含 40 张 PNG 的目录 | 应数到 | `TotalOnDisk: 0` → `[PASS] no images to review.` | 0 |
| T6 | `AlreadySeen 49` + 5 张 | 应拦下 | `Remaining: 1` → `[PASS] no images to review.` | 0 |
| T7 | `-PerRoundNew 0` | 应报错退出 | `InvalidCastException`（第 41 行除零）→ 继续打印 `RoundsNeeded: , FirstRoundNew: 0` | **0** |
| T8 | `mixed\` 根 12 + `sub_a\` 12 + `sub_a\sub_b\` 12 = 36 | 应数到 36 | **`TotalOnDisk: 12`**（少算 3×） | **0** |
| T9 | `-AlreadySeen 50`（== Cap） | 应拦下 | `[FAIL] budget exhausted.` | **1** |
| T10 | `-AlreadySeen 45` + 60 张 | 应拦下 | `Remaining: 5` → 打印 **7 轮共 60 张** 的计划 | **0** |
| T11 | `-AlreadySeen 50` + 60 张 | 应拦下 | `[FAIL] budget exhausted.` | **1** |

### 1.2 缺陷清单（8 条）

**S1 · `-Cap` / `-PerRoundNew` 完全可覆盖，且 `-PerRoundNew` 能把门禁反转成 PASS**
`check_image_budget.ps1:6-7` 两个红线数字都是普通 `int` 入参，无任何守卫。T2 证明 `-Cap 500` 被静默接受。
更严重的是 T3：`-PerRoundNew 60` 让脚本打印 `Round 1: 50 images` 之后给出 **`[PASS] fits in one round. Read at most the listed images this round.`**
—— 脚本**主动批准了单轮读 50 张**，正是 53 张事故的形态。根因是第 59 行的判定
`if ($total -gt $PerRoundNew)`：把 `PerRoundNew` 调大，结论就从 `[PLAN]` 翻成 `[PASS]`。
**红线不是常量，是可调参数。**

**S2 · 非递归，静默少算，实测 3×**
`check_image_budget.ps1:18` 是 `Get-ChildItem -LiteralPath $ImageDir -Filter $Pattern -File`，无 `-Recurse`。
T8：36 张分布在 3 层，脚本报 `TotalOnDisk: 12`，exit 0，无任何提示。
**这不是理论缺陷，864 已经踩过**：`docs\lessons\archive\864-rejected-attempt\reports\adversarial_864_v3_adv3.md:358`
原文写着「`check_image_budget.ps1` 已跑（**它只扫目录根的 `*.jpg`，我的帧在子目录，故报 `TotalOnDisk: 0`**；我自己按轮记账）」——
一个 Agent 拿到了一份针对空扫描的 `[PASS]`。

**S3 · 只认 `*.jpg`，PNG 全隐形——而 PNG 正是条文点名的那些工具**
`check_image_budget.ps1:4` 默认 `$Pattern = '*.jpg'`。T5：40 张 PNG → `TotalOnDisk: 0` → `[PASS] no images to review.`。
`IMAGE_LIMIT.md:12` 明文把 `get_app_state` 截图 + `screenshot` + `zoom` 裁图计入累计。
**这三种调用的产物是 PNG、且从不落盘**——条文点名的对象，脚本一个都看不见。

**S4 · 累计口径只算了一半，而且脚本打印的计划自身就违反它**
`$remaining = $Cap - $AlreadySeen`（第 20 行）是唯一的累计运算。T10：`-AlreadySeen 45` + 盘上 60 张，
脚本给出 `Remaining: 5`，随后**打印一个跨 7 轮、共 60 次新读的计划**——按它自己引用的累计口径，
累计将是 105 > 50，而 exit 0。
换句话说：**脚本输出的计划，恰好就是它声称要防止的那个违规。**
`-AlreadySeen` 是调用者手打的 int，没有任何状态来源，**不可证伪**（填 0 就当没看过）。
`$AlreadySeen -gt 0` 时第 66 行只打一句 `[NOTE]`，仍然不拦。

**S5 · 崩溃被当成通过（`exit 0`）**
`$ErrorActionPreference = 'Continue'`（第 10 行）+ 第 41 行 `($total - $firstRound) / [double]$PerRoundNew` 无除零保护。
T7：`-PerRoundNew 0` 抛 `InvalidCastException`，脚本继续往下跑，打印 `RoundsNeeded: , FirstRoundNew: 0`，**exit 0**。
**崩溃的门禁和通过的门禁在调用方眼里完全一样。**

**S6 · 口径与 `IMAGE_LIMIT.md` 根本不是同一个量**
- 条文口径（`IMAGE_LIMIT.md:7,12`）：**一次上游请求携带的图片总数，会话内累计**，含 `Read` + 截图 + `screenshot` + `zoom`。
- 脚本口径：**此刻某个目录层里匹配一个 glob 的文件数**。

两者互不包含：脚本漏掉子目录（S2）、漏掉 PNG/在内存图（S3）、没有"本轮"概念（本轮新增是条文的核心量，脚本从头到尾没算过）。
**「单轮新增 ≤10」这条规则，在整个项目里没有任何一处机器检查。**

**S7 · 无 JSON、无状态、无副作用，无法被任何门禁消费**
只有 stdout 文本，无 `-Json`；不写任何状态文件（所以 S4 的 `AlreadySeen` 无从派生）；只读预演，
但**「本轮真的只读了 Round 1 那 N 张吗」脚本无法验证，也无人验证**——T3 那句 `Read at most the listed images`
是纯建议，零强制。
附带债：`image-limit-enforce/spec.md:67` 把验收锚点写成 `check_image_budget.ps1 :: Show-ImageBudgetPlan (new)`，
**交付物里没有这个函数**，是个 param 脚本（01 号 D5，核实属实）。

**S8 · 越界不 FAIL，只在"已经死"时才 FAIL**
`check_image_budget.ps1:27-30` 是唯一的 FAIL 分支，条件 `$remaining -le 0`。
T1/T9（盘上 60 > Cap 50）exit 0；T10（累计 105 > 50）exit 0；只有 T11（`AlreadySeen == Cap`，累计正好 50）才 exit 1。
**门禁拦的是"已超"，不是"将超"。**

---

## 2. 改造后规格（`check_image_budget.ps1` v2）

一句话：**从"打印建议"改成"带状态的判门禁"，数字不可调、计数递归全覆盖、违规 exit 2、预检可消费。**

### A. 数字不可覆盖
- 红线数字移出脚本参数，读唯一机读源 `config/image_budget.json`：`{ "per_request_cap": 50, "per_round_new": 10 }`。
  `IMAGE_LIMIT.md` 显式指向该文件——**数字从此只有一处**。
- 删除 `-Cap` / `-PerRoundNew`。确需测试覆盖时走 `-UnsafeOverride`，此时强制打印
  `[WARN] redline overridden by operator` 并 **exit 2**，让"放宽红线"永远无法静默成功。

### B. 计数对象 = 真正会进请求的图，三个来源分开记账
1. **递归 + 多扩展名**：默认 `-Recurse`，匹配 `*.jpg,*.jpeg,*.png,*.webp,*.gif`。
2. **联系表 sheet-aware**（对齐 03 号 P1）：文件名含 `sheet`/`contact` 记 1 张，同时打印 `N cells` 作成本提示。
3. **在内存图**：无法自动发现 → 新增 `-InMemory <n>` 显式申报；未申报时输出 `InMemory: UNDECLARED`
   并按**最坏假设**计入（宁可多算）。

### C. 累计口径靠状态文件持久化（这是"跨对话"的答案）
- 每任务目录一份 `reports\image_budget_ledger.json`：
  `{ "session", "seen_total", "rounds": [ { "ts", "new", "tool", "files" } ] }`
- 脚本默认 `-Ledger <ImageDir 上溯到任务目录>\reports\image_budget_ledger.json`，
  自行读 `seen_total` 作为累计基数。**`-AlreadySeen` 标记 `[OBSOLETE]` 保留但忽略**——手填的数一律不信。
- 默认 **dry-run**（只读，保留现有只读性质）；`-Commit` 才把本轮实际读取追加进 ledger 并落盘。
  「跨对话」由此变成：下一轮/下一个窗口重跑同一命令，读到的是 ledger 里的真实累计，不是记忆。

### D. 判 FAIL 的四个条件（真正的门）
| 条件 | 输出 | exit |
|---|---|---|
| `seen_total + 本轮新增 > per_request_cap` | `[FAIL] cumulative X > 50` | **2** |
| 本轮新增 > `per_round_new` | `[FAIL] round new N > 10` | **2** |
| 递归后 `total == 0` 但目录下确有图片（扩展名/层级不匹配） | `[FAIL] counted 0 — recurse or pattern mismatch` | **2** |
| ledger 缺失/损坏 | `[FAIL] ledger missing/corrupt` | **2**（不猜） |

exit 码契约：`0` = 预演通过 / `1` = 环境错（目录不存在）/ `2` = 违规 BLOCKER。
新增 `-Json`，供 `qa_gate.py` 与 `check_video_environment.ps1` 预检消费——**让"看图预算"第一次成为可被门禁核对的项**（01 号 §2 指出九份报告无一核对过预算）。

### E. 必须澄清"轮"的含义
脚本的 `rounds` 是**跨请求**的分批，不是"同一请求内读 N 张"。每轮输出加 `CumulativeIfFollowed` 与 `RequestIndex`，
并在累计逼近上限时明确打 `[FAIL] N 轮计划累计 X > 50，须开新窗口/新会话` ——**直接修掉 T10 的自相矛盾**。
同时把 `IMAGE_LIMIT.md:17` 的"拆成多个**单轮**"改成"拆成多个**请求**"：在累计口径下，拆轮不解除累计。

---

## 3. 文档收敛：8 份副本逐份处置

| # | 位置 | 现状 | 处置 |
|---|---|---|---|
| 1 | `IMAGE_LIMIT.md` 1–26 | 自称真源，含 4 处未证实断言 + 1 处内部矛盾 | **保留为唯一真源，改写** |
| 2 | `AGENTS.md §9` 245–262 | 与 #1 近乎逐字重复的 7 步全文 | **保留（入口，必须自足），压成 6 行** |
| 3 | `docs\WORKFLOW.md` 101–109 | 第三份全文副本 | **替换为一行指针** |
| 4 | `docs\TROUBLESHOOTING.md` 294–298 | 第四份全文副本 | **保留，改写为故障条目视角** |
| 5 | `docs\粗剪提示词.md` 128–131 | 5 行压缩版，数字正确 | **保留（入口，用户日常唯一版，必须自足）** |
| 6 | `README.md` 18 | **唯一与真源直接矛盾**的入口（"单轮 50 张封顶"） | **保留指针，改数字** |
| 7 | `roughcut-launch.md` 68 / 90 / 106 / 159 | 4 处；**L90 完全无数字**（01 号命中） | **4 处各替换为一行指针** |
| 8 | `complete-combat-roughcut.md` 229 | 第五份全文副本 | **替换为一行指针** |

### 逐份目标文本

**#1 `IMAGE_LIMIT.md` — 真源，改写**
保留标题与 7 步骨架，但：
- 顶部加**出处注记**：`此数字源自 muse-spark-1.3-contributor-free 时代的网关观测，2026-10-04 起未再复现验证。`
- 新增 `config/image_budget.json` 引用，声明"数字以该文件为准，本文档不重复维护"。
- **删掉 L17**「确实需要超过 50 张时，拆成多个单轮依次执行」——它与 L7 累计口径**直接矛盾**（本轮新发现，见 §4）。
- **删掉 L21**「任何文档不得将其写成仅适用于某一模型的临时限制」——见 §4，这条自我约束是当前最大的文档债。
- L11 示例命令 `-ImageDir <缩略图目录>` 改掉：正是这个单目录用法造成 T8 的 3 倍少算。
- 把「强制执行顺序」里与脚本职责重复的措辞删掉，改成「跑脚本，脚本说了算（exit 2 = 违规，停）」。

**#2 `AGENTS.md §9` — 入口，保留但压成 6 行（自足）**
```markdown
## 9. 单次图片上限

- 单请求累计 ≤ 50 张（含历史已看 + 本轮全部图片工具：Read / 截图 / screenshot / zoom 裁图）；单轮新增 ≤ 10 张。
- 只数「本轮新增」不够；累计口径下拆轮不解除累计，超了只能开新请求（新窗口/新会话）。
- 看图前必须先跑 `scripts\check_image_budget.ps1`（计数走 `reports\image_budget_ledger.json` 持久化）；
  **exit 2 = 违规，必须停下先把结论落盘再换窗口**，不做预算不准看图。
- 超 10 帧优先拼联系表（`scripts\make_contact_sheet.ps1`，一表计一图）。
- 完整口径与数字出处见根目录 `IMAGE_LIMIT.md`。
```
**删掉**：与 #1 逐字重复的 7 步全文、`muse-spark` 模型点名、以及「任何文档不得将其写成仅适用于某一模型的临时限制」。

**#3 `docs\WORKFLOW.md` 101–109 → 一行**
```markdown
### 看图限流

单轮新增 ≤10 张、单请求累计 ≤50 张；执行与门禁见根目录 `IMAGE_LIMIT.md`，机器门禁 `scripts\check_image_budget.ps1`（exit 2 即违规）。
```
理由：它是 `AGENTS.md §4` 的下游，`AGENTS.md §9` 已自足，无需第三份全文。

**#4 `docs\TROUBLESHOOTING.md` 294–298 → 保留标题，改写为故障条目**
```markdown
## 看图超限导致会话中断（历史注记）

症状：上游返回失败、当前会话无法继续。**历史注记**：曾一次性提交 53 张、以及 `sess_03bfff9d` 每批 5 张累加超限
（此 50 张数字源自 muse-spark-1.3-contributor-free 时代网关，2026-10-04 起未再复现验证）。

处置：先跑 `scripts\check_image_budget.ps1 -Json`——exit 2 即说明本轮新增或累计已超限，按 `IMAGE_LIMIT.md`
的分轮/换窗口规则处置；exit 0 但 `TotalOnDisk: 0` 说明图在子目录或不是 `.jpg`，脚本 v2 会直接报 FAIL。
```
理由：troubleshooting 的读者是**已经炸了**的人，删掉标题会失去检索入口；但不该复述全流程。

**#5 `docs\粗剪提示词.md` 128–131 — 入口，保留（自足）**
```markdown
- 看图是硬红线：单请求累计不超过 50 张（含历史已看，含 Read / 截图 / screenshot / zoom 裁图），单轮新增不超过 10 张。
  看之前先跑 C:\Project\永劫无间\scripts\check_image_budget.ps1，exit 2 就是超了，停下降数并换窗口。
  超过 10 帧先拼联系表（一张联系表算 1 张）。宁可多看一轮，不可多看一张。完整口径见根目录 IMAGE_LIMIT.md。
```
（现文已无漂移，只补 `zoom` 截图类与 exit 2 语义。）

**#6 `README.md` 18 — 保留指针，改正数字**
```markdown
- 单次图片上限硬红线：[IMAGE_LIMIT.md](IMAGE_LIMIT.md)（单请求累计 ≤50 张、单轮新增 ≤10 张；看图前先跑 `scripts\check_image_budget.ps1`）
```
删除「（单轮 50 张封顶，看图前先数数）」——**这是全项目唯一与真源直接矛盾的入口文本**，
且恰好复现 53 张事故的失败形态（把两级压成一级）。

**#7 `roughcut-launch.md` — 4 处各一行**
- L68：`看图预算（派工时必须写明：引用 IMAGE_LIMIT.md + 本路 reports\image_budget_ledger.json 路径，不在 prompt 内复述数字）`
- L90：`看图预算规则（引用 IMAGE_LIMIT.md §强制执行顺序）` ← **现无数字，补指针**
- L106：`看图前先跑 scripts\check_image_budget.ps1（exit 2 即停），单轮新增≤10、单请求累计≤50；打满开新路复用结论不复看。`
- L159：`每路独立图片预算，单轮新增≤10、单请求累计≤50，累计写入本路 reports\image_budget_ledger.json。`

**#8 `complete-combat-roughcut.md` 229 → 一行**
```markdown
#### 看图限流

单轮新增 ≤10 张、单请求累计 ≤50 张（累计含历史已看 + 本轮全部图片工具）；口径与门禁见根目录 `IMAGE_LIMIT.md`
与 `scripts\check_image_budget.ps1`（exit 2 即违规）。
```
删除「全模型硬性红线」「违者会话作废」「53 张单轮作废、`sess_03bfff9d` 累加作废」——未经证实的断言。

**收敛后**：全文副本从 5 份降到 1 份（真源）；自足入口 3 份（`AGENTS.md §9`、`粗剪提示词.md`、`README.md` 指针行）；
纯指针 4 处（`WORKFLOW.md`、`roughcut-launch.md` ×4、`complete-combat-roughcut.md`）；`TROUBLESHOOTING.md` 走故障视角。

---

## 4. 顺手核实：`IMAGE_LIMIT.md` 自己有没有过时内容

| # | 位置 | 现有断言 | 核实结论 |
|---|---|---|---|
| V1 | L3, L5 | 「上游单次请求携带的图片总数上限都是 50 张」+「超过后上游直接失败、当前会话无法继续」 | **不成立为事实陈述**。04 号已查无原始证据。当前 provider 是 `opencode-go / space-bunny-free`，**已不是** `muse-spark-1.3-contributor-free`，网关与计费路径都换过。降级为带出处的历史注记 |
| V2 | L3, L21 | 「无论使用什么模型（含 muse-spark 及任何后续模型）」「与模型名称无关」 | 提法**形式上仍成立、实质已无信息量**：模型早换了，这句只是把一次观测包装成定律 |
| V3 | `AGENTS.md:257` / `IMAGE_LIMIT.md:21` | 「任何文档不得将其写成仅适用于某一模型的临时限制」 | **本轮最大文档债**。这条自我约束正好**挡住**把数字降级为历史注记的唯一合法路径——谁想修正都会违反它。改造必须**先删它** |
| V4 | L7 vs L17 | L7「计数口径是累计口径」 vs L17「超过 50 张时拆成多个**单轮**依次执行」 | **真源自身内部矛盾**（本轮新发现，比副本漂移更严重）。累计口径下拆轮**不解除**累计——L17 的处方治不了 L7 描述的病。应改为「拆成多个**请求**」 |
| V5 | L22 | 「与 `AGENTS.md §9`、`docs/WORKFLOW.md`、`complete-combat-roughcut.md` 保持一致」 | **已经不成立**。README 漂移、`roughcut-launch.md:90` 无数字。真源自称的一致性是假的——这正是收敛要修的东西 |
| V6 | L11 | 示例 `-ImageDir <缩略图目录>` | **示例本身制造缺陷**。单目录用法直接导致 T8 的 3 倍少算，且已有 Agent 因此拿到空扫描的 `[PASS]`（`adversarial_864_v3_adv3.md:358`） |
| V7 | 硬绑定 | `check_video_environment.ps1:326` `$AllowedRootFiles` 含 `IMAGE_LIMIT.md` | 保留真源在根目录**有强制力**（删了会被预检报 stray file）——这是选它当真源的第三条硬理由 |

---

## 5. 缺陷数与优先级

**脚本 8 条缺陷**：S1 红线可调且能反转成 PASS ｜ S2 非递归静默少算（实测 3×，864 已踩） ｜ S3 PNG/在内存图隐形 ｜ S4 累计只算一半且计划自身违规（实测累计 105 exit 0） ｜ S5 崩溃仍 exit 0 ｜ S6 口径与条文不是同一个量 ｜ S7 无 JSON/无状态/无法被门禁消费 ｜ S8 只拦"已超"不拦"将超"。

**改造后规格一句话**：红线数字移入 `config\image_budget.json` 由脚本只读（`-UnsafeOverride` 才可调且强制 exit 2），
计数改递归多扩展名 + 联系表按 1 张 + 在内存图显式申报，累计基數由 `reports\image_budget_ledger.json` 持久化而非手填，
四条 FAIL 条件一律 **exit 2** 并加 `-Json` 供预检/`qa_gate.py` 消费，默认 dry-run、`-Commit` 才落盘。

**文档漂移 2 处（01 号已实证，本轮复核属实）**：README「单轮 50」与真源「累计 50 + 单轮新增 10」矛盾；`roughcut-launch.md:90` 无数字。
**本轮新增 2 处真源自伤**：`IMAGE_LIMIT.md` L7 与 L17 内部矛盾；L21「不得写成仅适用于某一模型」把数字焊死。