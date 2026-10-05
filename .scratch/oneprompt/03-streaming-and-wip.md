# 03 · 流式合成（岛式合并）+ `wip-` 预览旁路：可行性与风险

> **视角**：只回答两件事能不能做、做了碰哪些现有条文/脚本、半成品会不会被当成品。
> **取证日**：2026-10-05 · **本轮只读，不改任何项目文件**（唯一写入是本报告 + `%TEMP%\opencode\island_probe\` 下的实测复现件）
> **输入**：`skills\naraka-highlight-studio\references\{roughcut-launch.md §2.1–§2.8, §3.7, deliverables-and-qa.md}` · `123\workflow_upgrade\{g-shard-merge.md, merge_log_g.md, e5_freeze_gate.md}` · `123\13.849*\reports\merge_decision_v1-partial-r1.md` · `123\19.861*\`（台账 + 全部 `segN_scan_report.md` mtime + `timeline\combat_episodes_v1/v9.json`） · `skills\...\scripts\{qa_gate.py, validate_combat_timeline.py, episode_geometry.py}` · `scripts\{cleanup_after_master.ps1, check_task_hygiene.ps1, read_episode_bounds.ps1, seg_render_master.sh, verify_master.sh}` · `.scratch\efficiency\{05,09}` · `.scratch\oneprompt\{01,02}`

---

## 0. 一页结论

| 项 | 判定 |
|---|---|
| **A. partial「转正」** | **不做。** 禁令一字不动。可机器判定的「转正条件」一旦写成条文，就自动退化成「永不许转正」——因为 partial 的定义就是「有缺席路」，而缺席路 = 覆盖不完整（§3.2 证明）。**要补的不是转正条件，是把这条禁令从"靠人记"变成"靠脚本"** |
| **B. `wip-` 旁路** | **能做，且不需要用户点头**（前提：`wip` 的消费者是 Agent 自己，不是用户 —— 见 §4.3）。这一条**推翻 09 号的 🔴 需点头判定**，理由是它的前提错了 |
| **先做哪个** | **B。但必须和「覆盖门」一起做** —— 因为 B 的前提（wip 不是成品）今天没有任何脚本在守 |
| **顺手捡到的真缺陷** | `validate_combat_timeline.py` 与 `qa_gate.py` **都没有源覆盖门**。实测：把 861 v9 里一场 48.75 秒的真战斗整段删掉，`qa_gate.py` 仍然 `pass: true, fail: 0, exit 0`。**"半成品被当成品"今天不是假想风险，是机器看不见的风险** |
| **对 05 号 1.63 h 的修正** | 算术成立，但**这个数在用户的诉求下价值≈0**（用户明确「不要分段汇报、最后一次性给结论」，提前 8 h 给一份他不会看的文件不省任何东西）。`wip` 在一站式诉求下的真实价值是**提前发现缺陷**，这个收益**无人测过**（§4.1） |

---

## A. 流式合成（岛式合并）

### A.1 三处禁令原文

四处（不是三处，`deliverables-and-qa.md` 还有第五处镜像）：

**① `roughcut-launch.md §2.3` 末句（L69）**
> 全回 + 双证齐 + validate pass 即冻结候选。**字幕员、渲染员、自审员只认冻结版，不认 partial。**

**② `roughcut-launch.md §2.8` 岛定义（L94）**
> 缺席路两侧断面记 pending 缝（`SEAM-<缺席路>L/R`），只出 partial 草稿，永不冻结。partial 命名 `merge_decision_vN-partial-r{k}`（N 为父冻结号，**永不转正**，只能被修线员重算替代；字幕/渲染/自审禁认 partial）。

**③ `roughcut-launch.md §2.6`（L104）**
> 草稿带 `-partial` 后缀，**不冻结、不送字幕渲染自审**；任一边界改动即加版，旧预览作废。

**④（镜像）`deliverables-and-qa.md` L50**
> `reports\merge_decision_vN-partial-r{k}.md` # 岛草稿（g升级）：永不转正、不进字幕渲染自审；任一边界改动即作废重出

**⑤（镜像）`e5_freeze_gate.md §6`**
> `-partial` 后缀仅用于局部合成草稿与相邻预合…不冻结、不送预览验收、不送审；字幕员、渲染员、自审员只认冻结版（沿用 §2.3）

另有两条**间接**同向条文：
- `§2.8` 搭桥：「仅当缺席路回来且与两侧各完成互证，一次性闭合双缝；任一失败则不合拢、不升级冻结版。」
- `§2.8` 台账三态：`FROZEN` 全局唯一，**FROZEN 计数 >1 即锁账停渲染**。

### A.2 当初禁令在防什么 —— 找到那个具体事故

禁令不是凭空写的。它有一条**可追溯的祖先事故**，还有一条**至今仍然生效的机械理由**。两条都查到了。

#### 事故一（祖先，可追溯）：848 `repair-v1` 阻塞 4 轮

`roughcut-launch.md §2.5` 白纸黑字：

> 超时即冻结换 `segNb`，**禁如 848 `repair-v1` 等 4 轮**（教训：**28 路扫描全回后合并 blocked 4 轮才转接管，瓶颈在串行合并不在扫描**）

同一教训在 `d1_parallel_orchestration.md §3.4` L135 与 `e4_parallel_throughput.md` L135 各写了一遍，措辞几乎相同：

> 禁止：原地死等、催原路"再看看"、**把阻塞路的半成品直接合入主线**。

**这就是禁令的直系来源**：848 已经证明「扫描全回之后，合并才是瓶颈」，而且已经因为往主线上塞半成品而付出过 4 轮阻塞的代价。g 升级（`123\workflow_upgrade\g-shard-merge.md` §0）对这件事的定位非常清楚：

> **能回来几路先合几路**：能。1–3 回先合成岛 A…**但这不省合并的总工作量**——省的是"干等"。

也就是说：**岛式合并从设计第一天起就只承诺省"排队时间"，从未承诺省"到第一版的时间"**。05 号 §3.2 结论一（"逃生阀在物理上无法缩短到第一版预览的时间"）说的就是这个设计意图，只是一直没人把它和"用户什么时候看到片子"接上。

#### 事故二（仍然生效的机械理由）：**没有任何脚本能看见一个 partial**

这是我这轮实测出来的，也是本报告最重要的一条。

**探测方法**（复现件在 `%TEMP%\opencode\island_probe\`，可重跑）：

```
1. 取 861 冻结版 timeline\combat_episodes_v9.json（14 场，15 条 deleted_intervals）
2. 模拟「缺席一路」：把与 [1881, 1971)（seg23 路）相交的 episode / deleted_interval 全部剔除
3. 跑 validate_combat_timeline.py  → pass=false，但唯一 FAIL 是 no_holes_in_battle，
   与「未改动的 v9 基线」FAIL 完全相同（v9 基线本来就 FAIL）
4. 跑 qa_gate.py                  → {"pass": true, "fail": 0}，exit=0，17 个门全 PASS/WARN
5. 算源覆盖：union(episodes ∪ deleted_intervals) = 2227.233 s / source_duration = 2399.233 s
   → **172.0 秒的源区间没有任何声明**，洞在 (1800.0, 1972.0)
```

**再做一个更狠的探测**：直接删掉 `combat_005`（48.75 秒真战斗，`[1013.0, 1061.75)`），
`qa_gate.py` 依然返回 `{"pass": true, "fail": 0}`，exit=0。

**结论：`validate_combat_timeline.py` 和 `qa_gate.py` 里都不存在任何"源覆盖"检查。**
我用 ripgrep 逐个确认过：`episode_geometry.py` 只算 program 秒数与洞形，不碰覆盖；`qa_gate.py` 的 17 个门里没有任何一个拿 `source_duration` 去比对 union；`validate_combat_timeline.py` 只用 `source_duration` 做 `end <= duration` 的单边上界检查（第 172 行 `within_source`）。

**为什么 864 那两道门也拦不住**：§8.1 的 `no_holes_in_battle` 与 `no_zero_gap_pseudo_cuts` 判的都是 `excluded_inside` —— 也就是**已声明 episode 内部的洞**。一个缺席路造成的缺口**不是洞，是"没有任何声明"**。这两道门对它是**结构性失明**。这不是巧合：它们是为 864 的"战斗中不许挖洞"设计的，而岛式合并的缺口在拓扑上位于 episode **之间**，两者的数学对象不同。

**所以禁令在防的具体事故是**：一个覆盖不完整的时间线被当成完整时间线冻结、渲染、交付。而这条禁令**今天唯一的 enforcement 是四个 Agent 记得住**，因为：
- `qa_gate.py` 不看文件名，不看台账，不看 `merge_decision` —— 我实测把 island 时间线直接喂给它，它给 PASS。
- 冻结三件套 `combat_episodes_vN.json` 的命名不带任何"这是 island"的标记（partial 只是 `reports\merge_decision_vN-partial-r{k}.md`，**没有对应的 partial 版 JSON**）。
- `scripts\` 与 `skills\...\scripts\` 全库 grep `partial` = **0 命中**（唯一的 `PARTIAL` 是 `sanitize_stray_dirs.ps1` 和 `cleanup_after_master.ps1` 里一个同名无关变量）。

**这就是 §2.3/§2.8/§2.6 三处各自独立写同一句禁令的真正原因**：三处是给三个不同角色（字幕员 / 渲染员 / 自审员）看的**提示层补丁**，因为**没有脚本层**。849 跑出 7 份 partial/draft 时这个事实就已经暴露了，但没人把它归因到"缺一门"。

### A.3 「partial 什么条件下可以转正」—— 为什么这个问题本身是自指的

设想要一个可判定的转正条件 `C`，使 partial 在 `C` 下可以转正。既然 partial 的定义是：

> 岛 = **连续已回路的闭合集合**；缺席路两侧记 `SEAM` 缝。（§2.8）

那么 `C` 至少必须包含「所有缺席路都已回来」。但「所有缺席路都回来」+「双证齐」+「validate pass」= §2.3 的**冻结候选触发器本身**，此时它已经叫 vN，不叫 `partial-r{k}`。

**`C` 一旦写成条文，就自动退化成「永不许转正」。**

这说明：**「永不转正」这条禁令是对的，它不需要改，需要的是把它的 enforcement 从散文变成代码。** 09 号 §4.4 的判断（「把『永不转正』删掉 —— 血统唯一性是版本正确性的地基」）我核实后**完全同意**：`FROZEN 全局唯一` + `一动全废（旧 N 下全部 partial 作废）` 这两条一旦松动，`vN-partial-r1 → vN → vN+1` 的谱系就无法判定"哪一版是当前版"，而 `read_episode_bounds.ps1` 只认 `-v<N>` 一个轴。

**我的修订不是「转正条件」，是「转正禁令的机器化」** —— 一条新的 FAIL 条件，让"覆盖不完整"在脚本层变成不可通过：

```
coverage_complete：
  union( combat_episodes[source_start,source_end) ∪ deleted_intervals[start,end) )
  必须覆盖 [0, source_duration]，容差 0.05 s
  → head gap ≤ 0.05 且 tail gap ≤ 0.05 且 相邻区间间隙之和 ≤ 0.05
  缺 source_duration 字段时判 WARN（不判 FAIL），不得静默 PASS
```

实测四份既有时间线：861 v9 **PASS**（0.000 未覆盖）、861 island **FAIL**（172.0 s）、861 丢战斗 **FAIL**（48.75 s）、864 archive v5 **PASS**（该文件无 `source_duration` → 走 WARN 分支，不会误杀已交付任务）。

**这一条改动零风险、只紧不松、不需要点头，且它单独就能把 §8.1 的头号判据（不漏战）从"靠 7 路对抗审 + 4 遍自审 + 3 路验收人肉兜"变成"脚本兜"。**

### A.4 防呆设计：半成品时间线被当成品冻结

四道闸，前三道是命名/字段，第四道是**唯一不可绕过的**：

| # | 闸 | 位置 | 拦什么 |
|---|---|---|---|
| 1 | **文件名字段标记** | island 产物必须落 `timeline\combat_episodes_vN-island-r{k}.json`，顶层写 `"island": true` + `"seams": ["SEAM-23L","SEAM-23R"]` + `"coverage_complete": false` | 人眼与 `Get-ChildItem` 层面的误认。`check_task_hygiene.ps1` 的 `combat_episodes_v(\d+)\.json$` 正则天然不匹配 island 名，不会被误判成 STALE |
| 2 | **脚本层认名字** | `qa_gate.py` / `validate_combat_timeline.py` 见到 `island: true` 或路径含 `island` / `-wip` → **立即 FAIL**，不进入任何其它门 | 防"喂错文件"（我今天就是这么喂的，它照单全收） |
| 3 | **台账第三态** | `PARTIAL` / `BRIDGED` / `FROZEN` 之外**不加岛态**；`§2.8` 三态表只追加不改 | 防"岛态被当成第四种冻结态" |
| 4 | **渲染入口收口（唯一不可绕过）** | **`read_episode_bounds.ps1` 拒绝任何顶层无 `"coverage_complete": true` 的时间线 JSON** | **这是唯一一处不可逆伤害发生的地方**（4K 成片）。`seg_render_master.sh` 的全部切点都经它。它一拒，partial/island **在结构上无法渲出任何分辨率的成片**，不依赖任何命名约定、不依赖任何 Agent 记得住 |

第 4 条是设计的核心：**护栏要放在伤害不可逆的那一格，而不是放在大家记得住的那一格。** 现有 4K 链路（`seg_render_master.sh` → `read_episode_bounds.ps1` → `episode_geometry`）完全不看台账、不看 `merge_decision`、不看文件名 —— 它只信 JSON。**这既是它今天可靠的原因，也是它今天会被 island 骗过去的原因。** 改一处、只改一处、加一个字段判空，比改五处散文条文有效。

> 顺带核实：`verify_master.sh` **不读 preview 目录**（grep `preview` 只命中一处无关的 `-map 0:v:0`），`freeze_kit.py` 的预览路径是硬编码的 `21-review-{ver}.mp4`。**这两个已经因为命名而不可能被 wip 污染，无需改动。**

### A.5 碰到的现有条文与脚本清单

| 文件 | 现状 | A 方案要碰什么 |
|---|---|---|
| `roughcut-launch.md §2.8` | 三态 + 永不转正 | **不改**。只加一行指向 coverage 门 |
| `roughcut-launch.md §2.3` L69 | 禁认 partial | **要改**（B 的授权位，见 §4） |
| `roughcut-launch.md §2.6` | 草稿不送下游 | **要改**（同 B） |
| `roughcut-launch.md §3.7` | 冻结五门 AND | **要加**：G0 = `coverage_complete`，六门 AND |
| `deliverables-and-qa.md` L50 / 生命周期表 / Freeze gate 节 | partial 命名 + 可删 | **要加** island JSON 与 `preview\wip\` 两行 |
| `qa_gate.py` | 17 门，无覆盖门 | **加 2 门**：`coverage_complete`（FAIL）、`no_island_input`（见到 island 立即 FAIL）。约 25 行 |
| `validate_combat_timeline.py` | 无覆盖门 | **加 1 项 check**。约 15 行 |
| `read_episode_bounds.ps1` | 只认数组，不看顶层 | **加一个字段判空**，拒绝渲染未声明覆盖完整的时间线。约 8 行 |
| `episode_geometry.py` | 只算 program / 洞 | 不动（覆盖率计算放 `validate` 侧，复用它的 `timeline_*` 函数即可） |
| `check_task_hygiene.ps1` | STALE_PREVIEW 正则 `-review-v(\d+)\.mp4$` | **加 1 条**：非 FROZEN 状态下 `preview\wip\` 非空 → 违规；`timeline\*-island-*.json` 残留 → INFO |
| `cleanup_after_master.ps1` | 删 `preview` 整目录 | **不动** —— wip 在 `preview\wip\` 下，出 4K 后自动被清掉。这是白捡的 |
| `seg_render_master.sh` / `verify_master.sh` | 不读 preview | 不动 |
| `freeze_kit.py`（864 任务目录内） | 预览名硬编码 `-review-` | 不动（命名已隔离） |
| `scripts\test_whole_battle_gates.sh` | 覆盖 864 两门 | **加 3 个回归用例**：island 必须 FAIL、丢战斗必须 FAIL、正常 vN 必须 PASS |

---

## B. `wip-` 预览旁路

### B.1 核实 05 号的 1.63 h —— 算术对，口径错

**算术复核（全部用文件 mtime，不采信台账自述）**：

```
T0          = 2026-09-29 18:07:22   （台账 T0 目录创建 18:07:08 / extract_1fps.py 18:08:46）
v1 预览可看 = 2026-09-30 04:10:06   （timeline\program_map_v1.json mtime）
→ 10.047 h ≈ 10.05 h                ✓ 与 05 号一致

seg16（第 26 路）落盘 = 19:15:06
19:15:06 + 30 min（草稿+渲染假设） = 19:45:06
19:45:06 − 18:07:22 = 1.63 h         ✓ 与 05 号一致
```

**算术没问题。但有两处它没说清：**

**① 「30 分钟」是假设，不是实测。** 861 的真实数字：末路 seg29 落盘 03:09:26 → `merge_decision_v1.md` 04:03:26（**54 分钟**合并 29 路）→ `program_map_v1.json` 04:10:06。台账自述渲染耗时 368.3 s（6.1 min）。**26 路的 partial 合并不会比 29 路的全量合并更快到 30 分钟以内**，合理区间 30–55 min。所以更诚实的首版时间是 **2.2 – 2.7 h**，省 **7.4 – 7.9 h**，不是 8.42 h。

**② 更关键：这个「触发点」其实可以更早。** §2.3 的触发器是「回半数即全量草稿」。数 861 的 `segN_scan_report.md` mtime：**第 15 路（半数）落在 18:42**（T0+35 min）。所以一个按 §2.3 字面执行的 `wip` 触发点应该在 ~18:42，比 05 号用的 19:15 还早 33 min。**05 号取了最保守的那个点。**

**③ 但真正的问题在口径本身。** 05 号的 8.42 h 省的是「用户更早看到一份文件」。而 `docs\粗剪提示词.md` L27 白纸黑字：

> 中间出几版、推几轮我不在乎，**不要问我，不要分段汇报，最后一次性给结论**。

**在用户的实际诉求下，「提前 8 小时给一份他不看的文件」节省的是机器的墙钟，不是用户的等待 —— 而用户根本不在这条路径上。** 01 号 §5.4 的判定「粗剪预览真的能做到零用户介入」成立，正因为零介入，所以**任何以"让用户早点看到"为目标的改造，其收益在用户侧恒等于零**。

`wip` 在一站式诉求下唯一真实的价值是另一件事：

> **让 Agent 自己在冻结之前就能看片。**

864-att1 的整局否决、864 v6「门禁全绿但仍被整局重剪」（`AGENTS.md §8.1`）、861 从 v1 滚到 v9（12.5 h）—— 这些失败的共同形态是**缺陷要到很晚才被发现**。`wip` 把「看片」这个动作从 v9 提前到 26/29 路，成本只是一次渲染（+6 min）。**这个收益没人测过**（05 号 / 09 号都没算它），所以我不能替它标价；但它是 `wip` 在本项目诉求下**唯一站得住的理由**，也是我建议保留 `wip` 的唯一理由。

### B.2 05 号的 8.42 h 我不采信为决策依据

不采信不等于数字错，是**它衡量的不是用户要的东西**。用它去排序 ROI（`10-roi-ranking.md` 把 C2 排到 ROI 第 5、值 8.4 h、标「硬点头」）会让改造顺序被一个假指标带偏。**正确的指标是：缺陷发现时间提前了多少小时。** 这个数现在测不出来 —— 需要至少一局实跑。

### B.3 风险与防呆：把「不拿给用户看」变成机制而不是纪律

09 号 §5.2 列了四条泄漏路径，风险①（用户误认）判「高」并因此判 🔴 需点头。**我认为这个判定的前提是错的**：它假设 `wip` 是给用户看的。既然用户明确「不要分段汇报」，那 `wip` 的消费者就应该是 **Agent 自己**（§3.6 对抗审 / §3.1 自审的输入），而不是用户。**一旦不拿给用户看，风险①在定义上就不存在。**

| 泄漏路径 | 09 的判定 | 我的判定与手段 |
|---|---|---|
| ① 用户把 wip 看成成片并据此给意见 | 高 | **归零** —— `wip` 的唯一消费者写进条文：自审员 / 对抗审员，**不进交付清单、不进对话汇报**。用户侧看到它的唯一可能是自己翻任务目录，为此仍做目录隔离 |
| ② QA / 验收误吃 wip 当依据 | 高 | 保留并加强。`wip` 渲在 `preview\wip\19-wip-r2.mp4`，`qa_gate.py --preview` 见到路径含 `wip-` → exit 2；冻结门禁表加一行「送审清单 `wip-` 文件数 = 0」 |
| ③ 成片从 wip 放大渲染 | 不可逆 | **已天然免疫 + 再加断言**：`seg_render_master.sh` 不读 preview 目录（已核实）；`read_episode_bounds.ps1` 字段收口后连 island 时间线都渲不了 |
| ④ wip 残留被当成现行版 | 中 | `preview\wip\` 整个目录：`FROZEN` 落地即清；`check_task_hygiene.ps1` 加「非 FROZEN 下 wip 目录非空 → 违规」；`cleanup_after_master.ps1` 出 4K 后删 `preview` 整目录时**自动带走**（白捡，零改动） |

**加两条 09 没提的：**

- **⑤ `wip` 目录必须是子目录 `preview\wip\`，不能是 `preview\` 平铺。** 09 §5.3 提到了但归在"缓解"里。**它应该是硬规则** —— `check_task_hygiene.ps1` 的 `STALE_PREVIEW` 用 `Get-ChildItem -File`（非递归）扫 `preview\`，子目录天然不在扫描范围，所以平铺的 `19-wip-r2.mp4` 会被误当成一个"没被认出的版本"而长期滞留；放子目录则零干扰。
- **⑥ 零烧录。** AGENTS §5 的禁令是**禁烧字幕**（"MP4 内零字幕流、零烧录像素字"）。09 号提出用 `drawtext` 烧一个 `PARTIAL · NOT FREEZABLE` 横幅，并自认"为避免争议，优先用文件名 + 播放器标题元数据，drawtext 仅作兜底"。**我的建议更保守：默认不烧，一个像素都不烧。** 标记靠文件名 `wip-` + `preview\wip\README.md` + 台账 `PARTIAL-WIP` 状态行。理由：AGENTS §5 的字面表述是「零烧录像素字」，烧横幅需要再去 AGENTS §5 加一句例外，**为一层本可不需要的保险去改项目铁律，是净负债**。而且 §8.2 结论 3 已经给了更强的护栏（成片根本不读 preview）。

### B.4 05/09 都没解的关键矛盾：不打扰用户 & 拿到早反馈

矛盾的实质是：**`wip` 要被"看"，而用户说了不要分段汇报。**

解法是把"看"这个动作从**用户**转移到**Agent**，并且让这个转移是**结构性的**而不是靠自觉：

1. **`wip` 的消费者写进条文，不写进提示词。** §2.3-wip 新增：`PARTIAL-WIP` 预览的唯一合法消费者是**自审员（§3.1）与对抗审员（§3.6）**；`docs\粗剪提示词.md` **一个字都不改**。提示词管"对用户说什么"，references 管"Agent 之间说什么" —— 这与 02 号 §7「刻意不写进提示词的东西」的分工一致。
2. **触发点挂在台账数字上，不挂在"要不要汇报"上。** §2.3 的「回半数即全量草稿」触发器本来就存在，只是产物无人消费。给 `PARTIAL` 态挂一个 `PARTIAL-WIP` 消费者，**指挥不需要做任何新决策、不需要判断"现在适不适合给用户看"** —— 它根本不给用户看。
3. **`wip` 不是"一版"，是"一次提前的自审输入"。** 对抗审按节目轴切 60–90 s/路，本来就要把整条节目轴过一遍；给它一份 26/29 路的岛，它能提前发现的是**跨岛接缝处的战斗断裂**和**缺路口两侧的边界可疑点** —— 这两类恰好是 §8.1 R2-2「场边界本身也在切」最易失守的地方。**这是 wip 唯一真正划算的用法：它让"边界"在冻结前就被多看一遍。**
4. **对用户侧零新增。** `wip` 不出现在 `preview\` 根、不进 `dispatch_ledger` 的对外投影、不进交付报告的六项、不被 `cleanup_after_master.ps1` 之外的任何东西引用。用户收到的仍然只有一句话触发 → 一次性结论。

---

## C. 判断

### C.1 能不能做

| | 判定 | 碰到的现有条文 / 脚本 |
|---|---|---|
| **A. partial 转正** | **不做，且认为这条禁令不该动。** 改为「转正禁令机器化」：加 `coverage_complete` FAIL 门 | `qa_gate.py`（+2 门）、`validate_combat_timeline.py`（+1 check）、`read_episode_bounds.ps1`（+1 字段判空）、`test_whole_battle_gates.sh`（+3 回归）、`roughcut-launch.md §3.7`（G0）、`deliverables-and-qa.md` Freeze gate 节。**`§2.8` / `§2.6` 的 partial 条款一字不改** |
| **B. `wip-` 旁路** | **能做。** 三处条文各加一个例外 + 一个新角色（预览员）+ 一个新目录 | `roughcut-launch.md §2.1`（角色表 +1 行）、`§2.3`（末句改写 + 新增 §2.3-wip）、`§2.6`（单写者矩阵 +1 行）、`§2.8`（岛定义末句 + PARTIAL-WIP 态）、`deliverables-and-qa.md`（命名 + 生命周期 + Freeze gate 各 +1 行）、`qa_gate.py`（`--preview` 拒 wip）、`check_task_hygiene.ps1`（+1 条）。**`cleanup_after_master.ps1` / `seg_render_master.sh` / `verify_master.sh` / `freeze_kit.py` 零改动** |
| **两者关系** | **A 是 B 的前提，B 是 A 的收益。** 没有 coverage 门，B 就是在造一个"看起来像成品、机器认不出、只有人记得它不是"的文件 —— 那正是 A.2 实测出来的现状 | |

### C.2 需不需要用户点头

**两项都不需要。** 理由分列，因为它们的"需点头"判定此前被两篇报告搞错了：

**B（`wip`）—— 不需要，且这是对 09 号 🔴 判定的更正。**
09 号判 🔴 的理由是「用户会直接看到 wip 预览并可能据此给意见」。**在用户的实际诉求下这个前提不成立**：他明确说了不要分段汇报、不要问、最后一次性给结论 —— 他**看不到** `wip`。而"让 Agent 自己提前看片"完全落在提示词已预授权的自主权范围内（「遇阻塞且能保守收敛，就收敛后照常交付」「中间所有轮次只写文件」）。
**它不改变任何对外可见面**：不新增用户可见文件、不新增汇报、不改交付物清单、不改提示词、不写 E 盘、不装环境。
唯一需要注意的是：**如果将来有人想把 `wip` 拿给用户看，那一刻才需要点头** —— 我在条文里写死「`wip` 不得出现在交付清单与对话汇报中」，把这次点头的边界留在未来那一刻。

**A（coverage 门）—— 不需要。**
它只增加 FAIL 条件、只收紧不放宽、不改任何交付格式。属于 09 号 §6 判为 🟢「纯内部机制」那一类。（对比：`render.auto_start_authorized` 那条要点头，是因为它会在用户离开后向 `E:\Cujian导出` 写 1.4–2.6 GB 并触发删任务目录 —— A、B 都不碰这个面。）

**唯一需要提前告知的（不是点头，是通知）**：`coverage_complete` 落地后要**回跑四份既有任务的时间线**。861 v9 / 863 / 864-att2 预期 PASS；若某份 FAIL，那是**发现了一个已交付成片的漏战**，性质从"加个门"升级为"要开一轮复审"。这个可能性必须提前说清楚，不能等门禁报红再解释。**建议顺序：先只读回跑、把结果落 `reports\`，确认无回归再把门写进 `pass` 判定。**

### C.3 只做一项，先做哪个

**先做 B，但把「coverage 门」当成 B 的第一块砖一起砌。**

顺序与理由：

1. **coverage 门先行（半天，独立可验证）。** 它是 B 的安全前提，也是**唯一一个今天就在漏的缺陷**（我实测 `qa_gate.py` 对"删掉一场 48.75 s 真战斗"的时间线给 `pass: true`）。它单独就有价值，与 `wip` 无关 —— 即使 B 最后不做，这一门也该加。
2. **`wip` 随后（1–2 天）。** 它是四项改造里唯一直接缩短"缺陷发现时间"的。风险已被四条护栏 + 目录隔离 + 命名收口压到可控。
3. **A 的"转正"部分永久不做。** 不是排后面，是**判定为不该做**（§A.3 自指论证 + 血统唯一性）。

**如果只能做一件事**（时间/预算极端受限）：做 **coverage 门**。理由 —— `wip` 省的是墙钟（用户无感），`coverage 门`堵的是"漏战被机器放过"（用户直接受害，且 864 已证明这一类失败一次就要整局重剪）。**先堵会出事的洞，再省不痛的时间。**

**明确不做**（避免被顺手加进去）：
- 不删 `§2.8` 的「永不转正」/ 不让字幕员·自审员·验收员·成片渲染员认 partial（禁令从四角色收窄为**零**角色变宽，正确做法是**只新增预览员**）。
- 不废岛式合并（它在 `offline 岛` 场景 —— 抽帧被清理后需补扫的区块 —— 仍有真实价值，且是 §2.5 换路"新旧择优合入"的载体）。
- 不把 `wip` 加进 `docs\粗剪提示词.md`（02 号 §7 的分工：提示词只管对用户说什么）。
- 不烧 `drawtext` 横幅（§B.3⑥）。

---

## 4. 可直接替换进 `roughcut-launch.md` 的规则文本

> 下列文本**风格与现有条文一致**（短句、祈使、禁例用"禁止/禁"），
> §2.3 / §2.6 / §2.8 三处**只做加法与末句改写，不删旧条**（沿用 `merge_log_g.md §2.2` 的合入纪律）。

### 4.1 替换 `§2.3` 末句（原：「字幕员、渲染员、自审员只认冻结版，不认 partial。」）

> 字幕员、渲染员、自审员、验收员、成片渲染员只认冻结版，不认 partial。**唯一的例外是 §2.3-wip 的 `PARTIAL-WIP` 旁路，它只对预览员开放，且产出的 `preview\wip\` 文件不是"一版预览"。**

### 4.2 新增 `§2.3-wip`（插在 §2.3 之后、§2.4 之前）

> #### §2.3-wip `PARTIAL-WIP` 旁路（预览员的唯一授权，2026-10-05）
>
> - **目的**：让"扫描回来不齐"不再等于"干等到全齐"。岛草稿 `merge_decision_vN-partial-r{k}` 照旧**永不转正、不进下游**；本节只增加一条**只读旁路**，不改变任何质量门。
> - **消费者只有一个**：**预览员**。它的产出只允许被 **§3.1 自审员**与 **§3.6 对抗审员**当作提前自审输入。**字幕员、验收员、复验员、成片渲染员、`qa_gate.py`、`freeze_kit`、`verify_master.sh` 一律不认。**
> - **落点**：`preview\wip\<序号>-wip-r<k>.mp4`，720p、review 同规格、**从源重渲**（分段复用规则同 `deliverables-and-qa.md`，禁从 preview 放大）。**必须是 `preview\wip\` 子目录，禁止在 `preview\` 平铺**（平铺会被 §2.7 的卫生检查当成版本残留长期滞留）。
> - **零烧录**：wip 画面与 review 一样干净。**禁止任何 `drawtext` / 水印 / 状态字**（沿用 `AGENTS.md §5`）。状态标记只靠文件名 + 台账 `PARTIAL-WIP` 行 + `preview\wip\README.md`。
> - **台账**：`PARTIAL` 行派生一行 `PARTIAL-WIP`（只追加，不改旧行），写明 `r{k}`、覆盖路集合、缺席路 `SEAM` 列表、未覆盖源秒数。`PARTIAL-WIP` **不是第四态**，不进 `FROZEN` 计数。
> - **触发**（自动，不需请示、不需判断"要不要给用户看"）：`§2.3` 六档触发器的「回半数即全量草稿」与「缺路成岛」两档产出 `PARTIAL` 时，**必须**同时派一路预览员出 `wip`。不得因"还没冻结"而不派。
> - **四条泄漏拦截（缺一即实现不合规）**：
>   1. `qa_gate.py` 与 `validate_combat_timeline.py` 的 `--preview` / timeline 输入路径含 `wip-` 或 `-island` → **exit 非 0**，不进入任何其它门。
>   2. `check_task_hygiene.ps1`：非 `FROZEN` 状态下 `preview\wip\` 非空 → 违规；`timeline\*-island-*.json` 残留 → INFO。
>   3. `read_episode_bounds.ps1` 拒绝顶层无 `"coverage_complete": true` 的时间线 JSON —— **wip/island 时间线在结构上渲不出任何分辨率的成片**（`seg_render_master.sh` 的全部切点经它）。
>   4. `freeze_gate_<序号>_v<N>.md` 送审清单新增一行「**`wip-` 文件数 = 0 且 `*-island-*` 数 = 0**」，非 0 即该门 FAIL。
> - **生命周期**：`partial-r{k+1}` 落盘或任一 `FROZEN` 落地即删 `preview\wip\` 整目录；出 4K 后由 `cleanup_after_master.ps1` 删 `preview\` 时自动带走（无需额外改动）。
> - **不进对话**：wip **不得**出现在任何给用户的汇报、交付清单六项或 `docs\粗剪提示词.md` 的最后报告里。把 wip 拿给用户看需要用户单独点头 —— 该点头留到那一天。

### 4.3 `§2.8` 岛定义末句追加（不动「永不转正」四字）

> - **岛定义（追加）**：岛草稿仍**永不转正**、不进 `timeline/`、不作 QA 依据（此条不动一字）。岛草稿若要落到时间线，只能落 `timeline\combat_episodes_v<N>-island-r<k>.json`，顶层必写 `"island": true` + `"seams": [...]` + `"coverage_complete": false`，且**不得**被 `seg_render_master.sh` / `read_episode_bounds.ps1` 读入（见 §2.3-wip 第 3 条）。**岛的时间线永远渲不出成片，这不是纪律，是字段判空。**

### 4.4 `§2.6` 单写者矩阵追加一行

> - **预览员**（wip 旁路，唯一授权 `PARTIAL-WIP`）：只写 `preview\wip\<序号>-wip-r<k>.mp4` + `preview\wip\README.md` + 台账 `PARTIAL-WIP` 行。**禁止**碰 `timeline/`（含 island JSON）、禁止碰 `captions/`、禁止交任何验收角色、禁止进交付清单、禁止烧任何像素字、禁止 4K。草稿带 `-partial` 后缀，不冻结、不送字幕渲染自审；任一边界改动即加版，旧预览作废。

### 4.5 `§3.7` 冻结门禁加 G0（六门 AND）

> - **G0 源覆盖完整**（`coverage_complete`，新增，排在 G1 之前）：`union(combat_episodes ∪ deleted_intervals)` 必须覆盖 `[0, source_duration]`，容差 **0.05 s**（head gap / tail gap / 相邻间隙之和，三者各判）。`source_duration` 字段缺失判 **WARN 不判 FAIL**（不得静默 PASS）。**脚本实跑来源：`validate_combat_timeline.py` 的 `coverage_complete` 项与 `qa_gate.py` 的同名门，两者任一 FAIL 即 `NOT_FROZEN`。**
> - 冻结定义改为六门AND：`冻结 vN ≡ G0 ∧ G1 ∧ G2 ∧ G3 ∧ G4 ∧ G5`。G0 的动机：**§2.3/§2.8/§2.6 三处"partial 禁认下游"的禁令，其 enforcement 原本只有散文** —— 实测把一条含真战斗的 episode 整段删掉，两个脚本仍给 `pass: true`。**"缺席一路"在拓扑上不是 `excluded_inside` 洞，`no_holes_in_battle` 与 `no_zero_gap_pseudo_cuts` 对它结构性失明。** G0 是那道缺的机器。
> - 回归：`scripts\test_whole_battle_gates.sh` 必须覆盖三个用例 —— 岛时间线（缺一路）**FAIL**、被删掉一场真战斗的时间线 **FAIL**、正常 vN **PASS**。三个用例任一不成立，G0 不算落地。

### 4.6 `deliverables-and-qa.md` 追加（命名节 + 生命周期表 + Freeze gate 节）

> ```
> timeline\combat_episodes_v<N>-island-r<k>.json  # 岛时间线（2026-10-05）：顶层 island=true + coverage_complete=false；
>                                                  #   永不冻结、永不送 QA、永不可被 read_episode_bounds.ps1 读入；可随时删
> preview\wip\<序号>-wip-r<k>.mp4                    # PARTIAL-WIP 旁路（2026-10-05）：只给自审员/对抗审员当提前自审输入；
>                                                  #   零烧录；不进 QA/验收/交付；下一 partial 或 FROZEN 落地即删
> ```
>
> 生命周期表补两行：岛时间线 = **可删**（下一 `partial-r{k+1}` 或 `FROZEN` 落地即删，结论已被吸收）；`preview\wip\` = **可删**（同上；且出 4K 后随 `preview\` 整目录由 `cleanup_after_master.ps1` 清掉）。
> Freeze gate 节补一句：**送审清单必须 `wip-` 数 = 0 且 `*-island-*` 数 = 0**，非 0 判 FAIL；G0 覆盖门并入冻结定义（细则见 `roughcut-launch.md §3.7`）。

### 4.7 `roughcut-launch.md §2.1` 角色表追加一行

> | **预览员（wip 旁路）** | 只把岛草稿渲成**明确不可冻结**的 `preview\wip\` 预览，供自审/对抗审提前看 | `preview\wip\<序号>-wip-r<k>.mp4`（720p，零烧录）+ 台账 `PARTIAL-WIP` 行 | 禁止碰 `timeline/`（含 island JSON）；禁止交字幕/验收/成片渲染；禁止进交付清单与对话汇报；禁止 4K；禁止任何烧录像素字 |

---

## 5. 已知不足与未验证项（不粉饰）

| 项 | 状态 |
|---|---|
| `wip` 的真实收益（缺陷发现提前多少小时） | **未测。** 需要至少一局实跑对比。§4.1 的 1.63/2.2–2.7 h 是"用户早看到"，在用户诉求下无价值；真正要测的是"第几版才发现跨岛接缝问题" |
| `wip` 合并耗时 | **未测。** 861 的 54 min 是 29 路全量合并，26 路的岛合并可能更慢。`§2.3-wip` 的触发点写死为"回半数"，但没有时限保护 —— 若半数迟迟不来，wip 也不出 |
| `coverage_complete` 的回归风险 | **需先只读回跑。** 861 v9 已实测 PASS；863 / 864-att2 / 864-att1 归档版**未逐一回跑**。若某份已交付任务 FAIL，性质是"发现已交付成片漏战"，须开复审而非当作回归回退 |
| 0.05 s 容差 | 沿用 `SUM_TOLERANCE_S = 0.01` 与 `PREVIEW_DURATION_TOLERANCE_S = 0.3` 的量级，取 0.05 是折中。**未在四份真实时间线上标定过误报率** |
| `wip` 的看图预算 | **未算。** 对抗审员看 wip 与看 review 是两次独立预算，两次都受 `AGENTS.md §9` 的 50 张累计红线约束。**若 wip + review 双跑导致超限，本改造反而会触发会话作废** —— 这是我看到的最大未识别风险，实现前必须先跑 `scripts\check_image_budget.ps1` 按双跑场景排轮 |
| 「烧不烧状态字」 | 我的建议是**不烧**，理由见 §B.3⑥。若将来决定烧，须先改 `AGENTS.md §5` 加例外 —— 那一步才是需要点头的 |
| `preview\wip\README.md` | 目录内容未设计。最小内容：当前 `r{k}`、覆盖路集合、`SEAM` 列表、未覆盖源秒数、"本目录任何文件不是预览版本、不得作 QA 依据、不得交付" |