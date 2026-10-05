# 04 · 漏战检测门设计（可行性确认）

> 本轮只做复核与设计，**未改任何项目文件**。所有数字都是本机实跑，不是推断。
> 环境：`check_video_environment.ps1` → `SUMMARY: ok=9 warn=1 blocker=0`，
> Python `C:\Project\永劫无间\.video-tools\venv\Scripts\python.exe`（3.12.10）。

---

## 1. 复核结论：实测成立，而且比上报的更严重

用 `docs\lessons\examples\864_v6_combat_episodes.json`（7 场、program 661.06 s、源 1152.233 s）造了 5 个变体，跑
`skills\naraka-highlight-studio\scripts\qa_gate.py`。

| 变体 | 做了什么 | qa_gate 结果 |
|---|---|---|
| `base` | 原样 | `pass:true, fail:0`（基线） |
| `del_ep002` | **整场删掉 `combat_002`**（24.73 s，`engage_start` 320.3、`outcome_time` 338、`event_types=[escape,kill,loot]`） | **`pass:true, fail:0`** |
| `del_ep007` | **整场删掉 `combat_007`**（86.75 s） | **`pass:true, fail:0`** |
| `hole48` | 在 `combat_009` 战斗中挖 **48.75 s 洞** `[900,948.75]` | **`pass:true, fail:0`**，仅 `no_holes_in_battle` 给 **WARN**（加上 `"whole_battle_policy":"864"` 才转 FAIL，实测 `pass:false`） |
| `hostile_del` | 删掉 `combat_002` **并把它声明成 `deleted_intervals`**，同时**重算 `program_map` 的 `program_seconds_total`→636.33** | **`pass:true, fail:0`** |

`validate_combat_timeline.py` 在 `hostile_del` 上同样 `pass:true, episodes:6`。

**关键补充（上一位 Agent 没测的那一半）**：`hostile_del` 这一行才是要害。
任何真实自动化都会顺手把自己删掉的区间登记进 `deleted_intervals`、顺手重算 program map。
一旦如此，**`program_sum` 这道唯一的时长交叉校验也被一起喂饱了**，全绿。
换句话说：**「自洽的谎言」能完整通过现有全部门禁**，这才是漏战风险的真实形态。

结论：漏战机器确实抓不住，而且不是「少一扇门」，是**现有 17 扇门里没有一扇读过 `deleted_intervals`**。

---

## 2. 为什么抓不住 —— `qa_gate.py` 全部门禁的射程

源码级事实：`'deleted_intervals' in qa_gate.py` → **False**。它连这个字段的名字都没出现过。
`--source-duration` 只从命令行取，从不读时间线 JSON 里的 `source_duration`。

现有 17 个 check，按「能抓 / 抓不住」分：

### 能抓（都是**内部一致性**错误，不是**语义漏战**）

| check | 抓什么 | 抓不住什么 |
|---|---|---|
| `timeline_mutex` | episode 之间重叠 | 少一个 episode（重叠只会更少，不会更多） |
| `source_range` | `end<=start`、`end>源时长`、最短段 <1 s | 中间缺一大段 |
| `in_segment_holes` | 洞越界 / 非正长度 / 吞掉整场 | 洞挖在战斗窗口内（G-1 接手） |
| `no_holes_in_battle` | `excluded_inside` 落在 `(engage_start, outcome_time)` 内，默认 **WARN** | **整场消失**（不是洞，是缺席）；且默认 WARN 会被忽略 |
| `no_zero_gap_pseudo_cuts` | 相邻两场 `source_end == 下一场 source_start`（空切） | 两场之间插进一段被删的战斗 |
| `program_sum` | 时间线总时长 vs `program_map` header | **program map 被同步重算之后**（实测 `hostile_del`） |
| `preview_duration` / `av_sync` / `frame_rate` | 成片容器事实 | 需要真渲一版；且一样只对「文件对不对」，不对「内容漏没漏」 |
| `subtitle_*` / `no_burned_variant` / `no_subtitle_stream` | 字幕合规 | 与漏战无关 |
| `proxy_map` / `workspace_hygiene` / `freeze_kit` / `media_filters` | 路径与落盘齐全 | 与漏战无关 |

### 抓不住（= 漏战的全部形态）

1. **整场战斗从 episodes 里消失**，且没人补 `deleted_intervals` → `del_ep002` / `del_ep007` 全绿。
2. **整场消失 + 补了 `deleted_intervals` + 重算 program map** → `hostile_del` 全绿。**这是自动化必然踩的那一步。**
3. **战斗窗内挖大洞**（48.75 s）→ 只 WARN。
4. **两个真战斗被合并成一场**（`merge` 反向操作）→ 无门：`timeline_mutex` 只管重叠，不管「本该是三场」。
5. **`deleted_intervals` 谎报类别**（把战斗标成 `traversal_loot_ui`）→ 全场无人核对。历史 423 条删除段里只有 79 条带 `evidence[]`、24 条带 `disposition` 散文，**其余是裸区间**。
6. **场首已在打**（`source_start` 落在战斗中）→ 无门。
7. **场尾未走完**（`source_end` 切在「拉开→补给→再进场」中间）→ 无门。

一句话：**现有门禁验的是「这份 JSON 内部和它自己的渲染是否自洽」，不是「这份 JSON 是否忠于源素材」。**
漏战是后一个问题。

---

## 3. 三条路径的可执行判据

设计前提（三条都遵守，理由见 §4）：

> **门禁只在「纸面缺失」上 FAIL，绝不在「机器的语义结论」上 FAIL。**
> 命中信号 = **要求一份署名裁决**，不是宣布「这里有战斗」。
> 这是 `.scratch\efficiency\10-roi-ranking.md` L-354 与 04 号 Agent 警告的同一件事，我把它做成结构。

### G-C1 `coverage_complete` —— 未声明的空隙（唯一可判 FAIL 的那条）

```
covered = union( [source_start, source_end) for each episode ]        # 原始范围，含洞
                ∪ [start, end) for each deleted_intervals[] ]
判据：head_gap ≤ tol 且 tail_gap ≤ tol 且 Σ 相邻间隙 ≤ tol
源时长 sd = timeline.source_duration（缺失则回落 --source-duration；两者皆无 → WARN，禁止 PASS）
tol = max(0.25, timeline.coverage_tolerance_s)
```

- 状态：**FAIL**（未声明空隙）/ **WARN**（拿不到 `source_duration`）/ PASS
- 实测回归（**这一条必须先说**）：对项目全部 **35 份历史时间线**跑本判据，**零 FAIL、零间隙**（容差 0.05 s 口径）。
  → **新增这道门对已交付任务零回归风险**，这是它可以判 FAIL 的唯一理由。
- 命中效果：`del_ep002` → 抓（间隙 24.73 s）、`del_ep007` → 抓（86.75 s）。
- **抓不到**：`hostile_del`（缺口被补成 `deleted_intervals`）、`hole48`（洞在 episode 内部，属 G-C1 管不到）。
  → 所以 G-C1 不是终点，是 G-C2 的前提：它保证「所有不在片里的秒，都有一个人签字说该不在」。

### G-C2 `deleted_voice_audit` —— 删除段战斗词扫描（**缺席审查**门，不是缺席战斗门）

```
对每条 deleted_intervals[i]：
  hits = 语音战斗词扫描( source.srt / source_transcript.json, [start,end) )
  strong = hits ∩ {杀,大招,打我,打你,打药,拉药,血量,敌人,绝泰圈,钩,打不过,打不}
  if strong:  必须存在一份署名裁决记录，逐条覆盖 [start,end)
             记录格式：reports/deleted_audit_v<N>.md 内有
                       "| [start, end) | 命中: <词> | 结论: 无战斗/有战斗 | 审计员: <名字> | 证据: <路径> |"
  缺记录 → FAIL；  有记录 → PASS（**不管它结论是什么**）
  顺带产出 measured，供人看
```

- 状态：**FAIL**（命中却无裁决记录）/ PASS（无命中，或命中且已裁决）
- 实测检出率（把 v6 每一场分别整段删掉，看扫描能否命中）：
  **任意战斗词 7/7 命中；strong 词 4/7。**
  漏的三场是 `combat_002`（只有「逃跑」）、`combat_005`（「快摘快摘」）、`combat_007`（「给我三把武器」）。
  → **所以关键词表不能当探测器用，只能当触发器用**，这正是「缺席审查」门的形态。
- 实测误报面：已验收的 v6 里 `[0.0,181.0]` 这条**正确**的删除段有 **5 条 strong 命中**
  （「杀包」「大招应该也用不了吧」…）。**若做成「命中即 FAIL」，会把用户已验收的 v6 判死。**
  → 这条数据是「必须做成缺席审查门」的直接证据。
- **音频不进这道门**。`analysis\audio_activity.json` 实测：`combat_002`（真战斗，被删就会漏）
  `frac_p75=0.04`，与真删除段 `[444,495]` 的 `0.04`、`[0,181]` 的 `0.06` 完全重叠。
  `deleted_audit_v1.md §4` 已独立记过同一条（「D4 peak_max −0.29 dBFS ≈ combat_002 0.00 dBFS」）。
  → 音频在本素材**无判别力**，只能进 `measured` 当线索，绝不参与状态判定。

### G-C3 `episode_head_engagement` —— 首帧已经在打

```
对每场 ep：
  off = min(ep.impact_points) - ep.source_start      # impact_points 缺失 → 跳过该场，记 WARN
  if off <= 0.0:  必须有 ep.head_adjudication 记录（帧路径 + 结论）；缺 → FAIL
  if off <= 0.5:  同上，但缺记录只记 WARN
  另有反向触发：off >= 8.0 且 ep 前紧邻 deleted_interval > 15 s
                 → WARN，提示「这段前置跑图可能本属同一场，往前扩」
```

- 状态：见上（FAIL 仅在 `off<=0.0` 且无记录）
- 实测基线（409 场历史）：`off<=0.0` **2 场**、`off<=0.25` 10 场、`off<=0.5` 16 场。
  → 阈值取 **0.0** 时误报面 0.5%，可判 FAIL；取 0.5 s 就是 4%，只能 WARN。
- **量纲踩坑（必须写死，否则这条门会算错）**：`lead_in = source_start - engage_start`
  在**全部 409 场里恒为负**（中位 −4.5 s），因为 schema 规定 `engage_start` 在场**内**。
  所以「前置战斗」的量只能是 `impact_points[0] - source_start`，**不能**用 `lead_in`。
- 已知那 2 场 `off==0.0` 是 859 的 `combat_009`，已验收交付 → 所以 G-C3 的 FAIL 仍然只能落在
  「缺 `head_adjudication` 记录」上，不能落在「off 数值小」上。

### G-C4（补丁，必做）`deleted_audit_evidence_present`

`validate_combat_timeline.py` 现有 `deleted_intervals_audit_present` 只判「列表非空」，
423 条里 344 条无 `evidence[]` 也能过。**改成：每条 `deleted_intervals` 必须带 `evidence[]` 或
`disposition`；缺失 → WARN**（历史 344 条会命中，故只能 WARN；要升 FAIL 必须走
`--automation-mode` 或时间线顶层 `"coverage_gate_strict": true` 显式 opt-in，
与 `whole_battle_policy: "864"` 同一套先例）。

---

## 4. 门禁哲学：宽于或等于真相 —— 每扇门的误报条件

项目已栽两次「门禁严于真相」：861 `preview_duration` 假 FAIL、864 `verify_master.sh` 无音轨假 FAIL。
因此下面每条都写明**它会在什么情况下冤枉一条正确的线**。

| 门 | 误报条件（实测/推导） | 缓解 |
|---|---|---|
| `coverage_complete` | ① `source_duration` 字段被四舍五入到 0.1 s → 尾部天然差 ≤0.05 s；② 片尾故意留黑不入片但没登记 `deleted_intervals`；③ 源文件比 probe 短（录屏尾部截断），`source_duration` 取大了 | tol 默认 **0.25 s**（15 帧）不是 0.05；可用 `coverage_tolerance_s` 放宽；②③ 属「必须声明」的真实缺失，不算冤枉 |
| `deleted_voice_audit` | 已验收 v6 的 `[0,181)` 有 5 条 strong 命中（实测）→ 若做成「命中即 FAIL」直接误杀用户已验收版本 | **缺席审查门**：命中只要求裁决记录，记录写「无战斗」也 PASS。门永不说「这里有战斗」 |
| `episode_head_engagement` | `off<=0.5` 有 4% 场次（16/404，实测），其中含 859 已验收的 `combat_009` | FAIL 阈值钉在 `off<=0.0`（0.5%）；且 FAIL 条件是「缺 `head_adjudication` 记录」，不是「off 小」 |
| `deleted_audit_evidence_present` | 423 条历史里 344 条无 `evidence[]` → 直接 FAIL 会把 6 个已交付任务全部打红 | 默认 **WARN**；FAIL 需显式 opt-in |
| 音频派生任何门 | `combat_002` 与真删除段 `frac_p75` 完全重叠（0.04 vs 0.04/0.06） | **音频不进状态判定**，只进 `measured` |

**贯穿全部四扇门的一条铁律**（建议写进 `qa_gate.py` 模块 docstring）：

> FAIL 的唯一合法理由是「**该有的纸没落盘**」，绝不是「**机器认为这里有战斗**」。
> 机器信号（战斗词、音频、首帧态）**只决定要不要审，永远不决定审出来有没有**。

这条同时满足了 04 号 Agent 的要求与「宽于或等于真相」：门禁的上界由**纸的完整性**决定，
而纸的完整性是自动化自己就能 100% 满足的（照抄一张模板即可），
所以这道门对**正确的自动化流程零误报**，对**偷懒跳步的流程必红**。

---

## 5. 可执行规格

### 5.1 接入点（`skills\naraka-highlight-studio\scripts\qa_gate.py`）

新增函数（放在 `gate_no_zero_gap_pseudo_cuts` 之后，`main()` 里**排最前**，先于 `timeline_mutex`）：

```python
def gate_coverage_complete(document, episodes, deleted, evidence) -> dict      # G-C1
def gate_deleted_voice_audit(deleted, voice_index, audit_text, evidence) -> dict  # G-C2
def gate_episode_head_engagement(episodes, evidence) -> dict                    # G-C3
```

`main()` 里插在 `if episodes:` 块**首行**（先判「有没有漏」，再判「有没有重叠」）：

```python
checks.append(gate_coverage_complete(document, episodes, deleted_intervals, tl_path))
checks.append(gate_deleted_voice_audit(deleted_intervals, voice_index, audit_files, tl_path))
checks.append(gate_episode_head_engagement(episodes, tl_path))
```

新增 CLI：

```
--voice-index PATH      analysis/combat_voice_index.json（naraka-voice-index/v1）
--deleted-audit PATH    可重复。reports/deleted_audit_v*.md（缺席审查门的裁决记录）
--automation-mode       把 G-C4 从 WARN 升 FAIL（仅「一句话自动出预览」模式使用）
```

`load_timeline()` 顺带把 `deleted_intervals` 与顶层 `source_duration` 一并返回（现在 `load_timeline`
只回 `(document, episodes)`，第 52–62 行）。

`validate_combat_timeline.py` 同步加 `coverage_complete` check（`check_deleted_intervals` 之后，289 行前），
与 qa_gate 共用同一实现 → 建议放进 `episode_geometry.py`，照它既有 docstring 的理由
（三处实现曾各算各的，861 因此假 FAIL）。

### 5.2 门禁规格表

| 门名 | 判据 | PASS / WARN / FAIL | 现状回归 | 自动化能否自愈 |
|---|---|---|---|---|
| `coverage_complete` | `∪episode原始范围 ∪ deleted_intervals` 铺满 `[0, sd]`，tol ≥0.25 s；`sd` 取不到 → WARN | PASS / WARN(无 sd) / **FAIL**(未声明间隙) | 35/35 历史 **零 FAIL** | **能**（漏了就补一条 `deleted_intervals`） |
| `deleted_voice_audit` | `deleted_intervals` 内 strong 战斗词命中 → 须有署名裁决记录 | PASS / — / **FAIL**(命中且无记录) | v6 需 1 条记录（`[0,181)`） | **能**（补一张表，结论写什么都行） |
| `episode_head_engagement` | `min(impact_points)−source_start ≤ 0.0` 须有 `head_adjudication`；`≤0.5` 仅 WARN；`≥8.0` 且前置删除段 >15 s → WARN | PASS / WARN / **FAIL**(off≤0 且缺记录) | 409 场中 2 场触发 | **能** |
| `deleted_audit_evidence_present` | 每条 `deleted_intervals` 带 `evidence[]` 或 `disposition` | PASS / WARN(默认) / FAIL(`--automation-mode`) | 423 条中 344 条 WARN | **能** |

### 5.3 回归（`scripts\test_whole_battle_gates.sh`）

现文件已锁 G-1/G-2，需补 6 个用例（缺一不算落地）：

| # | fixture | 期望 |
|---|---|---|
| 1 | `864_v6_combat_episodes.json` 原样 | `coverage_complete` **PASS** |
| 2 | 删掉 `combat_002`、**不补** `deleted_intervals` | `coverage_complete` **FAIL** |
| 3 | 删掉 `combat_002`、**补** `deleted_intervals`（`hostile_del`） | `coverage_complete` **PASS**（正确！缺口已声明），但 `deleted_voice_audit` **FAIL** |
| 4 | `combat_009` 挖 48.75 s 洞 | `no_holes_in_battle` FAIL（须带 `whole_battle_policy:"864"`） |
| 5 | 造一条 strong 词命中但无 `deleted_audit` 记录 | `deleted_voice_audit` **FAIL** |
| 6 | 同 fixture + 一份署名 `deleted_audit_vN.md` | `deleted_voice_audit` **PASS** |

用例 3 是这套设计的**核心自证**：单靠覆盖门不够，正是 G-C2 把它抓住的。

---

## 6. 诚实边界（不粉饰）

1. **这三扇门合起来仍然抓不到全部漏战。** 它们抓的是「未声明的缺口」「无人复核的战斗词命中」「场首已在打」。
   抓不到的是：**场尾未走完**（G-5）、**两场该分被合成一场**、**battle 内部顺序错乱**。
   这三条本轮只登记，判据需另设计（864 §6 的 G-4/G-5/G-6）。
2. **G-C2 的检出率上限是「有台词的战斗」。** 实测 strong 词只能覆盖 4/7；
   `combat_002`/`combat_005`/`combat_007` 三场删掉后 strong 词全不命中。
   换言之：**一场没有喊话的遭遇战被整段删掉，本设计仍然全绿。**
   真正的兜底只有两条：G-C1 要求它被登记，以及**审片**。
3. **音频在本素材无判别力**（`combat_002` 的 `frac_p75` 与真删除段完全重叠），
   所以任何以 dB/peak 为判据的门在本项目上都会是「严于真相」的假 FAIL。这与 864 `deleted_audit_v1` 的独立结论一致。
4. **`coverage_complete` 的 FAIL 可被自动化「合法」绕过** —— 补一条 `deleted_intervals` 就过。
   这是设计使然（宽于真相的代价）。真正拦住它的是 G-C2 的签名记录要求，
   而**签名要求无法被自动化满足**（它必须是一个人写下的判断）。
   **这是整套设计里唯一真正不可自动化的环节，也是唯一防住 `hostile_del` 的环节。**
5. 03 号报告已提出同名 `coverage_complete`（`03-streaming-and-wip.md §4.5`，容差 0.05 s）。
   本报告**同意其结论，但把容差从 0.05 放宽到 0.25** 并给出理由（`source_duration` 四舍五入），
   另加 G-C2/G-C3 —— 因为 03 只设计了「缺席一路」的拓扑检测，
   **没覆盖 `hostile_del`（自己把缺口登记成删除段）这一形态**。两轮结论可叠加，不冲突。