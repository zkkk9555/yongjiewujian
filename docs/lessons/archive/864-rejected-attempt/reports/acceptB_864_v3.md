# 角色 B · v3 独立验收报告（时间线数字验收员）

- 任务：21 / 素材 864
- 版本：v3
- 验收角色：B（时间线数字）
- 看图张数：**0**（未抽帧、未看帧、未跑 whisper / scenedetect / auto-editor）
- 写入文件（仅此两件）：本报告 + `TASK\reports\acceptB_revalidate_v3.json`
  - 过程脚本（只写 `TASK\cache\`，前缀 `_acceptB_v3`）：`cache\acceptB_v3_recompute.py`、`cache\acceptB_v3_framequant.py`
  - 中间结果：`cache\acceptB_v3_recompute_result.json`、`cache\acceptB_v3_framequant.json`
- 纪律：未修改 `timeline\`、`preview\`、`reports\` 下任何既有文件；未触碰 `acceptC_*` / `acceptD_*` / `selfaudit_*` / `adversarial_*`
- 声明：`merge_decision_v3.md` 与 `v3_validate.json` 只当**待复核对象**，本报告所有数字均由本人从原始产物重算

```
TASK     = C:\Project\永劫无间\123\21.864永劫无间 2026-09-30 02-57-13
PYTHON   = C:\Project\永劫无间\.video-tools\venv\Scripts\python.exe
FFPROBE  = C:\Project\永劫无间\.video-tools\LosslessCut\resources\ffprobe.exe
GEOMETRY = C:\Project\永劫无间\skills\naraka-highlight-studio\scripts\episode_geometry.py
VALIDATE = C:\Project\永劫无间\skills\naraka-highlight-studio\scripts\validate_combat_timeline.py
```

| 编号 | 项目 | 判定 |
|---|---|---|
| B1 | validate 复核（对象级相等） | **PASS** |
| B2 | 分段求和 / 20 切口逐条比对 | **PASS** |
| B3 | 源铺满 | **PASS**（作业书字面口径不成立，见 §B3-口径） |
| B4 | 挖洞合规 + 已登记例外 | **PASS** |
| B5 | needs_review 残留 / 边界内落 | **PASS** |
| B6 | 坐标换算零改动 | **PASS**（字面差异 40 处已逐条点名，见 §B6-点名） |

---

## B1 · validate 复核 —— PASS

**动作**：本人实跑一次
```
python.exe VALIDATE "TASK\timeline\combat_episodes_v3.json" --source-duration 1152.233 \
  --output "TASK\reports\acceptB_revalidate_v3.json"
→ stdout {"pass": true, "episodes": 11, ...} ; 退出码 0
```

**对象级相等比较**（`deep_diff` 递归 dict/list/标量，路径化）：

| 字段 | 我的实测值 | 绝对路径 · 字段 |
|---|---|---|
| 逐字段 diff 数 | **0** | `TASK\reports\acceptB_revalidate_v3.json` ↔ `TASK\reports\v3_validate.json` |
| `pass` | `true`（存档）/ `true`（复跑） | 两者 `$.pass` |
| `episode_count` | `11` / `11` | 两者 `$.episode_count` |
| `checks` 条数 | `27` / `27` | 两者 `$.checks` 长度 |
| `checks` 名称序列 | 完全一致（`checks_name_sequence_identical = true`） | 两者 `$.checks[*].name` |
| `warnings` | `[]` / `[]` | 两者 `$.warnings` |
| `schema` | `naraka-combat-roughcut-qa/v1` | 两者 `$.schema` |
| `timeline` | 两者逐字符相同 | 两者 `$.timeline` |

**`checks` 构成（27 = 1 + 11 + 1 + 1 + 1 + 1 + 11）**：

1. `episodes_non_empty` × 1（`count=11`）
2. `episode_001` … `episode_011` × 11（每条含 `source_start/source_end/engage_start/outcome_time/complete/needs_review/valid_range/within_source/monotonic_non_overlapping`，全 `pass=true`）
3. `source_duration_valid`（`source_duration=1152.233`）
4. `program_sum_seconds` → `program_sum = 580.26`
5. `in_segment_holes_excavated` → `excavated_seconds = 50.67`，`raw_span = 630.93`，`hole_count = 10`
6. `in_segment_holes_valid` → `problems = []`
7. `deleted_interval_1` … `deleted_interval_11` × 11

**逐条点名**：

- `program_sum_seconds`：存档与复跑两条 JSON 对象全等（`equal=true`），`program_sum = 580.26`。
- `in_segment_holes_excavated`：两条全等；`excavated_seconds = 50.67` / `raw_span = 630.93` / `hole_count = 10`。（本人另在 §B2 用 `episode_geometry` 独立重算到同样的 50.67 / 630.93 / 10。）
- `in_segment_holes_valid.problems`：`[]`（空数组，非缺字段）。
- `deleted_interval_N.overlaps_selected`：存档 11 个 `false`，复跑 11 个 `false`，两列逐位相同（`all_false_archive=true`、`all_false_revalidate=true`）。
- `warnings`：两条都是 `[]`，逐条无告警（0 条）。
- `deleted_interval_N` 的 `category` 全部非空（`birth_ability_ui_travel / travel_loot_idle / loot_heal_travel / ui_panel_selection / travel_loot / loot_shop_ui_travel / traversal_loot_environment / trade_loot_navigation / traversal / traversal / lobby_idle`）。

**判定：PASS**（对象级逐字段 diff = 0）

---

## B2 · 分段求和 —— PASS

**本人自己 `import episode_geometry` 重算**（不是读 `program_map_v3.json` 头部）：

| 量 | 我的实测值 | 出处 |
|---|---|---|
| `timeline_program_seconds(eps)` | **580.26** | `episode_geometry.py:167` ← 本人调用 |
| `timeline_raw_span_seconds(eps)` | **630.93** | `episode_geometry.py:174` ← 本人调用 |
| Σ 10 洞长度（逐洞相加） | **50.67** | `episode_geometry.episode_holes()` |
| `raw_span − program_sum` | **50.67** | — |
| 逐洞和 == raw_span − program_sum | **true**（差 0.0） | — |

**三处头部核对**（另加三处 QA 记录，共 6 处）：

| 绝对路径 · 字段 | 值 | 与本人 580.26 的最大绝对偏差 |
|---|---|---|
| `TASK\timeline\program_map_v3.json` · `program_seconds_total` | 580.26 | **0.0** |
| `TASK\timeline\combat_episodes_v3_programbounds.json` · `program_seconds_total` | 580.26 | **0.0** |
| `TASK\timeline\combat_episodes_v3.json` · `program_seconds_total` | 580.26 | **0.0** |
| `TASK\reports\v3_validate.json` · `checks[program_sum_seconds].program_sum` | 580.26 | **0.0** |
| `TASK\reports\qa_v3.json` · `checks[program_sum].measured` | 580.26 | **0.0** |
| `TASK\reports\qa_v3_programbounds.json` · `checks[program_sum].measured` | 580.26 | **0.0** |

**逐场（`episode_segments()` 展开 + 洞扣减）**：

| 场 | raw_span | 洞 | program | 展开切片 |
|---|---|---|---|---|
| combat_001 | 85.50 | [229.0,234.0] = 5.00 | 80.50 | [181.0,229.0] [234.0,266.5] |
| combat_002 | 40.00 | — | 40.00 | [305.0,345.0] |
| combat_003 | 47.00 | — | 47.00 | [357.0,404.0] |
| combat_004 | 27.01 | — | 27.01 | [416.99,444.0] |
| combat_005 | 22.50 | — | 22.50 | [495.0,517.5] |
| combat_006 | 43.70 | [554.2,555.55] = 1.35 | 42.35 | [517.5,554.2] [555.55,561.2] |
| combat_007 | 86.75 | 4 处 = 1.0+1.7+1.7+0.9 = 5.30 | 81.45 | [598.25,626.4] [627.4,630.7] [632.4,659.5] [661.2,678.6] [679.5,685.0] |
| combat_008 | 84.00 | 3 处 = 0.8+10.9+12.1 = 23.80 | 60.20 | [726.0,756.2] [757.0,781.0] [791.9,797.9] |
| combat_009 | 32.01 | — | 32.01 | [910.99,943.0] |
| combat_010 | 88.01 | — | 88.01 | [948.99,1037.0] |
| combat_011 | 74.45 | [1100.75,1115.97] = 15.22 | 59.23 | [1053.0,1100.75] [1115.97,1127.45] |
| **合计** | **630.93** | **10 处 = 50.67** | **580.26** | **20 段** |

**20 个 `cuts[]` 逐条 vs 展开切片**（`TASK\timeline\program_map_v3.json` · `cuts[i]` 对 `episode_geometry.timeline_cut_segments()`）：

| # | episode_id | source_start | source_end | program_start | program_end | source_dur | program_dur | rendered_frames | 三项一致 |
|---|---|---|---|---|---|---|---|---|---|
| 1 | combat_001 | 181.00 | 229.00 | 0.00 | 48.00 | 48.00 | 48.00 | 2880 | ✓ |
| 2 | combat_001 | 234.00 | 266.50 | 48.00 | 80.50 | 32.50 | 32.50 | 1950 | ✓ |
| 3 | combat_002 | 305.00 | 345.00 | 80.50 | 120.50 | 40.00 | 40.00 | 2400 | ✓ |
| 4 | combat_003 | 357.00 | 404.00 | 120.50 | 167.50 | 47.00 | 47.00 | 2820 | ✓ |
| 5 | combat_004 | 416.99 | 444.00 | 167.50 | 194.51 | 27.01 | 27.01 | 1621 | ✓ |
| 6 | combat_005 | 495.00 | 517.50 | 194.51 | 217.01 | 22.50 | 22.50 | 1350 | ✓ |
| 7 | combat_006 | 517.50 | 554.20 | 217.01 | 253.71 | 36.70 | 36.70 | 2202 | ✓ |
| 8 | combat_006 | 555.55 | 561.20 | 253.71 | 259.36 | 5.65 | 5.65 | 339 | ✓ |
| 9 | combat_007 | 598.25 | 626.40 | 259.36 | 287.51 | 28.15 | 28.15 | 1689 | ✓ |
| 10 | combat_007 | 627.40 | 630.70 | 287.51 | 290.81 | 3.30 | 3.30 | 198 | ✓ |
| 11 | combat_007 | 632.40 | 659.50 | 290.81 | 317.91 | 27.10 | 27.10 | 1626 | ✓ |
| 12 | combat_007 | 661.20 | 678.60 | 317.91 | 335.31 | 17.40 | 17.40 | 1044 | ✓ |
| 13 | combat_007 | 679.50 | 685.00 | 335.31 | 340.81 | 5.50 | 5.50 | 330 | ✓ |
| 14 | combat_008 | 726.00 | 756.20 | 340.81 | 371.01 | 30.20 | 30.20 | 1812 | ✓ |
| 15 | combat_008 | 757.00 | 781.00 | 371.01 | 395.01 | 24.00 | 24.00 | 1440 | ✓ |
| 16 | combat_008 | 791.90 | 797.90 | 395.01 | 401.01 | 6.00 | 6.00 | 360 | ✓ |
| 17 | combat_009 | 910.99 | 943.00 | 401.01 | 433.02 | 32.01 | 32.01 | 1921 | ✓ |
| 18 | combat_010 | 948.99 | 1037.00 | 433.02 | 521.03 | 88.01 | 88.01 | 5281 | ✓ |
| 19 | combat_011 | 1053.00 | 1100.75 | 521.03 | 568.78 | 47.75 | 47.75 | 2865 | ✓ |
| 20 | combat_011 | 1115.97 | 1127.45 | 568.78 | 580.26 | 11.48 | 11.48 | 689 | ✓ |

- `source_start/source_end` 逐条 == 展开切片：**20/20 相等**（`cut_src_pair_all_equal = true`）
- `source_duration == program_duration`：**20/20 相等**；`|source_dur − program_dur|` 最大 **0.0**
- `program_end − program_start == program_duration`：**20/20 相等**（最大偏差 0.0）
- `Σ program_duration` = **580.26**，`Σ source_duration` = **580.26**，与 `episode_geometry` 的 580.26 完全一致
- 节目钟连续性：20 个 `program_start` 逐条等于前一 `program_end`（首 0.0），**0 处断点**
- 末 `program_end` = **580.26** == `program_seconds_total`
- `program_map_v3.json` 头部：`cut_count=20`、`rendered_segments=20`、`reused_segments=0`、`episode_count=11` —— 与实测 20 切口 / 20 展开段 / 11 场一致
- **Σ `rendered_frames` = 34,817**；本人实跑
  `ffprobe -v error -select_streams v:0 -show_entries stream=nb_frames ... TASK\preview\864-review-v3.mp4`
  得 `nb_frames = 34817`（容器 tag，非 `-count_frames` 重数）→ **完全相等**
- 附带：`34817 ÷ 60 = 580.283333`；`ffprobe format.duration = 580.304333`，差 **−0.021 s**（音频流略长于视频流，属正常）
- 附带：20 条 `rendered_frames` 逐条 == `round(source_duration × 60)`，20/20 相等

**判定：PASS**

---

## B3 · 源铺满 —— PASS

程序化枚举（`cache\acceptB_v3_recompute.py`，非手数），源区间 `[0, 1152.233]`（`combat_episodes_v3.json` · `source_duration`）。

### B3-主判 · 三分铺满（11 删除段 + 10 段内洞 + 20 选中段 = 41 片）

| 量 | 我的实测值 |
|---|---|
| 片数 | **41** |
| Σ 片长 | **1152.233**（与 `source_duration` 差 0.0） |
| **最小缝隙值** | **0.0** |
| **最大缝隙值** | **0.0** |
| 缝隙条数（> 1e-9） | **0** |
| 重叠条数（< −1e-9） | **0** |
| 精确铺满 | **true** |

### B3-副判 · 二分铺满（11 删除段 + 11 场原始跨度 = 22 片）

| 量 | 我的实测值 |
|---|---|
| Σ 片长 | **1152.233**（630.93 + 521.303，差 0.0） |
| 最小 / 最大缝隙 | **0.0 / 0.0** |
| 重叠 | **0** |
| 精确铺满 | **true** |

两条独立口径都给出「零缝零重叠、首尾严丝合缝」。逐条 41 片的排布见 `cache\acceptB_v3_recompute_result.json` · `$.B3.tiling_41.pieces`（例如 `DEL4 [404.0,416.99]` 紧接 `SEL05:combat_004 [416.99,444.0]`，`DEL5` 起于 444.0 …）。

### B3-口径 · 作业书字面写法不成立（**不判为 v3 缺陷**）

作业书 B3 写「11 条 `deleted_intervals` + **20 段选中区**必须精确铺满 `[0,1152.233]`」。本人按字面枚举 31 片：

| 量 | 我的实测值 |
|---|---|
| 片数 | 31（11 删除段 + 20 选中段） |
| Σ 片长 | **1101.563** |
| 未覆盖 | **50.67** —— 恰好等于 §B2 实测的 10 洞总长 50.67 |
| 重叠 | 0 |
| 非洞缝隙 | 10 条，全部正好是 10 处声明洞（5.00 / 1.35 / 1.00 / 1.70 / 1.70 / 0.90 / 0.80 / 10.90 / 12.10 / 15.22） |

即：**「20 段选中区」已经是扣除洞之后的展开切片，洞是第二类删除区间**，字面口径把两类合并漏掉了。把洞补进片集（41 片）或改用 11 场原始跨度（22 片），铺满均精确成立。这是**作业书措辞缺口，不是 v3 的时间线缺陷**；v3 侧没有任何未申报的缝隙或重叠。

**判定：PASS**（按正确口径；字面口径缺口已登记）

---

## B4 · 挖洞合规 + 已登记例外 —— PASS

程序化枚举 10 处 `excluded_inside`（`TASK\timeline\combat_episodes_v3.json` · `combat_episodes[*].excluded_inside`）：

| 场 | start | end | 时长 | `start<end` | `start>=source_start` | `end<=source_end` |
|---|---|---|---|---|---|---|
| combat_001 | 229.0 | 234.0 | 5.00 | ✓ | ✓ (181.0) | ✓ (266.5) |
| combat_006 | 554.2 | 555.55 | 1.35 | ✓ | ✓ (517.5) | ✓ (561.2) |
| combat_007 | 626.4 | 627.4 | 1.00 | ✓ | ✓ (598.25) | ✓ (685.0) |
| combat_007 | 630.7 | 632.4 | 1.70 | ✓ | ✓ | ✓ |
| combat_007 | 659.5 | 661.2 | 1.70 | ✓ | ✓ | ✓ |
| combat_007 | 678.6 | 679.5 | 0.90 | ✓ | ✓ | ✓ |
| combat_008 | 756.2 | 757.0 | 0.80 | ✓ | ✓ (726.0) | ✓ (810.0) |
| combat_008 | 781.0 | 791.9 | 10.90 | ✓ | ✓ | ✓ |
| combat_008 | 797.9 | 810.0 | 12.10 | ✓ | ✓ | ✓ |
| combat_011 | 1100.75 | 1115.97 | 15.22 | ✓ | ✓ (1053.0) | ✓ (1127.45) |
| **合计 10 处** | | | **50.67** | **10/10** | **10/10** | **10/10** |

- **互不重叠**：同场内两两配对检查 → **0 对重叠**（`same_episode_hole_overlaps = []`）。每场内洞均严格升序且首尾相接不交。
- **不与 `deleted_intervals` 重叠**：10 洞 × 11 删除段共 110 次配对 → **0 处重叠**（`hole_vs_deleted_interval_overlaps = []`）。
- **分场洞数**：`{combat_001:1, combat_002:0, combat_003:0, combat_004:0, combat_005:0, combat_006:1, combat_007:4, combat_008:3, combat_009:0, combat_010:0, combat_011:1}` = **10**。
- `episode_geometry.hole_problems()` 逐场返回 `[]`；`validate` 的 `in_segment_holes_valid.problems = []`。
- `TASK\reports\qa_v3.json` · `checks[in_segment_holes].measured = "10 holes well-formed"`，与本人计数一致。

### 已登记例外逐条核数

| 登记项 | 我的实测值 | 绝对路径 · 字段 | 一致 |
|---|---|---|---|
| `combat_004` `lead_in = 0.01` | engage 417.0 − start 416.99 = **0.01** | `combat_episodes[3].engage_start − .source_start` | ✓ |
| `combat_003` 无洞 | `excluded_inside = []`，洞数 **0** | `combat_episodes[2].excluded_inside` | ✓ |
| `combat_006` 尾窗 12.2 s | 561.2 − 549.0 = **12.2** | `combat_episodes[5].source_end − .outcome_time` | ✓ |
| `combat_008` 可见尾窗 1.4 s | 洞 `[797.9, 810.0)` 起点 797.9 − outcome 796.5 = **1.4**（声明尾窗 810.0 − 796.5 = 13.5，12.1 已被洞挖除） | `combat_episodes[7].excluded_inside[2].start − .outcome_time` | ✓ |

**附：11 场尾窗（`source_end − outcome_time`）全表**，供复验按 §6 例外清单核对：
`combat_001 13.5` / `002 7.0` / `003 6.0` / `004 14.0` / `005 5.5` / `006 12.2` / `007 15.0` / `008 13.5` / `009 13.0` / `010 13.0` / `011 4.95`。
其中 `< 13 s` 的 6 场（002/003/005/006/008/011）在 `merge_decision_v3.md` §6 例外清单 E1–E5、E13、E14 中均有登记；本人实测数字与该清单逐条同值。

**判定：PASS**

---

## B5 · needs_review 与边界内落 —— PASS

| 量 | 我的实测值 | 绝对路径 · 字段 |
|---|---|---|
| `needs_review == true` 的场数 | **0** | `combat_episodes_v3.json` · `combat_episodes[*].needs_review` |
| 11 场 `needs_review` | 全 `false` | 同上 |
| 11 场 `complete` | 全 `true` | `combat_episodes[*].complete` |
| `validate` 的 `warnings` | `[]`（无 `is marked needs_review` 告警） | `acceptB_revalidate_v3.json` · `$.warnings` |
| `engage_start ∈ [source_start, source_end]` | **11/11** | `$.B5.boundary_rows[*].engage_in_range` |
| `engage_start >= source_start` | **11/11** | `$.B5.boundary_rows[*].engage_ge_source_start` |
| `outcome_time ∈ [source_start, source_end]` | **11/11** | `$.B5.boundary_rows[*].outcome_in_range` |
| `validate.valid_range`（`0<=start<engage<=outcome<=end`） | **11/11 true** | `acceptB_revalidate_v3.json` · `$.checks[episode_*].valid_range` |
| `validate.monotonic_non_overlapping` | **11/11 true** | 同上 |

逐场（`lead_in = engage_start − source_start`，`尾窗 = source_end − outcome_time`）：

| 场 | source_start | engage_start | outcome | source_end | lead_in | 尾窗 |
|---|---|---|---|---|---|---|
| combat_001 | 181.0 | 186.0 | 253.0 | 266.5 | 5.0 | 13.5 |
| combat_002 | 305.0 | 310.0 | 338.0 | 345.0 | 5.0 | 7.0 |
| combat_003 | 357.0 | 359.0 | 398.0 | 404.0 | 2.0 | 6.0 |
| combat_004 | 416.99 | 417.0 | 430.0 | 444.0 | **0.01** | 14.0 |
| combat_005 | 495.0 | 499.0 | 512.0 | 517.5 | 4.0 | 5.5 |
| combat_006 | 517.5 | 522.0 | 549.0 | 561.2 | 4.5 | 12.2 |
| combat_007 | 598.25 | 602.0 | 670.0 | 685.0 | 3.75 | 15.0 |
| combat_008 | 726.0 | 731.0 | 796.5 | 810.0 | 5.0 | 13.5 |
| combat_009 | 910.99 | 911.0 | 930.0 | 943.0 | **0.01** | 13.0 |
| combat_010 | 948.99 | 949.0 | 1024.0 | 1037.0 | **0.01** | 13.0 |
| combat_011 | 1053.0 | 1058.0 | 1122.5 | 1127.45 | 5.0 | 4.95 |

三场 `lead_in = 0.01` 均由 `validate` 第 113 行 `start < engage` 严格小于强制（`merge_decision_v3.md` §1.1 已登记为三场同因同解），已登记为例外 E7。

**判定：PASS**

---

## B6 · 坐标换算零改动 —— PASS

真源：`TASK\timeline\combat_episodes_v3.json`（11 场 / 11 删除段 / 10 洞）
视图：`TASK\timeline\combat_episodes_v3_programbounds.json`（`coordinate_space = "PROGRAM SECONDS (verification view only, never rendered)"`，**20 段**）

### B6-实质 · 换算是否改动了任何一个源秒数 → **未改动**

| 判据 | 我的实测值 |
|---|---|
| 20 个 `from_source` 逐对 == `episode_geometry.episode_segments()` 展开值 | **20/20 完全相等** |
| 20 个 `from_source` 逐对 == `program_map_v3.json` · `cuts[*].source_start/end` | **20/20 完全相等** |
| 视图节目坐标 `(source_start, source_end)` == `program_map_v3.json` · `(program_start, program_end)` | **20/20 完全相等** |
| 视图节目钟覆盖 `0 → 580.26`（`program_seconds_total`） | ✓ |
| 视图 Σ 节目时长 | **580.26**（与真源 580.26 相同） |
| `from_source` 抽样点名 | `combat_004#0 → [416.99, 444.0]`、`combat_009#0 → [910.99, 943.0]`、`combat_010#0 → [948.99, 1037.0]`、`combat_011#1 → [1115.97, 1127.45]` —— 三个 `0.01` 对齐值与 `1127.45` 全部**一字未改** |

结论：**换算过程没有改动任何一个源秒数**，`416.99 / 910.99 / 948.99 / 1115.97 / 1127.45` 等全部非整值原样保留在 `from_source` 里。

### B6-点名 · 字面逐字段比对（**40 处秒数不同，全部点名**）

作业书 B6 写「`combat_episodes_v3_programbounds.json` 必须与 `combat_episodes_v3.json` 边界数值完全相同」。字面执行结果：视图是**派生的 20 段节目时钟展开视图**，不是 1:1 副本，故字段值天然不同。逐条点名（`$.B6.literal_second_diffs`，共 **40** 条 `source_*` 差异）：

| # | 视图条目 | 视图 `source_start` | 展开源 `source_start` | 视图 `source_end` | 展开源 `source_end` |
|---|---|---|---|---|---|
| 1 | combat_001#0 | 0.00 | 181.00 | 48.00 | 229.00 |
| 2 | combat_001#1 | 48.00 | 234.00 | 80.50 | 266.50 |
| 3 | combat_002#0 | 80.50 | 305.00 | 120.50 | 345.00 |
| 4 | combat_003#0 | 120.50 | 357.00 | 167.50 | 404.00 |
| 5 | combat_004#0 | 167.50 | 416.99 | 194.51 | 444.00 |
| 6 | combat_005#0 | 194.51 | 495.00 | 217.01 | 517.50 |
| 7 | combat_006#0 | 217.01 | 517.50 | 253.71 | 554.20 |
| 8 | combat_006#1 | 253.71 | 555.55 | 259.36 | 561.20 |
| 9 | combat_007#0 | 259.36 | 598.25 | 287.51 | 626.40 |
| 10 | combat_007#1 | 287.51 | 627.40 | 290.81 | 630.70 |
| 11 | combat_007#2 | 290.81 | 632.40 | 317.91 | 659.50 |
| 12 | combat_007#3 | 317.91 | 661.20 | 335.31 | 678.60 |
| 13 | combat_007#4 | 335.31 | 679.50 | 340.81 | 685.00 |
| 14 | combat_008#0 | 340.81 | 726.00 | 371.01 | 756.20 |
| 15 | combat_008#1 | 371.01 | 757.00 | 395.01 | 781.00 |
| 16 | combat_008#2 | 395.01 | 791.90 | 401.01 | 797.90 |
| 17 | combat_009#0 | 401.01 | 910.99 | 433.02 | 943.00 |
| 18 | combat_010#0 | 433.02 | 948.99 | 521.03 | 1037.00 |
| 19 | combat_011#0 | 521.03 | 1053.00 | 568.78 | 1100.75 |
| 20 | combat_011#1 | 568.78 | 1115.97 | 580.26 | 1127.45 |

**另有 3 项结构性差异（非秒数，但作业书「只允许字段名/坐标系标注不同」未涵盖）**：

1. `engage_start` 20 个全部 == 本段 `source_start`（占位值，不是真源的 186.0/310.0/… ），`outcome_time` 20 个全部 == 本段 `source_end`。视图里这两个字段被降级成「整段即交火」的占位标注，**真源语义值未被搬运**。
2. `excluded_inside` 20 段全为 `[]`（10 洞已在展开阶段吸收，节目钟下不存在洞）。
3. `deleted_intervals` 由真源 **11 条**变为视图 **0 条**（节目钟下不存在「被删区间」）。

以上 3 项与 40 条 `source_*` 差异**全部是坐标系标注 / 视图语义**，不是对源秒数的改动；视图的 `coordinate_space` 字段已明文声明 `PROGRAM SECONDS (verification view only, never rendered)`。

**判定：PASS**（换算零改动成立；字面差异已逐条点名，判定按实质口径）

---

## 汇总

| 编号 | 项目 | 判定 | 关键实测值 |
|---|---|---|---|
| B1 | validate 复核 | **PASS** | 逐字段 diff = 0；27 checks；warnings 0；program_sum 580.26；excavated 50.67；problems []；11×overlaps_selected=false |
| B2 | 分段求和 | **PASS** | program 580.26 / raw 630.93 / 洞 50.67（6 处头部偏差均 0.0）；20/20 切口一致；Σframes 34,817 == ffprobe nb_frames |
| B3 | 源铺满 | **PASS** | 41 片 / 22 片双口径，Σ=1152.233，**最小缝隙 0.0**，重叠 0；字面 31 片口径缺口 50.67 = Σ洞（措辞问题） |
| B4 | 挖洞合规 | **PASS** | 10 洞全部合规；同场互不重叠 0；与删除段重叠 0；E7 0.01 / c003 无洞 / c006 12.2 / c008 可见 1.4 全对 |
| B5 | needs_review | **PASS** | 残留 **0**；engage/outcome 11/11 落界内；`start<engage` 三场 0.01 例外合规 |
| B6 | 坐标换算 | **PASS** | 20/20 `from_source` 与展开值及 cuts 逐对全等；字面 40 处差异已点名 + 3 项结构差异已登记 |

---

## 附 · 本人新发现的问题（均不影响上述六项判定）

### 新-1（**中 · 建议复验处理**）`combat_004` 的 `source_start = 416.99` 在 60fps 下**不是一帧**，实际首渲染帧是源 **417.0 s** —— 正是 v3 自己想避开的那块「四栏背包面板」帧

- 数值依据（`cache\acceptB_v3_framequant.json`）：`cuts[4].source_start = 416.99`；`416.99 × 60 = 25,019.4` → 落在帧 25,019 与 25,020 之间 → 解码器取到的第一帧是 **帧 25,020 = 源 417.000000 s**。
- 与 v3 自身记载的冲突：`combat_episodes_v3.json` · `combat_004.boundary_reason` 明写「4K 母版帧 `t0417.0.jpg` 显示**源 417.0 仍是四栏面板（货币 16250）**，故 **416.7 不可用**」；`combat_004.notes` §② 亦承认「416.2–416.6 那 0.4–0.5 秒的实时交火被半透明面板物理遮挡」。
- 结论：取 416.99 的两条理由里，**门禁理由（`start < engage` 严格小于）成立**，但**画面理由（要一个「面板已关的首干净帧」）在 60fps 帧级上并未达成** —— 节目上 `combat_004` 的第 0 帧就是 `cut 5`（`vseg005.mp4`，节目 `P 167.5`）所在的那一帧。若要真正拿到干净帧，需取 `417.0` 之后的**下一个整帧**（如 417.016667 / 417.033），同时把 `deleted_interval_4` 右界同步后移。
- 影响面：仅 `combat_004` 首帧 1 帧；`lead_in` 已登记为例外 E7（0.01 s），但**「面板残留」这一项此前未单独登记**。
- 限制声明：本人看图 0 张，**不能确认**该帧视觉上是否真的仍开面板；上述只是帧号算术 + 与 v3 自述的一致性推断。**建议派一路只抽这一帧（1 张图）复核**，不要重渲、不要改 v3。

### 新-2（**低 · 提示**）另有 3 处切口起点同样落在非整帧上

- `cuts[16]`（`vseg017.mp4`）：`910.99 × 60 = 54,659.4` → 实际首帧 **911.0**（= `engage_start`，设计意图达成，无害）
- `cuts[17]`（`vseg018.mp4`）：`948.99 × 60 = 56,939.4` → 实际首帧 **949.0**（= `engage_start`，设计意图达成，无害）
- `cuts[19]`（`vseg020.mp4`）：`1115.97 × 60 = 66,958.2` → 实际首帧 **1115.983333**（+0.0133 s）。`combat_011.notes` 写「战报名次屏的可读起点是 **1115.97**」，节目上实际是 **1115.9833**（晚 0.8 帧）。因 1115.9833 > 1115.97，**没有漏进任何加载屏帧**，无害；但文字秒点与实际首帧差 0.8 帧，建议在 notes 里把秒点写成 1115.98 或注明帧量化。
- 这 4 处 `rendered_frames` 均比「`ceil(end×60) − ceil(start×60)`」多 1 帧（四舍五入到上整帧），20 段合计 34,817 与 `ffprobe nb_frames` 完全对齐，**无累计漂移**。

### 新-3（**低 · 作业书措辞，非 v3 缺陷**）作业书 B3 的「11 删除段 + 20 段选中区」漏算 10 处声明洞（缺口 50.67 s）；作业书 B6 的「边界数值完全相同」与 `*_programbounds.json` 的视图语义不相容（字面 40 处差异 + 3 项结构差异）。两处均已在 §B3-口径 / §B6-点名 完整登记，建议后续作业书写成「11 删除段 + 10 洞 + 20 选中段 = 41 片」与「`from_source` 逐对全等」。

### 已复核并**排除**的疑似问题（留档以免复验重复查）

- `combat_episodes_v3.json` 的 `v2_change_summary` 字段内容为 v2 历史值（「洞 6 处 44.92 秒」「节目总秒 614.9 → 587.33」），初看像过期污染；**已确认是刻意保留的 v2 纪要**，同文件另有 `v3_change_summary`，其内容（洞 6→10 处、44.92→50.67 s、raw_span 632.25→630.93、节目总秒 587.33→580.26、切口 9/21→10/20）与本人实测**逐值相符**。字段名自带 `v2_` 前缀，不构成缺陷。
- `qa_v3.json` · `subtitle_span / subtitle_stats` 两项为 WARN（`"no srt"` / `"no stats"`）而 `qa_v3_programbounds.json` 同两项为 PASS（`40 cues` / `40`）—— 属作业书已登记的 `qa_gate.gate_subtitles` 源钟/节目钟错配（源坐标跑 `--no-srt`），**不计入本报告六项**，也不当作 v3 缺陷。

---

**六项合计：B1 PASS / B2 PASS / B3 PASS / B4 PASS / B5 PASS / B6 PASS。**
**本人新发现 3 条（新-1 为唯一需要人处置的一条：1 帧复核，不是渲染缺陷）。**

STATUS: PASS
