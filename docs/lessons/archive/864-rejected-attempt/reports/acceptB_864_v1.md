# 独立数字验收 B 角色报告 — 任务 864 v1 时间线

- **角色**：时间线数字验收员（独立验收角色 B）
- **独立性声明**：本人**未参与**本版任何执行 —— 没写过 `combat_episodes_v1.json`、没渲过 `864-review-v1.mp4`、没做过任何 seg 扫描。所有数字均由本人从原始产物**重新计算**，不采信任何他人报告中的结论。
- **纪律遵守**：全程只读（`dir` / 读文本 JSON / 项目 Python 只读算术 / `ffprobe` / `stat`）。未跑 whisper / scenedetect / auto-editor，未渲染，未安装，未新建环境。**看图 0 张**。
- **唯一写入的两个文件**（均经任务书明确授权）：
  1. `C:\Project\永劫无间\123\21.864永劫无间 2026-09-30 02-57-13\reports\acceptB_864_v1.md`（本报告）
  2. `C:\Project\永劫无间\123\21.864永劫无间 2026-09-30 02-57-13\reports\acceptB_revalidate_v1.json`（第 1 项要求的复现校验输出）
- **TASK** = `C:\Project\永劫无间\123\21.864永劫无间 2026-09-30 02-57-13`（下文简称 `TASK\`）
- **Python** = `C:\Project\永劫无间\.video-tools\venv\Scripts\python.exe`（3.12.10，venv 基座为系统 Python）
- **FFprobe** = `C:\Project\永劫无间\.video-tools\LosslessCut\resources\ffprobe.exe`（n8.0-23）
- **几何模块** = `C:\Project\永劫无间\skills\naraka-highlight-studio\scripts\episode_geometry.py`（本人以 `sys.path.insert` 导入，未修改）

---

## 1. validate pass 复核

### 1.1 重读原始校验结果

| 检查项 | 我的实测值 | 依据（绝对路径 + 字段） | 判定 |
|---|---|---|---|
| `pass` 顶层标志 | `true` | `TASK\reports\v1_validate.json` → 顶层 `pass`（第 309 行） | PASS |
| `episode_count` | `11` | 同上 → `episode_count`（第 4 行） | PASS |
| `checks` 条数 | **32** | 同上 → `len(checks)` = 32（第 5–307 行数组） | PASS |
| `warnings` 条数 | **0**（空数组 `[]`） | 同上 → `warnings`（第 308 行） | PASS |
| `pass == false` 的 check 名 | **无（0 条）** | 本人遍历 32 条 `checks`，`c.get("pass") is False` 的集合为空 | PASS |
| `schema` | `naraka-combat-roughcut-qa/v1` | 同上 → `schema`（第 2 行） | PASS |
| `timeline` 指向 | `...\timeline\combat_episodes_v1.json`（**源坐标真源**，非 programbounds） | 同上 → `timeline`（第 3 行） | PASS |

### 1.2 `checks` 32 条的名称构成（本人逐条分类计数）

| 类别 | 条数 | 说明 |
|---|---|---|
| `episodes_non_empty` | 1 | `count: 11` |
| `episode_001` … `episode_011` | 11 | 逐场几何 + 标注校验，全 `pass: true` |
| `source_duration_valid` | 1 | `source_duration: 1152.233` |
| `program_sum_seconds` | 1 | `program_sum: 614.9` |
| `in_segment_holes_excavated` | 1 | `excavated_seconds: 15.1`，`raw_span: 630.0`，`hole_count: 1`（标注为 informational） |
| `in_segment_holes_valid` | 1 | `problems: []` |
| `deleted_interval_1` … `deleted_interval_16` | 16 | 每条 `overlaps_selected: false` |
| **合计** | **32** | 与 `len(checks)` 一致 |

### 1.3 `warnings` 逐条分类

| 分类 | 条数 | 明细 |
|---|---|---|
| 预期内 | **0** | — |
| 需点名 | **0** | — |
| 需处理 | **0** | — |

**结论**：`warnings` 为空数组，**0 条待分类**。11 场全部 `complete: true` / `needs_review: false`（本人另在原始 JSON 上复核，见 §1.5），因此 `validate_combat_timeline.py` 的 `needs_review` 告警分支（该脚本第 132–133 行）一次都没触发。

### 1.4 自己再跑一遍 validate（可复现性）

```
& 'C:\Project\永劫无间\.video-tools\venv\Scripts\python.exe' `
  'C:\Project\永劫无间\skills\naraka-highlight-studio\scripts\validate_combat_timeline.py' `
  'C:\Project\永劫无间\123\21.864永劫无间 2026-09-30 02-57-13\timeline\combat_episodes_v1.json' `
  --source-duration 1152.233 `
  --output 'C:\Project\永劫无间\123\21.864永劫无间 2026-09-30 02-57-13\reports\acceptB_revalidate_v1.json'
```

stdout：`{"pass": true, "episodes": 11, "output": "...\reports\acceptB_revalidate_v1.json"}`，**退出码 0**。

| 检查项 | 我的实测值 | 依据 | 判定 |
|---|---|---|---|
| 复现 `pass` | `true`（与原文件一致） | `TASK\reports\acceptB_revalidate_v1.json` → 顶层 `pass` | PASS |
| 复现 `episode_count` | `11` | 同上 | PASS |
| 复现 `checks` 条数 | `32`（与原文件相同） | 本人 `len()` | PASS |
| 复现 `warnings` | `[]` | 同上 | PASS |
| check 名称列表 | **完全一致**（顺序也一致） | 本人逐项比对 | PASS |
| 32 条 check 的字段载荷 | **零差异**（逐条逐键比较，无任何键值不同） | 本人 diff | PASS |

**可复现性判定：PASS。** 两次运行产出**语义完全相同**的 32 条检查，说明 `v1_validate.json` 不是手写、不是陈旧、不是对着旧版时间线跑的。

### 1.5 附带复核（源坐标真源的标注自洽性）

| 检查项 | 我的实测值 | 依据 | 判定 |
|---|---|---|---|
| `source_start <= engage_start <= outcome_time <= source_end` | **11/11 成立，0 违反** | `TASK\timeline\combat_episodes_v1.json` → `combat_episodes[]` | PASS |
| `complete == true` | 11/11 | 同上 | PASS |
| `needs_review == true` | 0/11 | 同上 | PASS |

### 1.6 附带：两轮 qa_gate 的 WARN 逐条分类（补充材料，不属本项判据）

`validate` 自身 0 告警。为完整起见，把 `qa_gate` 的 WARN 也点名（这两个文件不属于本项五项判据，但 WARN 需要有人认领）：

| WARN 名 | `qa_v1.json` | `qa_v1_programbounds.json` | 分类 | 说明 |
|---|---|---|---|---|
| `subtitle_span` | WARN（"no srt"） | **PASS**（"51 cues"） | 已消解 | 源坐标跑且不传 `--srt` → 第 410 行走 `no srt` 分支；这是 §5 的时钟错配误报 |
| `subtitle_stats` | WARN（"no stats"） | **PASS**（51） | 已消解 | 同上，第 411 行 |
| `media_filters` | WARN | WARN | **需点名** | `measured: "see render/selfaudit evidence"`（`qa_gate.py` 第 384 行硬编码 WARN，本门禁不重解码）。证据在渲染/自审侧，**不属数字验收范围** |
| `no_burned_variant` | WARN | WARN | **需点名（预期内）** | `measured: "no master"`（`qa_gate.py` 第 274 行）。尚未出 4K 成片，**这正是禁烧录规则的正确前置状态**，非缺陷 |

**2 条残留 WARN 均非本角色五项判据，且都不是缺陷。** 无需处理项。

---

## 2. 分段求和

本人以 `episode_geometry` 的两个函数独立重算，与 `program_map_v1.json` 头部核对。

| 检查项 | 我的实测值 | 依据（绝对路径 + 字段） | 判定 |
|---|---|---|---|
| `timeline_program_seconds(combat_episodes)` | **614.9** | 本人 `sys.path.insert(<skills>\scripts)` 后调 `episode_geometry.timeline_program_seconds`，入参为 `TASK\timeline\combat_episodes_v1.json` 的 `combat_episodes[]` | — |
| `timeline_raw_span_seconds(combat_episodes)` | **630.0** | 同上，`timeline_raw_span_seconds` | — |
| `program_map_v1.json` 头部 `program_seconds_total` | **614.9** | `TASK\timeline\program_map_v1.json` 第 6 行 | — |
| **0.01 秒级核对** `|614.9 − 614.9|` | **0.000000** | 本人实算 | **PASS** |
| 两个数字（本人算 / 文件头） | **614.9 / 614.9** | 见上 | PASS |

**未扣洞原始跨度 Σ(source_end − source_start) = 630.0 s。**

**630.0 − 614.9 = 15.1 s，这个差就是挖洞秒数。** 与 `v1_validate.json` 的 `in_segment_holes_excavated` 字段（`excavated_seconds: 15.1`，`raw_span: 630.0`，`hole_count: 1`）独立吻合。全片仅 1 个洞，落在 `combat_011` 内部，类别 `loading_screen`。

### 2.1 逐场明细：`(source_end − source_start) − Σholes` 与该场节目贡献

| # | episode id | source_start | source_end | 原始跨度 | Σholes | **净节目贡献** | 切分段数 | 切分段（源坐标） |
|---|---|---|---|---|---|---|---|---|
| 1 | `combat_001` | 181.00 | 266.00 | 85.00 | 0.00 | **85.00** | 1 | [181.00, 266.00] |
| 2 | `combat_002` | 305.00 | 345.00 | 40.00 | 0.00 | **40.00** | 1 | [305.00, 345.00] |
| 3 | `combat_003` | 357.00 | 404.00 | 47.00 | 0.00 | **47.00** | 1 | [357.00, 404.00] |
| 4 | `combat_004` | 412.00 | 442.00 | 30.00 | 0.00 | **30.00** | 1 | [412.00, 442.00] |
| 5 | `combat_005` | 495.00 | 517.50 | 22.50 | 0.00 | **22.50** | 1 | [495.00, 517.50] |
| 6 | `combat_006` | 517.50 | 556.50 | 39.00 | 0.00 | **39.00** | 1 | [517.50, 556.50] |
| 7 | `combat_007` | 597.00 | 685.00 | 88.00 | 0.00 | **88.00** | 1 | [597.00, 685.00] |
| 8 | `combat_008` | 716.00 | 800.00 | 84.00 | 0.00 | **84.00** | 1 | [716.00, 800.00] |
| 9 | `combat_009` | 911.00 | 943.00 | 32.00 | 0.00 | **32.00** | 1 | [911.00, 943.00] |
| 10 | `combat_010` | 949.00 | 1037.00 | 88.00 | 0.00 | **88.00** | 1 | [949.00, 1037.00] |
| 11 | `combat_011` | 1053.00 | 1127.50 | **74.50** | **15.10** | **59.40** | **2** | [1053.00, 1100.80] + [1115.90, 1127.50] |
| | **合计** | | | **630.00** | **15.10** | **614.90** | **12** | |

依据：`TASK\timeline\combat_episodes_v1.json` → `combat_episodes[]`（`source_start` / `source_end` / `excluded_inside`），逐场经 `episode_geometry.episode_bounds()` / `episode_holes()` / `episode_segments()` 计算。

**逐行校验通过**：每行「原始跨度 − Σholes = 净节目贡献」都成立；12 个切分段的净贡献之和 = 614.90，与头部 614.9 零差。
`timeline_hole_problems(combat_episodes)` 返回 `[]`（洞全合法：正长度、落在各自 episode 内、未吃掉整场）。

### 2.2 全源时长闭环恒等式（附加证据）

| 量 | 值 | 依据 |
|---|---|---|
| Σ episode 原始跨度 | 630.000 | `episode_geometry.timeline_raw_span_seconds` |
| Σ `excluded_inside` 洞 | 15.100 | 630.000 − 614.900 |
| 节目秒 | 614.900 | `timeline_program_seconds` |
| Σ `deleted_intervals` | 522.233 | `TASK\timeline\combat_episodes_v1.json` → `deleted_intervals[]` 16 条逐条求和 |
| **630.000 + 522.233** | **1152.233** | = 源时长，**差 0.000000** |
| 614.900 + 522.233 + 15.100 | 1152.233 | 同上，**差 0.000000** |

源时长 1152.233 已由本人独立 `ffprobe` 复核：`E:\PR导出\864永劫无间 2026-09-30 02-57-13.mp4` 的 `format.duration` = **1152.233333**（与 1152.233 差 0.000333，为时间基取整）。

**判定：PASS。** 630.0 s 原始跨度里 15.1 s 被 `excluded_inside` 挖掉，剩 614.9 s 上节目；再补上 522.233 s 的删除段，**源时间轴一秒不多一秒不少**。

---

## 3. 单调、无重叠、无缝覆盖

### 3.1 episode 按 `source_start` 排序后的逐对检查

排序结果与文件原始顺序**完全相同**（时间线本身即已按源时间单调排列）。

| 相邻对 | prev.source_end | next.source_start | gap | 判定 |
|---|---|---|---|---|
| 001 → 002 | 266.00 | 305.00 | +39.00 | OK |
| 002 → 003 | 345.00 | 357.00 | +12.00 | OK |
| 003 → 004 | 404.00 | 412.00 | +8.00 | OK |
| 004 → 005 | 442.00 | 495.00 | +53.00 | OK |
| **005 → 006** | **517.50** | **517.50** | **+0.00** | **OK（首尾相接，非重叠）** |
| 006 → 007 | 556.50 | 597.00 | +40.50 | OK |
| 007 → 008 | 685.00 | 716.00 | +31.00 | OK |
| 008 → 009 | 800.00 | 911.00 | +111.00 | OK |
| 009 → 010 | 943.00 | 949.00 | +6.00 | OK |
| 010 → 011 | 1037.00 | 1053.00 | +16.00 | OK |

| 检查项 | 我的实测值 | 依据 | 判定 |
|---|---|---|---|
| 相邻对总数 | 10 | 本人对 11 场排序后取 `zip(ordered, ordered[1:])` | — |
| **违反 `next.source_start >= prev.source_end` 的对数** | **0** | 同上 | **PASS** |
| 最小 gap | **+0.00**（`combat_005`/`combat_006` 共享边界 517.50） | `TASK\timeline\combat_episodes_v1.json` | PASS |
| `0 <= source_start < source_end <= 1152.233` | 11/11 成立 | 同上 | PASS |

`combat_005` / `combat_006` 在源秒 517.50 处共享边界是**岛式合并点**：节目侧对应切点 224.50，两段 22.5 s（1350 帧）+ 39.0 s（2340 帧），**不重复帧、不丢帧**（见 §4 帧数核对）。

### 3.2 `deleted_intervals` 自身的单调性

| 检查项 | 我的实测值 | 依据 | 判定 |
|---|---|---|---|
| 相邻对总数 | 15 | `TASK\timeline\combat_episodes_v1.json` → `deleted_intervals[]` | — |
| **重叠对数** | **0** | 本人排序后逐对比较 | PASS |
| 首起点 | `0.0` | `deleted_intervals[0].start` | PASS |
| 末终点 | `1152.233` | `deleted_intervals[15].end`（`lobby_idle`） | PASS |

### 3.3 episodes + deletions 合并后是否**精确铺满** `[0, 1152.233]`

本人做了三种口径的铺满检查，全部列出：

**口径 A — 27 个区间（11 个 episode 原始边界 + 16 个 deletion）**

| 检查项 | 我的实测值 | 判定 |
|---|---|---|
| 区间数 | **27** | — |
| 首起点 | **0.000000**（需 0.0，差 0.000000） | PASS |
| 末终点 | **1152.233000**（需 1152.233，差 0.000000） | PASS |
| 相邻对数 | 26 | — |
| **缝隙（\|差\| > 0.01）** | **无（0 条）** | **PASS** |
| **重叠（差 < −0.01）** | **无（0 条）** | **PASS** |
| 区间长度合计 | **1152.233000**，与 `source_duration` 差 **0.000000** | **PASS** |

> **「零缝零重叠」判定：PASS —— 27 个区间无缝无重叠精确铺满 `[0, 1152.233]`。**

**口径 B — 28 个区间（12 个「已挖洞」切分段 + 16 个 deletion）**

| 检查项 | 我的实测值 | 判定 |
|---|---|---|
| 区间数 | 28 | — |
| 长度合计 | 1137.133000，与 `source_duration` 差 **15.100000** | — |
| 缝隙（> 0.01） | **恰好 1 条**：`combat_011` part0 末 1100.80 → part1 首 1115.90，gap = **15.10** | 见下 |
| 重叠 | 无（0 条） | PASS |

**这 15.10 s 不是缺陷，而是那 1 个已声明的洞**：`combat_011.excluded_inside[0] = {start: 1100.8, end: 1115.9, category: "loading_screen"}`，长度 1115.9 − 1100.8 = **15.10**，与缺口**逐位相等**。按 `episode_geometry` 的 schema 定义，洞写在 `excluded_inside` 而**不是** `deleted_intervals`（后者是"整段不要"，前者是"场内部挖掉"）。`v1_validate.json` 的 `in_segment_holes_excavated.excavated_seconds = 15.1` 独立印证。

**口径 C — 29 个区间（口径 B + 把该洞计为第 29 个排除区间）**

| 检查项 | 我的实测值 | 判定 |
|---|---|---|
| 区间数 | **29** | — |
| 首起点 / 末终点 | 0.000000 / 1152.233000 | PASS |
| **缝隙 / 重叠** | **各 0 条** | **PASS** |
| 长度合计 | **1152.233000**，与 `source_duration` 差 **0.000000** | **PASS** |

> **综合判定：PASS。** 源时间轴被 27 个「边界区间」无缝无重叠精确铺满；唯一的 15.10 s 内部缺口由 `excluded_inside` 显式声明并被 §2 的 15.1 s 扣减完全吸收。把洞计为排除区间后，29 个区间同样零缝零重叠铺满全源。

### 3.4 每一对 (deletion, episode) 不重叠检查

| 检查项 | 我的实测值 | 依据 | 判定 |
|---|---|---|---|
| (deletion × episode) 对数 | **176**（16 × 11） | 本人双重循环 | — |
| **重叠对数** | **0** | 本人 `del.start < ep.end and ep.start < del.end` | **PASS** |
| (deletion × 挖洞后切分段) 对数 | 192（16 × 12） | 同上 | — |
| **重叠对数** | **0** | 同上 | **PASS** |

（口径 B 的那 15.10 s 缺口**没有**被任何 deletion 覆盖 —— 已由 §3.3 确认为纯洞，不存在「洞与删除段重复扣时」。）

---

## 4. ffprobe 时长对照

本人**自己**跑 ffprobe 采数，不复用 `reports\preview_probe_v1.json`（该文件由渲染侧产出，属他人报告结论）。

```
& 'C:\Project\永劫无间\.video-tools\LosslessCut\resources\ffprobe.exe' -v error `
  -print_format json -show_format -show_streams `
  'C:\Project\永劫无间\123\21.864永劫无间 2026-09-30 02-57-13\preview\864-review-v1.mp4'
```

被测文件：`TASK\preview\864-review-v1.mp4`，802,410,248 字节（765.24 MB），mtime 2026/9/30 14:38:42。

| 检查项 | 我的实测值 | 依据（ffprobe 字段） | 判定 |
|---|---|---|---|
| `format.duration` | **614.921333** | `format.duration` | — |
| 节目总秒（本人 §2 实算） | 614.9 | `episode_geometry.timeline_program_seconds` | — |
| **差值 `\|614.921333 − 614.9\|`** | **+0.021333 s** | 本人实算 | **PASS**（在 ±0.3 s 内，记为舍入） |
| `format.nb_streams` | **2** | `format.nb_streams` | PASS |
| `format.bit_rate` | 10,439,192 bps | `format.bit_rate` | — |

### 4.1 `streams[]` 逐流检查

| 检查项 | 我的实测值 | 依据 | 判定 |
|---|---|---|---|
| 流构成 | video **1** + audio **1** + subtitle **0** + 其他 **0** | `streams[].codec_type` | PASS |
| **`codec_type == "subtitle"` 的流数** | **0** | `streams[]` 全量遍历 | **PASS（必须为 0，已满足）** |
| video `duration` | **614.900000** | `streams[0].duration` | — |
| audio `duration` | **614.921333** | `streams[1].duration` | — |
| **\|video − audio\| 时长差** | **0.021333 s** | 本人实算 | **PASS**（≤ 0.2 s） |
| `\|video.duration − 614.9\|` | **0.000000 s**（视频轨与节目**帧级精确**） | 本人实算 | **PASS** |
| `\|audio.duration − 614.9\|` | 0.021333 s | 本人实算 | — |
| 该 0.021333 s 的来源 | **恰等于 1 个 AAC 帧量子 `1024/48000 = 0.021333 s`** | 本人比对，差 < 1e-6 | 已解释，非节目误差 |
| video `start_time` | 0.021029 | `streams[0].start_time` | — |
| audio `start_time` | 0.000000 | `streams[1].start_time` | — |
| 音画起始偏移 `\|Vstart − Astart\|` | **0.021029 s** | 本人实算 | **PASS**（≤ 0.2 s） |
| video `avg_frame_rate` | **`60/1`** | `streams[0].avg_frame_rate` | — |
| video `r_frame_rate` | **`60/1`** | `streams[0].r_frame_rate` | — |
| **`avg_frame_rate == r_frame_rate`** | **是 → CFR 成立** | 本人比对 | **PASS** |
| video `nb_frames` | **36,894** | `streams[0].nb_frames` | — |
| `nb_frames / 60` | 614.900000，与 `streams[0].duration` **零差** | 本人实算 | PASS（独立佐证 CFR，无 VFR 填充） |
| `duration_ts / time_base` | 9,444,864 / (1/15360) = 36,894 帧 | 本人实算 | PASS |
| 分辨率 / 编码 | 1280×720，h264 **High**，yuv420p | `streams[0]` | 与 `program_map_v1.json` 头部 `preview_width/height=1280/720` 一致 |
| 视频码率 | 10,266,612 bps | `streams[0].bit_rate` | — |
| 音频 | AAC-LC，48,000 Hz，2 ch，160,342 bps | `streams[1]` | — |
| 帧对齐（12 段 × 60） | 12 段长度**全部**为 1/60 s 整数倍（5100/2400/2820/1800/1350/2340/5280/5040/1920/5280/2868/696），合计 **36,894** = `nb_frames` | `TASK\timeline\program_map_v1.json` → `cuts[].source_duration` | PASS |

> **判定：PASS。** 视频轨 614.900000 s 与节目 614.9 s **零误差**；`format.duration` 的 0.021333 s 超出完全等于一个 AAC 帧量子，是容器音频尾帧取整，不是节目时长错误。0 条字幕流（禁内嵌要求满足）。CFR 成立（`avg_frame_rate == r_frame_rate == 60/1`，且帧数/60 与流时长零差双重佐证）。

---

## 5. 字幕条数与断裂

### 5.1 SRT 实际条数与 stats 对账

本人自行解析 SRT（不采信 `stats.count` 与 `crosscheck.cue_count`）：

| 检查项 | 我的实测值 | 依据 | 判定 |
|---|---|---|---|
| SRT 路径 | `TASK\captions\864-review-v1.srt`（2,923 字节） | `stat` | — |
| **本人实 parses 的条数** | **51** | 本人按空行切块 + 正则解析时间行 | — |
| `stats.json` 的 `count` | **51** | `TASK\captions\864-review-v1.stats.json` → `count` | — |
| `stats.json` 的 `total` | 51 | 同上 → `total` | — |
| **对账结果 51 == 51** | **一致** | 本人实算 | **PASS** |
| `crosscheck.cue_count` | 51 | `TASK\reports\srt_crosscheck_v1.json` → `cue_count` | 一致 |
| `crosscheck.stats_declared_count` / `stats_match` | 51 / `true` | 同上 | PASS |
| 序号连续 1..51 | 是 | 本人遍历 | PASS |
| `end <= start` 的条数 | **0** | 本人遍历 | PASS |
| 首条起点 / 末条终点 | 25.94 / **614.90** | 本人解析 | PASS（末条正好收在节目总秒） |
| 超出 `[0, 614.9]` 的条数 | **0** | 本人遍历 | PASS |
| 条时长 min / max | 0.880 / 6.480 s | 本人实算 | PASS（落在 stats 声明的 0.8 / 7.0 界内） |

### 5.2 时钟对齐版断裂检查

| 检查项 | 我的实测值 | 依据 | 判定 |
|---|---|---|---|
| **`cross_cut_spans`** | **0** | `TASK\reports\srt_crosscheck_v1.json` → `cross_cut_spans` | **PASS** |
| 本人**独立重算**的跨切点数 | **0**（用 `program_map_v1.json` 的 `cuts[]` 12 个节目区间，逐条判 cue 是否严格跨越边界） | 本人实算 | **PASS（与声明吻合）** |
| `overlaps` | 0（本人独立重算同为 0） | 同上 | PASS |
| `timing_problems` / `gap_problems` | 0 / 0 | 同上 | PASS |
| `problems` | `[]` | 同上 | PASS |
| `pass` | `true` | 同上 | PASS |
| `cut_count` | 12 | 同上 | 与 `program_map_v1.json` 头部 `cut_count: 12` 一致 |
| 正好抵住切点（偏移恰为 0）的 cue | 5 | 本人实算 | PASS（`stats.split_at_cut = 6` 记录了 6 处在切点处切分；抵住 11 个内部切点的有 5 条，符合"切分即对齐"的设计） |
| `stats.cross_cut_spans` | 0（与 crosscheck 文件独立一致） | `TASK\captions\864-review-v1.stats.json` | PASS |

### 5.3 时钟错配说明（本项关键，任务书要求写清楚）

**问题本身（已由我复核确认）**：`qa_gate.py` 的 `gate_subtitles`（`C:\Project\永劫无间\skills\naraka-highlight-studio\scripts\qa_gate.py` 第 239–265 行），在第 261–264 行做跨切检查时：

```python
for start, end in (episode_range(ep) for ep in episodes):
    if start < entry["start"] < end < entry["end"] or entry["start"] < start < entry["end"] < end:
```

`entry["start"] / entry["end"]` 来自 SRT，是**节目秒**；`episode_range(ep)` 取 `episode["source_start"] / ["source_end"]`（同脚本第 65–68 行），在源坐标时间线里是**源秒**。两者放在同一量纲里比 —— **时钟错配，必然误报**。这就是 `qa_v1.json`（源坐标、不传 `--srt`）里 `subtitle_span` / `subtitle_stats` 双 WARN 的成因（第 410–411 行 `no srt` 分支）。

**为什么跑两遍是对的**：

| 文件 | 时间线坐标 | 是否传 `--srt` | `fail` / `warn` / `pass` |
|---|---|---|---|
| `TASK\reports\qa_v1.json` | 源秒 | 否 | 0 / 4 / `true` |
| `TASK\reports\qa_v1_programbounds.json` | 节目秒 | 是 | 0 / 2 / `true` |

两遍之间**只有 2 项结果变化**，其余全部不变（本人逐项比对）：

| check 名 | `qa_v1.json` | `qa_v1_programbounds.json` | 是否变化 |
|---|---|---|---|
| `subtitle_span` | WARN | **PASS** | **变** |
| `subtitle_stats` | WARN | **PASS** | **变** |
| `timeline_mutex` / `source_range` / `in_segment_holes` / `program_sum` / `preview_duration` / `av_sync` / `frame_rate` / `no_subtitle_stream` / `proxy_map` / `workspace_hygiene` | 全部 PASS | 全部 PASS | **不变（10/10 逐项相同）** |
| `media_filters` | WARN | WARN | 不变 |
| `no_burned_variant` | WARN | WARN | 不变 |

> 即：把时钟对齐后，字幕相关的 2 个 WARN 转为 PASS，而**所有几何/媒体控制项一字未动**。这从行为上证明 `programbounds` 视图没有污染任何几何判据。

### 5.4 **关键**：独立核实 `programbounds` 确实只是坐标换算、没改动任何边界数值

被核文件：`TASK\timeline\combat_episodes_v1_programbounds.json`（12 行 / 3,699 字节），头部自述 `coordinate_space: "PROGRAM SECONDS (verification view only, never rendered)"`。

**（a）逐场比对：`combat_episodes_v1.json` 的 (source_start, source_end) ↔ `program_map_v1.json` 的 `cuts[]`**

本人先用 `episode_geometry.episode_segments()` 从真源独立展开出 12 个切分段，再与 `cuts[]` 的 12 条逐条对撞。**两处都通过的判据**：源边界一致 + 节目边界为累计前缀和 + 各时长字段自洽。

| # | episode_id | part | 真源源边界（本人从 `combat_episodes_v1.json` 展开） | `cuts[].source_start/end` | `cuts[].program_start/end` | `source_duration` | `program_duration` | 判定 |
|---|---|---|---|---|---|---|---|---|
| 1 | `combat_001` | 0 | [181.00, 266.00] | 181.00 / 266.00 | 0.00 / 85.00 | 85.00 | 85.00 | OK |
| 2 | `combat_002` | 0 | [305.00, 345.00] | 305.00 / 345.00 | 85.00 / 125.00 | 40.00 | 40.00 | OK |
| 3 | `combat_003` | 0 | [357.00, 404.00] | 357.00 / 404.00 | 125.00 / 172.00 | 47.00 | 47.00 | OK |
| 4 | `combat_004` | 0 | [412.00, 442.00] | 412.00 / 442.00 | 172.00 / 202.00 | 30.00 | 30.00 | OK |
| 5 | `combat_005` | 0 | [495.00, 517.50] | 495.00 / 517.50 | 202.00 / 224.50 | 22.50 | 22.50 | OK |
| 6 | `combat_006` | 0 | [517.50, 556.50] | 517.50 / 556.50 | 224.50 / 263.50 | 39.00 | 39.00 | OK |
| 7 | `combat_007` | 0 | [597.00, 685.00] | 597.00 / 685.00 | 263.50 / 351.50 | 88.00 | 88.00 | OK |
| 8 | `combat_008` | 0 | [716.00, 800.00] | 716.00 / 800.00 | 351.50 / 435.50 | 84.00 | 84.00 | OK |
| 9 | `combat_009` | 0 | [911.00, 943.00] | 911.00 / 943.00 | 435.50 / 467.50 | 32.00 | 32.00 | OK |
| 10 | `combat_010` | 0 | [949.00, 1037.00] | 949.00 / 1037.00 | 467.50 / 555.50 | 88.00 | 88.00 | OK |
| 11 | `combat_011` | **0** | [1053.00, **1100.80**] | 1053.00 / 1100.80 | 555.50 / 603.30 | 47.80 | 47.80 | OK |
| 12 | `combat_011` | **1** | [**1115.90**, 1127.50] | 1115.90 / 1127.50 | 603.30 / 614.90 | 11.60 | 11.60 | OK |

| 检查项 | 我的实测值 | 判定 |
|---|---|---|
| 12 条源边界与真源**逐位相等** | **是（12/12）** | **PASS** |
| 12 条节目边界为「从 0.00 起累计」的精确前缀和 | **是**，节目轴跨度 `[0.00, 614.90]`，相邻 `program_start == prev program_end` 零差 | **PASS** |
| **Σ 各 part 长度 = 614.9** | **614.900000**，与 `program_map_v1.json` 头部 `program_seconds_total` 差 **0.000000000** | **PASS** |
| 同一 episode 的各 part 首尾相接 | `combat_011` 是唯一的多 part 场：节目侧 part0 末 603.30 == part1 首 603.30（**首尾相接，零缝零重叠**）；源侧 part0 末 1100.80 与 part1 首 1115.90 之间恰为 15.10 s 的已声明洞，part 长度 47.80 + 11.60 = **59.40** == 74.50 − 15.10 | **PASS** |
| 其余 10 场均为单 part | 10/10，无洞 | PASS |
| `program_map` 头部计数自洽 | `episode_count: 11` / `cut_count: 12` / `rendered_segments: 12` / `reused_segments: 0` | PASS |

**（b）`programbounds` 每条的 `from_source` 与源区间一致**

| # | `programbounds` id | pb `source_start/end`（节目秒） | pb `from_source`（源秒） | 对应真源切分段 | 判定 |
|---|---|---|---|---|---|
| 1 | `combat_001#0` | 0.00 / 85.00 | **[181.00, 266.00]** | [181.00, 266.00] | 一致 |
| 2 | `combat_002#0` | 85.00 / 125.00 | **[305.00, 345.00]** | [305.00, 345.00] | 一致 |
| 3 | `combat_003#0` | 125.00 / 172.00 | **[357.00, 404.00]** | [357.00, 404.00] | 一致 |
| 4 | `combat_004#0` | 172.00 / 202.00 | **[412.00, 442.00]** | [412.00, 442.00] | 一致 |
| 5 | `combat_005#0` | 202.00 / 224.50 | **[495.00, 517.50]** | [495.00, 517.50] | 一致 |
| 6 | `combat_006#0` | 224.50 / 263.50 | **[517.50, 556.50]** | [517.50, 556.50] | 一致 |
| 7 | `combat_007#0` | 263.50 / 351.50 | **[597.00, 685.00]** | [597.00, 685.00] | 一致 |
| 8 | `combat_008#0` | 351.50 / 435.50 | **[716.00, 800.00]** | [716.00, 800.00] | 一致 |
| 9 | `combat_009#0` | 435.50 / 467.50 | **[911.00, 943.00]** | [911.00, 943.00] | 一致 |
| 10 | `combat_010#0` | 467.50 / 555.50 | **[949.00, 1037.00]** | [949.00, 1037.00] | 一致 |
| 11 | `combat_011#0` | 555.50 / 603.30 | **[1053.00, 1100.80]** | [1053.00, 1100.80] | 一致 |
| 12 | `combat_011#1` | 603.30 / 614.90 | **[1115.90, 1127.50]** | [1115.90, 1127.50] | 一致 |

| 检查项 | 我的实测值 | 判定 |
|---|---|---|
| 12 行的 `id` 全部等于 `<episode_id>#<part>` | **是（12/12）** | PASS |
| 12 行的 `from_source` 与真源切分段**逐位相等** | **是（12/12，0 条不符）** | **PASS** |
| `from_source` 集合 == 真源 12 个切分段集合（排序后逐位相等） | **是** | **PASS** |
| 12 行的 `source_start/source_end` == `cuts[].program_start/program_end` | **是（12/12）** | **PASS** |
| 12 行行长 == 对应真源切分段长 | **是（12/12）** | PASS |
| 节目视图单调且无重叠 | **是**（`next.start − prev.end >= 0`，实际全为 0.00） | PASS |
| 节目视图覆盖 `[0.00, 614.90]`，行长之和 = 614.900000 == 头部 `program_seconds_total` | **是（差 0.000000）** | **PASS** |
| `excluded_inside` 在 12 行中全部清空为 `[]` | **是（12/12）** | PASS（洞已在展开时应用，无需二次声明） |
| `complete` / `needs_review` 与真源逐条相同 | **是（12/12）** | PASS |
| `deleted_intervals` 在 programbounds 中为 `[]`（真源 16 条） | **是** | PASS（**正确**：删除段是"节目时间的缺席"，在节目坐标里没有对应物；把它搬过来才是造假） |
| programbounds 行只含几何/标注字段（`id, source_start, source_end, engage_start, outcome_time, complete, needs_review, excluded_inside, from_source`），**不含** `notes` / `evidence` / `confidence` / `event_types` / `impact_points` / `boundary_reason` / `source` | **是** | PASS（纯几何验证视图，未夹带任何可影响判定的其他数据） |

> **`from_source` 一致性判定：PASS。** `programbounds` 的每一条 `from_source` 都能在真源 `combat_episodes_v1.json` 里找到**数值完全相同**的源区间；它的 `source_start/source_end` 就是 `program_map_v1.json` 的 `program_start/program_end`。**没有任何一个边界数值被改动、插值、凑整或重排。**

**（c）一处必须点名的差异（不构成 FAIL）**

| 检查项 | 我的实测值 | 判定 |
|---|---|---|
| `engage_start` / `outcome_time` 的换算方式 | **12/12 行被「压平」为该行自身边界**，即 `engage_start == source_start` 且 `outcome_time == source_end`（例：`combat_001#0` 的 `engage_start = 0.00`（非 5.00）、`outcome_time = 85.00`（非 72.00）；`combat_011#1` 的 `engage_start = 603.30`（非 666.20）） | 需点名 |
| 这是否属"改动边界数值" | **不是。** 被压平的是**标注字段**，不是几何字段；12 行的 `source_start` / `source_end` / `from_source` 全部逐位等于真源（见 (a)(b)） | **PASS** |
| 对 `qa_gate` 判据的影响 | **零。** 我 grep 过 `qa_gate.py` 全文：它**从不读取** `engage_start` / `outcome_time`（0 处匹配），`gate_timeline_mutex` / `gate_source_range` / `gate_program_sum` / `gate_in_segment_holes` 只用 `episode_range()` 即 `source_start` / `source_end` | **PASS** |
| 对 `validate` 判据的影响 | **零。** `validate_combat_timeline.py` 确实读这两个字段（第 109–110 行），但被校验的文件是 `combat_episodes_v1.json`（`v1_validate.json` 的 `timeline` 字段），它保留了真实源值（`combat_001` engage 186.0 / outcome 253.0 等），且 11/11 满足 `source_start <= engage_start <= outcome_time <= source_end` | **PASS** |
| 行为层佐证 | 两遍 `qa_gate` 的 10 项几何/媒体控制检查结果**完全相同**（§5.3） | **PASS** |

---

## 结论汇总

| 项 | 检查主题 | 判定 | 关键数字 |
|---|---|---|---|
| 1 | validate pass 复核 | **PASS** | `pass: true`；`episode_count: 11`；`checks: 32`；`warnings: 0`（0 需处理）；`pass: false` 的 check **0** 条；本人复现退出码 0，32 条 check 逐键零差异 |
| 2 | 分段求和 | **PASS** | 本人算 `program = 614.9` / `raw = 630.0`；文件头 `program_seconds_total = 614.9`；**差 0.000000**；挖洞 = **15.1 s**（唯一洞 `combat_011` 内 `loading_screen`）；630.0 + 522.233 = 1152.233 闭环 |
| 3 | 单调/无重叠/无缝覆盖 | **PASS** | episode 相邻对 10，重叠 **0**（最小 gap +0.00 于 517.50）；deletion 相邻对 15，重叠 **0**；**27 区间**铺满 `[0, 1152.233]`，0 缝 0 重叠，长度和 1152.233000 差 **0.000000**；计洞后 **29 区间**同样零缝零重叠；(deletion × episode) 176 对重叠 **0** |
| 4 | ffprobe 时长对照 | **PASS** | `format.duration = 614.921333`，节目 614.9，**差 +0.021333 s**（= 1 个 AAC 帧量子 1024/48000）；`video.duration = 614.900000` 差 **0.000000**；\|V−A\| = 0.021333 s；**subtitle 流 = 0**；`avg_frame_rate = r_frame_rate = 60/1` → **CFR**；`nb_frames 36894` = 614.9 × 60 |
| 5 | 字幕条数与断裂 | **PASS** | SRT 实解析 **51** 条 == `stats.count` 51 == `crosscheck.cue_count` 51；`cross_cut_spans = 0`（本人独立重算同为 0）；`programbounds` 12 行 `from_source` 与真源**逐位相等**、源边界与 `cuts[]` **逐位相等**、Σpart = **614.900000** 差 0.000000000 → 确认**纯坐标换算、零边界改动** |

### 需点名事项（均非缺陷，无 FAIL）

1. **15.1 s 的洞写在 `excluded_inside` 而非 `deleted_intervals`**。按 `episode_geometry` 的 schema，这是正确位置（"场内部挖掉" vs "整段不要"）。后果：若只把「已挖洞的切分段 + deletions」当作铺满集合（28 区间），会看到 1 条 15.10 s 的"缺口"；把洞计为第 29 个排除区间后即零缝零重叠。**任何按 28 区间口径审计的人都会误报这一条，需提前说明。**
2. **`programbounds` 的 `engage_start` / `outcome_time` 被压平为行边界**（12/12），非等偏移换算。几何字段零改动，且 `qa_gate.py` 从不读这两个字段（已 grep 验证），对两遍门禁结果零影响。源坐标真源保留真实标注值。
3. **`qa_gate` 残留 2 条 WARN**：`media_filters`（证据在渲染/自审侧，门禁不重解码）与 `no_burned_variant`（`"no master"`，尚未出 4K 成片 —— 这正是禁烧录规则的正确前置状态）。**均不属数字验收范围。**
4. **`combat_005` 与 `combat_006` 在源秒 517.50 共享边界**（岛式合并点）。节目切点 224.50，22.5 s + 39.0 s = 1350 + 2340 帧，**不重复帧、不丢帧**，且 12 段全部为 1/60 s 整数倍。
5. **`in_segment_holes_excavated` 被 validate 标为 informational**（非门禁），我已按其字段 `raw_span: 630.0` / `excavated_seconds: 15.1` 独立重算并完全吻合。

### 纪律留痕

- 只读：`dir`、读文本 JSON、项目 Python 只读算术（`json` / `os` / `re` / `subprocess` 调 ffprobe / `sys.path` 导入 `episode_geometry`）、`stat`。
- 未跑 whisper / scenedetect / auto-editor；未渲染；未安装；未新建环境；未修改任何既有文件。
- **看图 0 张**（远低于 50 张硬红线）。
- 写文件仅 2 个：本报告 + `reports\acceptB_revalidate_v1.json`（第 1 项任务书明确授权）。
- 未采信 `reports\preview_probe_v1.json`、`qa_v1*.json`、`srt_crosscheck_v1.json`、`v1_validate.json` 等他人产物的**结论**；所有数字均从 `combat_episodes_v1.json` / `program_map_v1.json` / `864-review-v1.srt` / `864-review-v1.mp4` **原始产物重算**，仅在表格"依据"列引用他人文件作交叉印证。

**STATUS: PASS**
