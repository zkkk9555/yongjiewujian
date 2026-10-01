# 角色 B · 时间线数字验收报告 — 任务 21 / 素材 864 / v4

**验收人**：独立第三方（B），**未参与 v4 任何执行**（未写时间线、未渲预览、未做扫描/对抗审/裁决）。
**验收日期**：2026-10-01
**看图张数**：**0 张**（全程只做数值与命令取证；未抽帧、未看帧、未跑 whisper / scenedetect / auto-editor）
**纪律**：全程只读既有文件；只写了本文件与 `reports\acceptB_revalidate_v4.json`；临时脚本全部落在 `TASK\cache\` 且带 `_acceptB_v4` 前缀；未新建任何 `.ps1`；未触碰 `timeline\` / `preview\` / v1/v2/v3 任何文件。

## 0. 取证环境与我的临时脚本

| 项 | 绝对路径 |
|---|---|
| TASK | `C:\Project\永劫无间\123\21.864永劫无间 2026-09-30 02-57-13` |
| 时间线 v4（真源） | `…\timeline\combat_episodes_v4.json` |
| 时间线 v3（只读对照） | `…\timeline\combat_episodes_v3.json` |
| 节目映射 v4 | `…\timeline\program_map_v4.json` |
| 节目坐标视图 v4 | `…\timeline\combat_episodes_v4_programbounds.json` |
| 冻结预览 v4（只读 ffprobe） | `…\preview\864-review-v4.mp4` |
| validate 存档 | `…\reports\v4_validate.json` |
| 我的重跑产物 | `…\reports\acceptB_revalidate_v4.json` |
| 改动单 | `…\reports\change_order_v4.md` |
| episode_geometry | `C:\Project\永劫无间\skills\naraka-highlight-studio\scripts\episode_geometry.py` |
| validate 脚本 | `…\naraka-highlight-studio\scripts\validate_combat_timeline.py` |
| Python | `C:\Project\永劫无间\.video-tools\venv\Scripts\python.exe` |
| FFprobe | `C:\Project\永劫无间\.video-tools\LosslessCut\resources\ffprobe.exe` |
| 我的临时脚本 | `…\cache\_acceptB_v4_read.py` / `_acceptB_v4_verify.py` / `_acceptB_v4_verify2.py` / `_acceptB_v4_verify3.py` / `_acceptB_v4_pb.py` / `_acceptB_v4_prose.py`；原始日志 `…\cache\_acceptB_v4_raw.txt` / `_acceptB_v4_raw_b36b7.txt` |

---

## B1 · validate 复核（自己重跑 + 对象级相等比较） — **PASS**

**我执行的命令**（与作业书逐字一致）：

```
validate_combat_timeline.py '…\timeline\combat_episodes_v4.json' \
  --source-duration 1152.233 --output '…\reports\acceptB_revalidate_v4.json'
→ stdout {"pass": true, "episodes": 11}   退出码 = 0
```

**对象级比较方法**：把两份 JSON 递归展平成 `路径 → 叶值` 的扁平映射（数组按 `[i]` 编址），对并集键集逐项 `!=` 比较。

| 字段 | 路径 | 存档 `v4_validate.json` | 我的 `acceptB_revalidate_v4.json` | 判定 |
|---|---|---|---|---|
| 扁平叶键数 | 整份 | 210 | 210 | 相等 |
| **逐字段 diff 条数** | 整份 | — | **0** | 相等 |
| 字节级 | 两文件 | `bytes() == bytes()` | **True** | 逐字节一致 |
| `pass` | 根 | `true` | `true` | PASS |
| `episode_count` | 根 | 11 | 11 | PASS |
| `len(checks)` | `checks[]` | 27 | 27 | PASS |
| `checks` 名称序列 | `checks[].name` | 27 项 | 完全同一序列（`==` 为 True） | PASS |
| `warnings` | 根 | `[]` | `[]` | PASS |
| `program_sum` | `checks[name=program_sum_seconds].program_sum` | 562.97 | 562.97 | PASS |
| `excavated_seconds` | `checks[name=in_segment_holes_excavated].excavated_seconds` | 52.69 | 52.69 | PASS |
| （同项 `raw_span`） | 同上 `.raw_span` | 615.66 | 615.66 | PASS |
| （同项 `hole_count`） | 同上 `.hole_count` | 11 | 11 | PASS |
| `in_segment_holes_valid.problems` | `checks[name=in_segment_holes_valid].problems` | `[]` | `[]` | PASS |
| `deleted_interval_N.overlaps_selected` | `checks[name=deleted_interval_1..11].overlaps_selected` | 11 项全 `false` | 11 项全 `false` | PASS |

**27 条 check 的构成**（我逐条点名核对，与 27 相符）：

| 组 | 名称 | 条数 |
|---|---|---|
| 1 | `episodes_non_empty` | 1 |
| 2 | `episode_001` … `episode_011` | 11 |
| 3 | `source_duration_valid`（`source_duration=1152.233`） | 1 |
| 4 | `program_sum_seconds` | 1 |
| 5 | `in_segment_holes_excavated` | 1 |
| 6 | `in_segment_holes_valid` | 1 |
| 7 | `deleted_interval_1` … `deleted_interval_11` | 11 |
| | **合计** | **27** |

**结论：重跑结果与存档对象级完全相等，逐字段 diff = 0，且两文件逐字节一致。B1 = PASS。**

---

## B2 · 分段求和（自己 `import episode_geometry` 重算） — **PASS**

**我导入的模块**：`sys.path.insert(0, '…\naraka-highlight-studio\scripts')` 后 `from episode_geometry import timeline_program_seconds, timeline_raw_span_seconds, timeline_cut_segments, episode_segments, episode_holes, episode_bounds`。全部为**自己调用**，未采信任何 `v4_geometry` 里的数字。

### B2.1 四处头部三处核对

| 来源 | 绝对路径 · 字段 | 值 |
|---|---|---|
| **我的重算** | `episode_geometry.timeline_program_seconds(combat_episodes_v4)` | **562.97** |
| 我的重算 | `episode_geometry.timeline_raw_span_seconds(...)` | **615.66** |
| 我的重算 | `episode_geometry.timeline_cut_segments(...)` 条数 | **21** |
| 归档 A | `…\timeline\combat_episodes_v4.json` → `program_seconds_total` | 562.97（差 **0.0**） |
| 归档 B | `…\timeline\program_map_v4.json` → `program_seconds_total` | 562.97（差 **0.0**） |
| 归档 C | `…\timeline\combat_episodes_v4_programbounds.json` → `program_seconds_total` | 562.97（差 **0.0**） |
| 归档 | `combat_episodes_v4.json` → `v4_geometry.raw_span_seconds` | 615.66（差 **0.0**） |
| 归档 | `program_map_v4.json` → `cut_count` / `rendered_segments` | 21 / 21 |
| 归档 | `v4_geometry.render_cut_segments` | 21 |
| 归档 | `v4_geometry.cut_segments`（21 对）与我的重算 | **完全相同**（列表相等） |

### B2.2 逐洞长度求和 == raw_span − program_sum

- 我枚举 `excluded_inside` 全部条目：**11 处**（与 `v4_geometry.excluded_inside_hole_count=11` 相符）
- 我自己逐洞累加 `Σ(hole.end − hole.start)` = **52.69**（与 `v4_geometry.excluded_inside_seconds=52.69` 相符）
- `raw_span − program_sum` = `615.66 − 562.97` = **52.69**
- **等式成立（差 0，判据 1e-6 内）**

### B2.3 21 个 `cuts[]` 与展开切片逐条比对（程序化，21 × 8 字段）

`program_map_v4.json` → `cuts[]` 对 `episode_geometry` 展开切片。逐条核 `episode_id` / `part` / `source_start` / `source_end` / `source_duration` / `program_start` / `program_end` / `program_duration` / `program_end−program_start==program_duration` / `rendered_frames==round(program_duration×60)`：

| # | episode | part | source_start | source_end | source_duration | program_start | program_end | program_duration | rendered_frames | 与几何一致 |
|---|---|---|---|---|---|---|---|---|---|---|
| 01 | combat_001 | 0 | 181.0 | 229.0 | 48.0 | 0.0 | 48.0 | 48.0 | 2880 | ✔ |
| 02 | combat_001 | 1 | 234.0 | 266.5 | 32.5 | 48.0 | 80.5 | 32.5 | 1950 | ✔ |
| 03 | combat_002 | 0 | 320.27 | 345.0 | 24.73 | 80.5 | 105.23 | 24.73 | 1484 | ✔ |
| 04 | combat_003 | 0 | 357.0 | 404.0 | 47.0 | 105.23 | 152.23 | 47.0 | 2820 | ✔ |
| 05 | combat_004 | 0 | 416.99 | 444.0 | 27.01 | 152.23 | 179.24 | 27.01 | 1621 | ✔ |
| 06 | combat_005 | 0 | 495.0 | 517.5 | 22.5 | 179.24 | 201.74 | 22.5 | 1350 | ✔ |
| 07 | combat_006 | 0 | 517.5 | 554.2 | 36.7 | 201.74 | 238.44 | 36.7 | 2202 | ✔ |
| 08 | combat_006 | 1 | 555.62 | 561.2 | 5.58 | 238.44 | 244.02 | 5.58 | 335 | ✔ |
| 09 | combat_007 | 0 | 598.25 | 624.0 | 25.75 | 244.02 | 269.77 | 25.75 | 1545 | ✔ |
| **10** | **combat_007** | **1** | **624.3** | **626.4** | **2.1** | **269.77** | **271.87** | **2.1** | **126** | **✔（本轮新洞造成的新切口）** |
| 11 | combat_007 | 2 | 627.4 | 630.7 | 3.3 | 271.87 | 275.17 | 3.3 | 198 | ✔ |
| 12 | combat_007 | 3 | 632.4 | 659.5 | 27.1 | 275.17 | 302.27 | 27.1 | 1626 | ✔ |
| 13 | combat_007 | 4 | 661.2 | 678.6 | 17.4 | 302.27 | 319.67 | 17.4 | 1044 | ✔ |
| 14 | combat_007 | 5 | 679.6 | 685.0 | 5.4 | 319.67 | 325.07 | 5.4 | 324 | ✔ |
| 15 | combat_008 | 0 | 726.0 | 755.25 | 29.25 | 325.07 | 354.32 | 29.25 | 1755 | ✔ |
| 16 | combat_008 | 1 | 757.0 | 779.95 | 22.95 | 354.32 | 377.27 | 22.95 | 1377 | ✔ |
| 17 | combat_008 | 2 | 791.9 | 798.35 | 6.45 | 377.27 | 383.72 | 6.45 | 387 | ✔ |
| 18 | combat_009 | 0 | 910.99 | 943.0 | 32.01 | 383.72 | 415.73 | 32.01 | 1921 | ✔ |
| 19 | combat_010 | 0 | 948.99 | 1037.0 | 88.01 | 415.73 | 503.74 | 88.01 | 5281 | ✔ |
| 20 | combat_011 | 0 | 1053.0 | 1100.75 | 47.75 | 503.74 | 551.49 | 47.75 | 2865 | ✔ |
| 21 | combat_011 | 1 | 1115.97 | 1127.45 | 11.48 | 551.49 | 562.97 | 11.48 | 689 | ✔ |

- **逐条 problems：none**（21 × 10 项判据全过）
- `program_start` 连续（`cuts[i].program_start == cuts[i-1].program_end`）：**True**，无断裂
- 首 `program_start` = **0.0**；末 `program_end` = **562.97**
- `Σ cuts[].source_duration` = **562.97**；`Σ cuts[].program_duration` = **562.97**；两者均 == 我的 `timeline_program_seconds` = 562.97
- `source_duration == program_duration` 逐条成立（21/21）
- `Σ cuts[].rendered_frames` = **33780**
- 我自己跑 `ffprobe -select_streams v:0 -count_frames` 读 `…\preview\864-review-v4.mp4`：`nb_read_frames = 33780`，`nb_frames = 33780`，`r_frame_rate = 60/1`，`avg_frame_rate = 60/1`
- **`Σ rendered_frames == nb_read_frames`（33780 == 33780，delta 0）**

**结论：全部对上。B2 = PASS。**

---

## B3 · 源铺满（程序化枚举） — **PASS**

作业书原文是「11 条 `deleted_intervals` + **21 段选中区**」。我按**两种划分口径**都做了枚举，因为 21 段选中区是**挖洞后**的产物，它与 11 条删除段之间天然隔着 11 处挖洞；单拿 32 块去要求「零缝」在数学上不可能（那 11 处缝正是登记挖洞本身）。我给出两个正确的口径：

### B3(a) 11 条 `deleted_intervals` + 11 段 episode **原始跨度** = 22 tiles

| 序 | 区间 | 标签 |
|---|---|---|
| 1 | `[0.0, 181.0)` | deleted_1 birth_ability_ui_travel |
| 2 | `[181.0, 266.5)` | combat_001 |
| 3 | `[266.5, 320.27)` | deleted_2 travel_loot_idle_v4 |
| 4 | `[320.27, 345.0)` | combat_002 |
| 5 | `[345.0, 357.0)` | deleted_3 loot_heal_travel |
| 6 | `[357.0, 404.0)` | combat_003 |
| 7 | `[404.0, 416.99)` | deleted_4 ui_panel_selection |
| 8 | `[416.99, 444.0)` | combat_004 |
| 9 | `[444.0, 495.0)` | deleted_5 travel_loot |
| 10 | `[495.0, 517.5)` | combat_005 |
| 11 | `[517.5, 561.2)` | combat_006 |
| 12 | `[561.2, 598.25)` | deleted_6 loot_shop_ui_travel |
| 13 | `[598.25, 685.0)` | combat_007 |
| 14 | `[685.0, 726.0)` | deleted_7 traversal_loot_environment |
| 15 | `[726.0, 810.0)` | combat_008 |
| 16 | `[810.0, 910.99)` | deleted_8 trade_loot_navigation |
| 17 | `[910.99, 943.0)` | combat_009 |
| 18 | `[943.0, 948.99)` | deleted_9 traversal |
| 19 | `[948.99, 1037.0)` | combat_010 |
| 20 | `[1037.0, 1053.0)` | deleted_10 traversal |
| 21 | `[1053.0, 1127.45)` | combat_011 |
| 22 | `[1127.45, 1152.233)` | deleted_11 lobby_idle |

- `min start = 0.0`（**精确 0.0**）；`max end = 1152.233`（**精确等于 `source_duration`**）
- `Σ tile 长度 = 1152.233`（**精确**）
- **缝隙 = 0 条；重叠 = 0 条**
- **最小缝隙值：不存在（22 块严格首尾相接，相邻块差值恒为 0.0）**

### B3(b) 11 条 `deleted_intervals` + 21 段挖洞后选中区 + 11 处挖洞 = 43 tiles

- `min start = 0.0`；`max end = 1152.233`；`Σ = 1152.233`（全精确）
- **缝隙 = 0 条；重叠 = 0 条**（这才是 `[0, 1152.233]` 的**完整划分**）
- 交叉重叠枚举：deleted×deleted **0**；deleted×selected **0**；selected×selected **0**（`[495,517.5]` 与 `[517.5,561.2]` 属**首尾相接**，不算重叠）

### B3(c) 21 段选中区之间的缝隙必须逐条 = 一处登记挖洞（程序化逐条匹配）

- **挖洞算术自洽**：11 段 episode + **10** 处内部洞（`end < source_end`）= **21** 段选中区（11+10=21 ✔）。第 11 处洞是 **terminal 洞**（`end == source_end`），不产生段间缝：`combat_008 [798.35, 810.0)`。
- 场内相邻段缝隙共 **10** 处，**逐条与 `excluded_inside` 精确匹配（10/10 True，未匹配 0）**：

| 场 | 缝隙 | 值 | 匹配登记挖洞 |
|---|---|---|---|
| combat_001 | 229.0 → 234.0 | 5.0 | ✔ `[229.0, 234.0)` |
| combat_006 | 554.2 → 555.62 | 1.42 | ✔ `[554.2, 555.62)` |
| **combat_007** | **624.0 → 624.3** | **0.3** | **✔ `[624.0, 624.3)`（本轮新洞）** |
| combat_007 | 626.4 → 627.4 | 1.0 | ✔ |
| combat_007 | 630.7 → 632.4 | 1.7 | ✔ |
| combat_007 | 659.5 → 661.2 | 1.7 | ✔ |
| combat_007 | 678.6 → 679.6 | 1.0 | ✔ |
| combat_008 | 755.25 → 757.0 | 1.75 | ✔ |
| combat_008 | 779.95 → 791.9 | 11.95 | ✔ |
| combat_011 | 1100.75 → 1115.97 | 15.22 | ✔ |

- **最小缝隙值 = 0.3 s**，正是 `combat_007` 本轮新洞 `[624.0, 624.3)`；最大 = 15.22 s（`combat_011` 加载屏洞）
- 跨场相邻段（被 `deleted_intervals` 隔开的 10 处）**不算缝隙**
- 删除段 ↔ 选中区 之间唯一「看似有缝」处：`selected_17` 尾 798.35 → `deleted_8` 头 810.0 = 11.65 s，**恰为 terminal 洞 `[798.35, 810.0)` 本身**，属预期

**结论：零缝零重叠，最小缝隙 0.3 s 且已登记为挖洞。B3 = PASS。**

---

## B4 · 挖洞合规（11 处，程序化枚举） — **PASS**

`episode_geometry.timeline_hole_problems(combat_episodes_v4)` = **`[]`**（我实跑）。

逐洞枚举（判据：`start<end`、`start>=source_start`、`end<=source_end`、`0<=start<end<=1152.233`）：

| # | 场 | 洞 | 长度 | 所属场边界 | `start×60` | `end×60` | 帧对齐 | 判据 |
|---|---|---|---|---|---|---|---|---|
| 1 | combat_001 | `[229.0, 234.0)` | 5.0 | `[181.0, 266.5]` | 13740 | 14040 | 整数 | OK |
| 2 | combat_006 | `[554.2, 555.62)` | 1.42 | `[517.5, 561.2]` | 33252 | 33337.2 | 右端非整帧 | OK |
| 3 | combat_007 | `[626.4, 627.4)` | 1.0 | `[598.25, 685.0]` | 37584 | 37644 | 整数 | OK |
| 4 | combat_007 | `[630.7, 632.4)` | 1.7 | `[598.25, 685.0]` | 37842 | 37944 | 整数 | OK |
| 5 | combat_007 | `[659.5, 661.2)` | 1.7 | `[598.25, 685.0]` | 39570 | 39672 | 整数 | OK |
| 6 | combat_007 | `[678.6, 679.6)` | 1.0 | `[598.25, 685.0]` | 40716 | 40776 | 整数 | OK |
| **7** | **combat_007** | **`[624.0, 624.3)`** | **0.3** | `[598.25, 685.0]` | **37440** | **37458** | **整数** | **OK** |
| 8 | combat_008 | `[755.25, 757.0)` | 1.75 | `[726.0, 810.0]` | 45315 | 45420 | 整数 | OK |
| 9 | combat_008 | `[779.95, 791.9)` | 11.95 | `[726.0, 810.0]` | 46797 | 47514 | 整数 | OK |
| 10 | combat_008 | `[798.35, 810.0)` | 11.65 | `[726.0, 810.0]` | 47901 | 48600 | 整数 | OK（terminal 洞） |
| 11 | combat_011 | `[1100.75, 1115.97)` | 15.22 | `[1053.0, 1127.45]` | 66045 | 66958.2 | 右端非整帧 | OK |

- **逐洞 problems：none**
- **洞 × 洞 重叠（含跨场两两枚举）：none**
- **洞 × `deleted_intervals` 重叠：none**
- 洞总数 **11** == 作业书声明（比 v3 的 10 处多 1）✔

### 特别核 `combat_007` 新洞 `[624.0, 624.3)`

| 核项 | 我的实测 | 字段 / 位置 |
|---|---|---|
| 是否存在于 v4 | **True（恰好 1 条）** | `combat_episodes[id=combat_007].excluded_inside`，`start=624.0` / `end=624.3` |
| 类别 | `ui_panel_loot` | 同上 `.category` |
| 落在场内 | True（`598.25 <= 624.0`，`624.3 <= 685.0`） | `episode_bounds` |
| 帧对齐 | `624.0×60 = 37440`、`624.3×60 = 37458`，**两端均为整数帧** | — |
| 与洞①是否误合并 | **否**，`626.4 − 624.3 = 2.1 s` 交火在中间 | 改动单写的 2.1 s 与我实测**精确一致** |
| 两侧邻帧敌方红条 | **我 0 图，无法核像素。** 已核到：登记值 **166 px** 与 **241 px** 逐字出现在该洞 `reason` 字段内 | `excluded_inside[i=4].reason` |
| 该洞是否切到 `engage`/`outcome` | 否（engage 602.0、outcome 670.0 均不在洞内） | — |
| 该洞是否切到任何 `impact_points` | 否（`combat_007` 拍组 602/606/613/616/619/**632**… 无一落在 `[624.0,624.3)`） | `impact_points[]` |
| 该洞 `evidence` 字段 | **`[]`（空）** | ⚠ 见第 5 节新问题 ③ |

**结论：11 处挖洞全部合规，零重叠，新洞成立。B4 = PASS。**

---

## B5 · `needs_review` 残留 / engage_start 与 outcome_time 落位 — **PASS**

- **11 场 `needs_review` 全部为 `false`，真值残留 = 0**（我逐场枚举：`[False]×11`）
- 11 场 `complete` 全部为 `true`：`[True]×11`
- 程序化逐场落位检查（`engage_start >= source_start`、`source_start <= engage_start <= source_end`、`source_start <= outcome_time <= source_end`）→ **problems：none**

| 场 | source_start | source_end | engage_start | outcome_time | lead_in | 尾窗 | 判定 |
|---|---|---|---|---|---|---|---|
| combat_001 | 181.0 | 266.5 | 186.0 | 253.0 | 5.0 | 13.5 | OK |
| **combat_002** | **320.27** | 345.0 | **333.0** | 338.0 | **12.73** | 7.0 | OK |
| combat_003 | 357.0 | 404.0 | 359.0 | 398.0 | 2.0 | 6.0 | OK |
| combat_004 | 416.99 | 444.0 | 417.0 | 430.0 | 0.01 | 14.0 | OK |
| combat_005 | 495.0 | 517.5 | 499.0 | 512.0 | 4.0 | 5.5 | OK |
| combat_006 | 517.5 | 561.2 | 522.0 | 549.0 | 4.5 | 12.2 | OK |
| combat_007 | 598.25 | 685.0 | 602.0 | 670.0 | 3.75 | 15.0 | OK |
| combat_008 | 726.0 | 810.0 | 731.0 | 796.5 | 5.0 | 13.5 | OK |
| combat_009 | 910.99 | 943.0 | 911.0 | 930.0 | 0.01 | 13.0 | OK |
| **combat_010** | 948.99 | 1037.0 | **953.0** | 1024.0 | 4.01 | 13.0 | OK |
| combat_011 | 1053.0 | 1127.45 | 1058.0 | 1122.5 | 5.0 | 4.95 | OK |

**两个 v4 新边界的特别核**：

| 核项 | 声明值 | 我的实测 | 字段 | 判定 |
|---|---|---|---|---|
| `combat_002.source_start < engage_start` | 320.27 < 333.0 | **320.27 < 333.0 → True** | `combat_episodes[id=combat_002]` | PASS |
| `combat_002.engage_start >= source_start` | — | **True** | 同上 | PASS |
| `combat_002.outcome_time` 落位 | 不动 | 338.0 ∈ [320.27, 345.0] | 同上 | PASS（确认未动） |
| `combat_010.engage_start` | 953.0 | **953.0（精确相等）** | `combat_episodes[id=combat_010].engage_start` | PASS |
| `combat_010.source_start` | 不动 | 948.99（v3 亦 948.99，**确认未动**） | 同上 | PASS |

`combat_002` 的 `lead_in = 12.73 s` 远超规约 `lead_in 5 s`，但这被 `change_order_v4.md`「本轮**不做**的事」显式登记为越权待裁，属**已登记的已知例外**，不是 v4 新引入的缺陷。

**结论：needs_review 残留 0，11 场落位全对，两个新边界符合声明。B5 = PASS。**

---

## B6 · 坐标换算零改动（`programbounds` vs `combat_episodes_v4`） — **PASS**

`combat_episodes_v4_programbounds.json` 是**按 21 段切口展开**的节目坐标视图（`id` 形如 `combat_007#3`，带 `from_source`），不是 11 场视图；`deleted_intervals` 为 `[]`（程序坐标下删除段无节目跨度，按设计为空）。

| 核项 | 我的实测 | 判定 |
|---|---|---|
| `programbounds.combat_episodes` 条数 | **21** == 我的 21 段展开切片 | PASS |
| 逐片 `from_source[0]/[1]` vs `episode_geometry` 展开切片 | **0 diffs**（21 片 × 2 值 = 42 项） | PASS |
| 逐片 `source_start`/`source_end` vs `program_map_v4.cuts[i].program_start/program_end` | **0 diffs**（21 片 × 2 值 = 42 项） | PASS |
| 场次级：每场首片 `from_source[0]` == v4 `source_start` | **0 diffs**（11 场） | PASS |
| 场次级：末片 `from_source[1]` == v4 `source_end` | **0 diffs**（11 场）。`combat_008` 末片止于 798.35 而非 810.0，**因 terminal 洞 `[798.35, 810.0)` 吃掉尾段，属预期**，非偏差 | PASS |
| `programbounds.program_seconds_total` | 562.97（与 v4 相同） | PASS |
| `programbounds.derived_from` | 指向 `…\timeline\combat_episodes_v4.json`（真源） | PASS |

合计 **84 + 22 = 106 项边界数值比对，diff = 0**。

**结论：坐标换算零改动。B6 = PASS。**

---

## B7 · v3 → v4 的 9 项改动逐条核对（本轮重点） — **PASS（数值层面零越界）+ 2 项 WARN**

**基准**：`…\reports\change_order_v4.md`（改动依据）与 `…\timeline\combat_episodes_v3.json`（只读对照）。**方法**：把 v3 与 v4 的 `combat_episodes` / `deleted_intervals` 逐字段递归 diff（散文字段 `boundary_reason` / `notes` / `evidence` / `reason` 从数值 diff 中剔除，散文另在第 5 节单列）。

### B7.0 改动总量

- 场次级数值 diff **13 行**
- `deleted_intervals` diff（`start`/`end`/`category`）**2 行**
- 顶层标量 diff（除 meta/geometry 块）**0 行**
- **合计 15 个字段级改动**，落在 **5 场**（`combat_002` / `006` / `007` / `008` / `010`）；**另外 6 场（001 / 003 / 004 / 005 / 009 / 011）数值 diff = 0，一字未动** ✔

### B7.1 逐条核对（9 项声明 vs 我的实测 diff）

| # | 声明改动（`change_order_v4.md`） | 我的实测字段级 diff | 吻合 |
|---|---|---|---|
| **1** | `combat_002.source_start` 305.0 → **320.27** | `combat_002.source_start` 305.0 → 320.27 | ✔ |
| | `combat_002.engage_start` 310.0 → **333.0** | `combat_002.engage_start` 310.0 → 333.0 | ✔ |
| | `combat_002.impact_points` 删 **314.0 / 318.0** | v3 `[314,318,321,322,333,334,336,337,338,339,341,344]` → v4 `[321,322,333,334,336,337,338,339,341,344]`：**恰删 2 个、其余 10 个与顺序逐项不变** | ✔ |
| | `deleted_intervals[…].end` 305.0 → **320.27** | `deleted_intervals[2].end` 305.0 → 320.27 | ✔（索引见 WARN-④） |
| **2** | `combat_006` 洞① `[554.2,555.55)` → **`[554.2,555.62)`** | `combat_006.excluded_inside[0].end` 555.55 → 555.62（`start` 554.2 不变） | ✔ |
| **3** | `combat_007` **新洞** `[624.0, 624.3)` | `combat_007.excluded_inside.count` 4 → 5，且 `excluded_inside[4]` = `{624.0, 624.3, ui_panel_loot}`；原 4 洞 `[626.4,627.4)/[630.7,632.4)/[659.5,661.2)/[678.6,679.5→679.6)` 中前 3 洞**一字未动** | ✔ |
| **4** | `combat_007` 洞③ `[678.6,679.5)` → **`[678.6,679.6)`** | `combat_007.excluded_inside[3].end` 679.5 → 679.6（`start` 678.6 不变） | ✔ |
| **5** | `combat_008` 洞① `[756.2,757.0)` → **`[755.25,757.0)`** | `combat_008.excluded_inside[0].start` 756.2 → 755.25（`end` 757.0 不变） | ✔ |
| **6** | `combat_008` 洞② `[781.0,791.9)` → **`[779.95,791.9)`** | `combat_008.excluded_inside[1].start` 781.0 → 779.95（`end` 791.9 不变） | ✔ |
| **7** | `combat_008` 尾洞 `[797.9,810.0)` → **`[798.35,810.0)`**（收窄 +0.45） | `combat_008.excluded_inside[2].start` 797.9 → 798.35（`end` 810.0 不变） | ✔ |
| **8** | 纯标注 `combat_010.engage_start` 949.0 → **953.0** | `combat_010.engage_start` 949.0 → 953.0 | ✔ |
| | 纯标注 `combat_010.impact_points` 949.0 → **950.0** | v3 首元素 `949.0` → v4 首元素 `950.0`；**其余 28 个元素与顺序逐项不变，条数 29 未变** | ✔ |
| **9** | 纯标注 `combat_010.event_types` 去掉 `'revive'` | v3 `["kill","downed","revive","escape","loot"]` → v4 `["kill","downed","escape","loot"]`：**恰删 `revive` 一个，其余 4 个与顺序不变** | ✔ |

**9 项声明全部落地，且每一项都只改了该改的那一个/那几个字段，无一项被顺手扩大。**

### B7.2 总量守恒（我用 v3 独立重算 v4 应得值，再与 v4 实测对撞）

| 步 | 改动 | 我的实测秒 |
|---|---|---|
| 起点 | v3 `episode_geometry.timeline_program_seconds`（我重算） | **580.26**（v3 `raw_span=630.93`、洞 10 处 50.67 s，与 `v3_geometry` 声明一致） |
| 改动 1 | `combat_002` 头 305.0 → 320.27 | **−15.27** |
| 改动 2 | `combat_006` 洞右端 555.55 → 555.62 | **−0.07** |
| 改动 3 | `combat_007` 新洞 `[624.0, 624.3)` | **−0.30** |
| 改动 4 | `combat_007` 洞③ 右端 679.5 → 679.6 | **−0.10** |
| 改动 5 | `combat_008` 洞① 起 756.2 → 755.25 | **−0.95** |
| 改动 6 | `combat_008` 洞② 起 781.0 → 779.95 | **−1.05** |
| 改动 7 | `combat_008` 尾洞起 797.9 → 798.35 | **+0.45** |
| | **7 步合计** | **−17.29** |
| 推得 | `580.26 − 17.29` | **562.97** |
| 实测 | v4 `episode_geometry.timeline_program_seconds` | **562.97** |

**`580.26 + (−17.29) = 562.97` 与 v4 实测逐位吻合（差 0）。改动总量守恒。**

### B7.3 唯一 1 项「未在 9 项声明内」的字段改动

| 字段 | v3 | v4 | 性质 |
|---|---|---|---|
| `deleted_intervals[2].category` | `travel_loot_idle` | **`travel_loot_idle_v4`** | 纯标签（后缀 `_v4`），对任何边界、时长、门禁**零影响** |

**评估：不判 FAIL。** 理由：这条 `deleted_intervals[2]` 本身就是改动 1 已声明在范围内的区间（其 `end` 已被改动 1 修改），标签改名发生在**同一条已被授权修改的记录**上，属于同一笔改动内的自我标识，不是「顺手改了别的场/别的洞」。但它**确属 `change_order_v4.md` 9 项清单之外的第 15 个字段级改动**，改动单没有登记 → 登记为 **WARN-①**。

**结论：v3 → v4 的 9 项改动逐条核对通过，只改了该改的、没顺手改别的；无一处越界改动。B7 = PASS。**

---

## 第 5 节 · 我发现的**新问题**（7 项，均不构成 B1–B8 的 FAIL）

### ⚠① 5 处被改动场次的 `boundary_reason` / `notes` / 洞 `reason` **散文在 v4 一字未改**，与 v4 自身数值矛盾

**位置**：`…\timeline\combat_episodes_v4.json`

我把 v3 与 v4 的散文字段做了 `==` 比较，结果：

| 场 | `boundary_reason` 与 v3 相同 | `notes` 与 v3 相同 | 结果 |
|---|---|---|---|
| combat_002 | **True** | **True** | 散文仍写已作废的旧值 |
| combat_006 | True | True | 洞① `reason` 仍写 `[554.2, 555.55)` |
| combat_007 | True | True | 洞③ `reason` 仍写「v3 取略宽于实测的 `[678.6, 679.5)`」 |
| combat_008 | True | True | 三处洞 `reason` 仍写 v3 的 756.2 / 781.0 / 797.9 |
| combat_010 | True | True | 仍写 v3 的 949.0 / 954.0 |

**具体矛盾点**：

- `combat_002.boundary_reason` 首句仍是「**头界 305.0 = engage 310.0 − lead_in 5s**」，而 v4 实际是 `source_start=320.27` / `engage_start=333.0`。
- `combat_002.notes` 仍含「**本场四个边界一字未动**」「**四个边界与 v2 一字未动**」，两处已被改动 1 推翻；也仍含被删的 impact_point 秒点 `314`。
- `combat_002.evidence.head` 仍引 `t0305.0.jpg` / `t0306.0.jpg` / `t0309.0.jpg` —— 这三帧现在落在**删除段 `[266.5, 320.27)` 内**，即被当成了已被删素材的头界取证。
- `combat_010.boundary_reason` 仍含「★【v3 · A9 engage_start 由 954.0 前移到 **949.0**】」，v4 已把 949.0 再改到 953.0，且**没有任何 v4 段落**记录 953.0 这个值与它的新依据。
- `combat_010` 全文**不出现「v4」二字**；`combat_006` / `combat_008` 同样不出现「v4」二字（`combat_002` / `combat_007` 的「v4」只来自 `deleted_intervals[2].category` 标签后缀与新洞的 `reason` 开头 `v4 NEW.`）。

**影响面（我已实测确认）**：`validate_combat_timeline.py` 只读 `source_start/source_end/engage_start/outcome_time/complete/needs_review/excluded_inside/deleted_intervals`；我对 `qa_gate.py` 做了全文 grep，**`boundary_reason` / `notes` / `impact_points` / `event_types` / `confidence` 一次都没出现**。⇒ **散文过期对任何门禁、渲染、时长零影响**，纯粹是文档可追溯性缺口。

**为何是新问题**：v1→v2→v3 每一轮都遵循了「在 `boundary_reason`/`notes` 里加一段 ★【v3 · A#】/★【v2 · …】」的既定体例（我在 v4 散文里读到大量 v2/v3 段落可证），**v4 是第一轮破例**：15 个数值字段全改，而配套叙述 100% 未同步。

**建议（不属我职权，交指挥处置）**：要么补写 5 段 v4 说明，要么在 `v4_change_summary` 里显式声明「v4 只改数值字段、不改 prose」。

### ⚠② `change_order_v4.md`「预计影响」表的**改动 4 秒数写错 0.05 s**，导致表内合计与实测差 0.05 s

**位置**：`…\reports\change_order_v4.md`「## 预计影响」表

| 改动单写的 | 我实测 |
|---|---|
| 改动 4 = **−0.05** | `679.6 − 679.5` = **−0.10** |
| 「v4 预计节目总时长」= **≈563.02** | v4 实测节目秒 = **562.97**（差 **+0.05**） |

其余 6 行（−15.27 / −0.07 / −0.30 / −0.95 / −1.05 / +0.45）**全部与实测精确相符**。**时间线本身是对的**（`580.26 − 17.29 = 562.97` 逐位吻合，见 B7.2）—— 是改动单的算术笔误。

**附一条观察**：改动单的 563.02 恰好等于 `ffprobe` 读到的**预览容器时长 563.021**，而不等于节目秒 562.97。**怀疑是把容器时长误当成节目秒填进了「预计节目总时长」栏**。建议在改动单里把「节目秒 562.97」与「容器时长 563.021」分两栏写。

### ⚠③ `combat_007` 新洞 `[624.0, 624.3)` 的 `evidence` 字段是**空数组 `[]`**

**位置**：`combat_episodes_v4.json` → `combat_episodes[id=combat_007].excluded_inside[4].evidence`

其余 10 处挖洞的 `evidence` 都有 2–8 条帧/工具路径；**唯独本轮唯一新增的洞是空的**。它的 `reason` 里只有文字化的像素读数（右侧区域边缘密度 1320–1335 vs 干净本底 ~740；两侧敌方红条 166 / 241 px），**没有指向任何可复算的帧文件或脚本**。

我 0 图，无法核这些像素；但从可追溯性看，**这是 v4 唯一一处无取证路径的挖洞**，且它是改动单自认的「**本轮唯一一处真正新增的接缝**，渲染后须专门复核观感」。建议补 `evidence` 路径（指向帧文件），否则该新接缝在复验时无法被第二人独立重算。

### ⚠④ `change_order_v4.md` 改动 1 的表格索引写错（`deleted_intervals[1]` 实为 `deleted_intervals[2]`）

**位置**：`…\reports\change_order_v4.md` 改动 1 表格第 4 行

改动单写「`deleted_intervals[1].end` 305.0 → 320.27」。v3 的 `deleted_intervals[1]`（1-based）是 `[0.0, 181.0)`，其 `end` 从来不是 305.0；**真正被改的是 `deleted_intervals[2]` = `[266.5, 305.0) → [266.5, 320.27)`**（我的程序化 diff 也定位在 `del[2]`）。索引差 1。纯文档笔误，不影响数据。

### ⚠⑤ 改动 3 的「节目 → 源」换算用的是 **v3 时钟**，v4 里的实际节目位置不同

**位置**：`…\reports\change_order_v4.md` 改动 3 第 2 条

改动单写「节目 `P [285.11, 285.41)`（cut#9，`S = 598.25 + (P − 259.36)`）」。`259.36` 是**v3** 版该片的 `program_start`；v4 里该片（`cuts[8]`）的 `program_start` 是 **244.02**。

⇒ 同一段源 `[624.00, 624.30)` 的**真实 v4 节目位置是 `P [269.77, 270.07)`**（我由 `program_map_v4.json` 的 `cuts[8]`/`cuts[9]` 反算），而改动单写的 `P 285.11–285.41` 落在 v4 节目 **P 285 附近的另一场内容**上。

成片不受影响（时间线是源驱动的，边界值正确、渲染正确），但**任何照改动单的 P 值去复核该新洞观感的人，会抽到错的帧**。建议把该行改成 v4 节目钟或直接只留源钟。

### ⚠⑥ `v4_geometry` 比 `v3_geometry` 少了三个键，铺满证明不再自带

**位置**：`combat_episodes_v4.json` → `v3_geometry` vs `v4_geometry`

| 键 | v3_geometry | v4_geometry |
|---|---|---|
| `hole_problems` | 有（`[]`） | **缺** |
| `tile_count` | 有（`22`） | **缺** |
| `coverage` | 有（`"[0.0, 1152.233] 零缝零重叠（22 tiles 严格相接）"`） | **缺** |

v3 自带铺满声明，v4 不带了。**我已独立枚举补上这个证明**（B3(a) 22 tiles 与 B3(b) 43 tiles 均 0 缝 0 重叠、端点精确），所以这是**文档能力退步、不是缺陷**。建议 v4 补回这三个键以保持冻结件自证能力。

### ⚠⑦ `combat_002` 的 `lead_in` = 12.73 s，已被改动单登记为「越权待裁」，但 v4 把该段的**头界**改到了一个「无可见交战」区间的正中

**位置**：`combat_episodes_v4.json` → `combat_episodes[id=combat_002]`；`…\reports\change_order_v4.md`「本轮**不做**的事」第 1 行

`engage_start=333.0`、`source_start=320.27` ⇒ `lead_in = 12.73 s`，是规约 `lead_in 5 s` 的 2.5 倍。改动单自己写明「`S 320.27–333.0` 这 12.73 s 仍无可见交战 → 裁决员主动登记为越权待裁，本轮不动」。

我**不重复判**（这是已登记的已知例外，且作业书要求 B 只核数字不重判内容），仅提示一条**数字层面**的事实：改动 1 的净效果是把该段的**无效前置从 v3 的 5.0 s（305.0→310.0）扩大到 12.73 s**，而这 12.73 s 全部无可见交战。也就是说 **v4 在这一项上的净收益是负的**——它按 E9 例外「超授权」把 15.27 s 挪走，却换来一个比原来更长的无交战前置。这与改动单的立论（例外被事实推翻、不能靠登记豁免）在方向上自洽，但**代价未被登记进「预计影响」表**（该表只记了 −15.27 s 的时长影响，没记 lead_in 从 5.0 s 涨到 12.73 s）。建议在例外台账里补记这一条。

---

## 附：8 项汇总

| 项 | 主题 | 判定 |
|---|---|---|
| **B1** | validate 复核（重跑 + 对象级相等） | **PASS** |
| **B2** | 分段求和（`episode_geometry` 重算 + 21 cuts 逐条） | **PASS** |
| **B3** | 源铺满（程序化枚举，零缝零重叠） | **PASS** |
| **B4** | 挖洞合规（11 处，含新洞 `[624.0,624.3)`） | **PASS** |
| **B5** | `needs_review` 残留 0 + engage/outcome 落位 | **PASS** |
| **B6** | 坐标换算零改动（programbounds 106 项 diff = 0） | **PASS** |
| **B7** | v3→v4 的 9 项改动逐条核对 | **PASS**（含 1 项未登记标签改名 + 2 项 WARN） |
| **B8** | 本报告格式与结尾 STATUS 行 | **PASS** |

**未做的事（按纪律）**：未抽帧 / 未看图（0 张）；未跑 whisper / scenedetect / auto-editor；未重渲预览；未运行 4K 渲染；未安装/升级任何包；未改 `timeline\` / `preview\` / v1/v2/v3 任何文件；未删除任何文件或目录；未新建 `.ps1`；未写出 TASK 目录以外的任何路径；只写了本文件与 `reports\acceptB_revalidate_v4.json`（临时脚本与原始日志在 `TASK\cache\`，文件名均带 `_acceptB_v4` 前缀）。

STATUS: PASS
