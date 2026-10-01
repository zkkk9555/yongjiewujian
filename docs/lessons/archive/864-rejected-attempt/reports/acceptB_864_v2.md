# acceptB — 任务 21 v2 冻结候选 · 时间线数字独立验收

- **角色**：独立验收角色 B（时间线数字验收员）。**未参与 v2 任何执行**：没写过时间线、没渲过预览、没做过扫描或对抗审。
- **验收对象**：`v2` 冻结候选（timeline `combat_episodes_v2.json` + preview `864-review-v2.mp4` + 外挂 SRT）。
- **验收日期**：2026-09-30。
- **纪律遵守**：全程只读（`dir` / 读文本 JSON / 项目 Python 只读算术 / `ffprobe` / `stat`）。**看图 0 张**。未跑 whisper / scenedetect / auto-editor，未渲染，未安装，未建环境，未改任何既有文件。
- **本角色写入的文件仅 2 个**：
  1. `…\reports\acceptB_864_v2.md`（本报告）
  2. `…\reports\acceptB_revalidate_v2.json`（第 1 项被授权的复算输出）
- **所有数字均为本人从原始产物重算**，不采信任何他人报告里的结论（`acceptB/C/D_864_v1.md`、`adjudicate_*`、`merge_decision_v2.md` 等一律未采信、未作为依据）。

## 0. 工具与真源

| 用途 | 绝对路径 | 实测 |
|---|---|---|
| Python | `C:\Project\永劫无间\.video-tools\venv\Scripts\python.exe` | 可用 |
| FFprobe | `C:\Project\永劫无间\.video-tools\LosslessCut\resources\ffprobe.exe` | 可用 |
| 几何模块 | `C:\Project\永劫无间\skills\naraka-highlight-studio\scripts\episode_geometry.py` | 可用（`episode_segments` / `timeline_program_seconds` / `timeline_raw_span_seconds`） |
| 门禁脚本 | `C:\Project\永劫无间\skills\naraka-highlight-studio\scripts\qa_gate.py` | 只读引用（未运行，见第 6 项说明） |
| 校验脚本 | `C:\Project\永劫无间\skills\naraka-highlight-studio\scripts\validate_combat_timeline.py` | 运行一次（获授权，输出到本角色文件） |

**TASK** = `C:\Project\永劫无间\123\21.864永劫无间 2026-09-30 02-57-13`

**源素材（只读，未改动）**：`E:\PR导出\864永劫无间 2026-09-30 02-57-13.mp4`
- `format.duration = 1152.233333`（ffprobe）→ 与校验所用 `1152.233` 一致
- 3840×2160, h264, `r_frame_rate=60/1` = `avg_frame_rate=60/1`, `nb_frames=69134`, 2,984,729,760 bytes, mtime `2026-09-30 09:38:25`

**冻结件时序（无过期产物）**：

| 时序 | 文件 |
|---|---|
| 17:00:53 | `timeline\combat_episodes_v2.json`（真源，110,489 B） |
| 17:10:44 | `reports\v2_validate.json`（6,910 B） |
| 17:18:47 | `timeline\program_map_v2.json`（5,014 B） + `preview\864-review-v2.mp4`（781,042,716 B） |
| 17:20:12 | `captions\864-review-v2.srt` + `.stats.json` + `reports\srt_crosscheck_v2.json` |
| 17:22:36 | `preview\864-review-v2.decode.log`（**0 字节** = 解码零报错） |
| 17:24:02 | `timeline\combat_episodes_v2_programbounds.json` + `reports\qa_v2.json` |
| 17:24:03 | `reports\qa_v2_programbounds.json` |

时间线 → 校验 → 映射+预览 → 字幕+交叉核对 → programbounds+门禁，顺序正确，无任何报告早于其输入。

---

## 1. validate 复核

| 检查项 | 我的实测值 | 依据（文件绝对路径 + 字段） | 判定 |
|---|---|---|---|
| `pass` | `true` | `…\reports\v2_validate.json` → `.pass` | PASS |
| `episode_count` | `11` | 同上 → `.episode_count` | PASS |
| `checks` 条数 | `27` | 同上 → `.checks`，本人 `len()` 复算 = 27 | PASS |
| `checks` 构成 | `episodes_non_empty` 1 + `episode_001…011` 11 + `source_duration_valid` 1 + `program_sum_seconds` 1 + `in_segment_holes_excavated` 1 + `in_segment_holes_valid` 1 + `deleted_interval_1…11` 11 = **27** | 同上 → `.checks[*].name` | PASS |
| `warnings` 逐条分类 | **`warnings = []`，长度 0 —— 零条警告，无可分类项** | 同上 → `.warnings` | PASS |
| `pass=false` 的 check | **无**（27 条全部 `pass=true`） | 同上 → `[c for c in checks if not c['pass']] == []` | PASS |
| 关键数值 `program_sum` | `587.33` | 同上 → `checks[program_sum_seconds].program_sum` | PASS |
| 关键数值 `excavated_seconds` | `44.92`，`raw_span = 632.25`，`hole_count = 6` | 同上 → `checks[in_segment_holes_excavated]` | PASS |
| 关键数值 `in_segment_holes_valid` | `problems = []` | 同上 → `checks[in_segment_holes_valid].problems` | PASS |
| **可复现性（本人重跑）** | 退出码 `0`，stdout `{"pass": true, "episodes": 11}`，输出 `…\reports\acceptB_revalidate_v2.json`（6,910 B） | 本人执行 `validate_combat_timeline.py '…\timeline\combat_episodes_v2.json' --source-duration 1152.233 --output '…\reports\acceptB_revalidate_v2.json'` | PASS |
| **重跑 vs 存档逐字段比对** | **整个 JSON 对象完全相等（`a == b` → `True`）**；27 条 check 名与顺序一致；逐条 diff = **0** | 本人对 `v2_validate.json` 与 `acceptB_revalidate_v2.json` 做对象级相等比较 | PASS |
| `source_duration_valid` | `1152.233` | 同上 → `checks[source_duration_valid]` | PASS |

**结论**：存档 validate 结果**逐字节可复现**，零警告、零失败项。

---

## 2. 分段求和

本人以 `episode_geometry.timeline_program_seconds()` / `timeline_raw_span_seconds()` 独立重算。

| 检查项 | 我的实测值 | 依据 | 判定 |
|---|---|---|---|
| `timeline_program_seconds(v2.combat_episodes)` | **587.33** | 本人 import `episode_geometry` 重算 | — |
| `program_map_v2.json` 头 `program_seconds_total` | **587.33** | `…\timeline\program_map_v2.json` → `.program_seconds_total` | — |
| **两者核对（0.01 s 级）** | **\|587.33 − 587.33\| = 0.000000** | 本人相减 | **PASS** |
| `timeline_raw_span_seconds` = Σ(`source_end − source_start`)（**未扣洞**） | **632.25** | 本人重算 | — |
| 差 = 挖洞秒数总和 | **632.25 − 587.33 = 44.92** | 本人相减 | — |
| 逐洞长度求和（独立） | **5.0 + 1.1 + 1.7 + 10.9 + 11.0 + 15.22 = 44.92** | 本人从 `combat_episodes_v2.json` 逐个 `excluded_inside` 求和 | **PASS** |
| 三处头部一致 | `tl.program_seconds_total` = `pm.program_seconds_total` = `pb.program_seconds_total` = 587.33 | 三份 JSON 头部 | PASS |
| 洞数 | **6**（`combat_001` 1、`combat_006` 1、`combat_007` 1、`combat_008` 2、`combat_011` 1） | 本人统计 | PASS |
| `program_map` 内部自洽 | `cut_count` 16 = `len(cuts)` 16 = `rendered_segments` 16 = `len(timeline_cut_segments())` 16 | `program_map_v2.json` + 本人重算 | PASS |
| 16 条 cut 与展开切片逐条比对 | 16/16 `(source_start, source_end)` 完全相等；16/16 `program_start` 等于累计值；16/16 `program_end` 等于累计+时长；16/16 `source_duration == program_duration`；`sum(program_duration) = 587.33`；`last program_end = 587.33` | 本人逐条比对 | PASS |
| `rendered_frames` 求和 | `35240`，与 `ffprobe nb_frames = 35240` **完全一致** | `program_map_v2.json` + ffprobe | PASS |

### 逐洞清单（源秒）

| # | 所属场 | 洞区间（源秒） | 长度 | category | 落在本场 `[source_start, source_end)` 内 |
|---|---|---|---|---|---|
| 1 | `combat_001` | `[229.0, 234.0)` | **5.00** | `ui_panel_loot` | 是（181.0–266.5） |
| 2 | `combat_006` | `[554.3, 555.4)` | **1.10** | `fullscreen_map` | 是（517.5–562.0） |
| 3 | `combat_007` | `[659.5, 661.2)` | **1.70** | `ui_panel_loot` | 是（598.0–685.0） |
| 4 | `combat_008` | `[781.0, 791.9)` | **10.90** | `shop_ui` | 是（726.0–810.0） |
| 5 | `combat_008` | `[799.0, 810.0)` | **11.00** | `vendor_and_loot` | 是（726.0–810.0） |
| 6 | `combat_011` | `[1100.75, 1115.97)` | **15.22** | `loading_screen` | 是（1053.0–1127.45） |
| | | **合计** | **44.92** | | 6/6 均在洞内，无洞越界、无洞吞掉整场 |

### 逐场：`(source_end − source_start) − Σholes` 与节目贡献

| 场 | source_start | source_end | 原始跨度 | 洞数 | Σholes | **净值 = 跨度 − Σholes** | 展开切片（源秒） | 节目贡献 | 节目区间 |
|---|---|---|---|---|---|---|---|---|---|
| `combat_001` | 181.0 | 266.5 | 85.50 | 1 | 5.00 | **80.50** | `[181.0,229.0)`,`[234.0,266.5)` | 80.50 | 0.00–80.50 |
| `combat_002` | 305.0 | 345.0 | 40.00 | 0 | 0 | **40.00** | `[305.0,345.0)` | 40.00 | 80.50–120.50 |
| `combat_003` | 357.0 | 404.0 | 47.00 | 0 | 0 | **47.00** | `[357.0,404.0)` | 47.00 | 120.50–167.50 |
| `combat_004` | 416.7 | 444.0 | 27.30 | 0 | 0 | **27.30** | `[416.7,444.0)` | 27.30 | 167.50–194.80 |
| `combat_005` | 495.0 | 517.5 | 22.50 | 0 | 0 | **22.50** | `[495.0,517.5)` | 22.50 | 194.80–217.30 |
| `combat_006` | 517.5 | 562.0 | 44.50 | 1 | 1.10 | **43.40** | `[517.5,554.3)`,`[555.4,562.0)` | 43.40 | 217.30–260.70 |
| `combat_007` | 598.0 | 685.0 | 87.00 | 1 | 1.70 | **85.30** | `[598.0,659.5)`,`[661.2,685.0)` | 85.30 | 260.70–346.00 |
| `combat_008` | 726.0 | 810.0 | 84.00 | 2 | 21.90 | **62.10** | `[726.0,781.0)`,`[791.9,799.0)` | 62.10 | 346.00–408.10 |
| `combat_009` | 911.0 | 943.0 | 32.00 | 0 | 0 | **32.00** | `[911.0,943.0)` | 32.00 | 408.10–440.10 |
| `combat_010` | 949.0 | 1037.0 | 88.00 | 0 | 0 | **88.00** | `[949.0,1037.0)` | 88.00 | 440.10–528.10 |
| `combat_011` | 1053.0 | 1127.45 | 74.45 | 1 | 15.22 | **59.23** | `[1053.0,1100.75)`,`[1115.97,1127.45)` | 59.23 | 528.10–587.33 |
| **合计** | | | **632.25** | **6** | **44.92** | **587.33** | 16 片 | **587.33** | 0.00–587.33 |

净值列逐场相加 = 587.33，与节目贡献列逐场相加 = 587.33，两者一致。

**结论：PASS。** 节目秒 **587.33** = `program_map_v2.json` 头 **587.33**，差 **0.000**（远优于 0.01 s）。原始跨度 **632.25** 与节目秒的差 **44.92** 已被 6 个洞逐条完整解释（5.00+1.10+1.70+10.90+11.00+15.22 = 44.92），无未解释余量。

---

## 3. 单调、无重叠、无缝覆盖

### 3a. episode 排序与相邻检查

文件内 `combat_episodes` 本身已按 `source_start` 升序（本人排序后 id 序列不变）。

| 相邻对 | prev | next | `next.source_start − prev.source_end` | 判定 |
|---|---|---|---|---|
| 1 | `combat_001` [181.0, 266.5) | `combat_002` [305.0, 345.0) | +38.5 | OK |
| 2 | `combat_002` [345.0 尾) | `combat_003` [357.0, 404.0) | +12.0 | OK |
| 3 | `combat_003` | `combat_004` [416.7, 444.0) | +12.7 | OK |
| 4 | `combat_004` | `combat_005` [495.0, 517.5) | +51.0 | OK |
| 5 | `combat_005` [495.0, 517.5) | `combat_006` [517.5, 562.0) | **0.0** | **TOUCH — 共享边界 517.5，判定为有意首尾相接，不是重叠** |
| 6 | `combat_006` | `combat_007` [598.0, 685.0) | +36.0 | OK |
| 7 | `combat_007` | `combat_008` [726.0, 810.0) | +41.0 | OK |
| 8 | `combat_008` | `combat_009` [911.0, 943.0) | +101.0 | OK |
| 9 | `combat_009` | `combat_010` [949.0, 1037.0) | +6.0 | OK |
| 10 | `combat_010` | `combat_011` [1053.0, 1127.45) | +16.0 | OK |

- **重叠对数 = 0**。全部 `next.source_start >= prev.source_end` 成立（等号仅 `combat_005`/`combat_006` 一处，为有意共享边界）。
- 半开区间语义下 `[495.0,517.5)` 与 `[517.5,562.0)` 交集为空，**零帧重叠**。

### 3b. 顶层精确铺满 `[0, 1152.233]`

> 说明（易错点已处理）：`excluded_inside` 的洞是**源时间轴上的洞**，属于 episode 内部，**不参与顶层铺满**；顶层只用 episode 的 `[source_start, source_end)`。本人已独立确认 6 个洞全部严格落在其所属 episode 内部（见第 2 项洞表），且它们不进入顶层区间集合。

**区间总数 = 22**（11 个 episode 顶层区间 + 11 条 `deleted_intervals`）。

| # | 区间（源秒） | 长度 | 类型 / category |
|---|---|---|---|
| 1 | `[0.0, 181.0)` | 181.000 | DEL `birth_ability_ui_travel` |
| 2 | `[181.0, 266.5)` | 85.500 | EP `combat_001` |
| 3 | `[266.5, 305.0)` | 38.500 | DEL `travel_loot_idle` |
| 4 | `[305.0, 345.0)` | 40.000 | EP `combat_002` |
| 5 | `[345.0, 357.0)` | 12.000 | DEL `loot_heal_travel` |
| 6 | `[357.0, 404.0)` | 47.000 | EP `combat_003` |
| 7 | `[404.0, 416.7)` | 12.700 | DEL `ui_panel_selection` |
| 8 | `[416.7, 444.0)` | 27.300 | EP `combat_004` |
| 9 | `[444.0, 495.0)` | 51.000 | DEL `travel_loot` |
| 10 | `[495.0, 517.5)` | 22.500 | EP `combat_005` |
| 11 | `[517.5, 562.0)` | 44.500 | EP `combat_006` |
| 12 | `[562.0, 598.0)` | 36.000 | DEL `loot_shop_ui_travel` |
| 13 | `[598.0, 685.0)` | 87.000 | EP `combat_007` |
| 14 | `[685.0, 726.0)` | 41.000 | DEL `traversal_loot_environment` |
| 15 | `[726.0, 810.0)` | 84.000 | EP `combat_008` |
| 16 | `[810.0, 911.0)` | 101.000 | DEL `trade_loot_navigation` |
| 17 | `[911.0, 943.0)` | 32.000 | EP `combat_009` |
| 18 | `[943.0, 949.0)` | 6.000 | DEL `traversal` |
| 19 | `[949.0, 1037.0)` | 88.000 | EP `combat_010` |
| 20 | `[1037.0, 1053.0)` | 16.000 | DEL `traversal` |
| 21 | `[1053.0, 1127.45)` | 74.450 | EP `combat_011` |
| 22 | `[1127.45, 1152.233)` | 24.783 | DEL `lobby_idle` |

| 检查项 | 我的实测值 | 判定 |
|---|---|---|
| 首起点 | **0.0**（= 0，差 0） | PASS |
| 末终点 | **1152.233**（与 ffprobe 源 `1152.233333` 截尾一致，差 0.0） | PASS |
| 21 对相邻间隔 | **全部 0.0**；**最大间隔 = 0.0** ≤ 0.01 | PASS |
| 相邻重叠对数 | **0** | PASS |
| 区间长度求和 | **1152.233**（与源时长一致） | PASS |
| 合并后连通段数 | **1** 段 = `[0.0, 1152.233]` | PASS |
| 覆盖长度 | 1152.233 = 源全长 | PASS |
| **零缝零重叠判定** | **精确铺满 `[0, 1152.233]`，零缝、零重叠** | **PASS** |

### 3c. (deletion, episode) 配对不重叠

本人对 11 × 11 = 121 个 `(deleted_interval, episode)` 组合做区间相交测试：

- **相交对数 = 0**。
- 与 `v2_validate.json` 独立吻合：该文件 11 条 `deleted_interval_*` check 的 `overlaps_selected` 字段**全部为 `false`**（本人读出，11/11 false）。

| 检查项 | 我的实测值 | 依据 | 判定 |
|---|---|---|---|
| (deletion, episode) 不重叠 | 121 组合中相交 **0** 对 | `…\timeline\combat_episodes_v2.json` → `.deleted_intervals` / `.combat_episodes` | PASS |
| 洞不越界 | 6/6 洞严格在所属 episode 内；0 洞吞掉整场 | 同上 → `.combat_episodes[*].excluded_inside` | PASS |
| 洞长为正 | 6/6 洞 `end > start` | 同上 | PASS |

**结论：PASS。** 单调、不重叠、22 区间精确铺满 `[0, 1152.233]`，零缝零重叠。`combat_005`/`combat_006` 共享 517.5 为有意首尾相接，半开区间下零帧重叠。

---

## 4. ffprobe 对照

命令：`ffprobe -v error -print_format json -show_format -show_streams '…\preview\864-review-v2.mp4'`

| 检查项 | 我的实测值 | 依据（字段） | 判定 |
|---|---|---|---|
| `format.duration` | **587.354333** | ffprobe `…\preview\864-review-v2.mp4` → `format.duration` | — |
| 节目总秒 | **587.33** | `…\timeline\program_map_v2.json` → `.program_seconds_total` | — |
| **差值** | **+0.024333 s**（≤ 0.3 s，属舍入/量化） | 本人相减 | **PASS** |
| video `duration` | **587.333333** | `streams[0].duration`（codec `h264`, `1280×720`, `yuv420p`） | — |
| audio `duration` | **587.348667** | `streams[1].duration`（codec `aac`, LC, 48000 Hz, 2ch） | — |
| **video 与 audio duration 差** | **0.015334 s**（\|差\| ≤ 0.2 s） | 本人相减 | **PASS** |
| **`codec_type == "subtitle"` 的流数** | **0** | `format.nb_streams = 2`，`streams[0].codec_type=video`，`streams[1].codec_type=audio` | **PASS** |
| `r_frame_rate` | `60/1` | `streams[0].r_frame_rate` | — |
| `avg_frame_rate` | `60/1` | `streams[0].avg_frame_rate` | — |
| **CFR 判定** | **`r_frame_rate == avg_frame_rate`（60/1 == 60/1）→ CFR** | 本人比对 | **PASS** |
| `nb_frames` | **35240** | `streams[0].nb_frames` | — |
| 节目秒 × 60 | `587.33 × 60 = 35239.8` | 本人计算 | — |
| **差** | **+0.2 帧**（< 1 帧量化；`35239.8 → 35240`） | 本人相减 | **PASS** |
| 帧数交叉验证 | `587.333333 × 60 = 35239.99998 ≈ 35240`；且 `sum(program_map.rendered_frames) = 35240` **与 `nb_frames` 完全一致** | ffprobe + `program_map_v2.json` | PASS |
| `streams[0].time_base` | `1/60000`；`start_pts 1260` → `start_time 0.021000` | ffprobe | — |
| `format.duration` 构成 | `0.021 + 587.333333 = 587.354333`（= video 末点） | 本人计算 | PASS |
| 视频起始偏移是否为 v2 回归 | **否**：`v1` 预览 `start_time = 0.021029`（本人 ffprobe `…\preview\864-review-v1.mp4`），同一 21 ms 常数，属**管线级既有常量**，非 v2 引入 | ffprobe v1 对照 | PASS |
| 解码日志 | `…\preview\864-review-v2.decode.log` = **0 字节**（解码零报错） | stat | PASS |

**结论：PASS。** 预览实测 587.354333 s vs 节目 587.33 s，差 **+0.024 s**（远在 ±0.3 内）；音视频差 0.0153 s；**字幕流 0**（符合禁烧录禁内嵌铁律）；CFR 成立；帧数差 0.2 帧属量化且与 `program_map` 帧数总和精确吻合。

---

## 5. 字幕条数与断裂

### 5a. SRT 实际条数与 stats 对账

| 检查项 | 我的实测值 | 依据 | 判定 |
|---|---|---|---|
| SRT 实际条数（本人独立解析） | **42** | 本人按空行切块解析 `…\captions\864-review-v2.srt` | — |
| 序号连续性 | 索引 **1…42 严格 +1 递增**，无跳号无重号 | 同上 | PASS |
| `stats.count` | **42** | `…\captions\864-review-v2.stats.json` → `.count` | — |
| `stats.total` | **42** | 同上 → `.total` | — |
| **对账** | **42 = 42 = 42 → 闭合** | 本人比对 | **PASS** |

### 5b. `accounting` 字段闭合性（本人独立加法）

**恒等式一**（`accounting` 字符串自述）：`inside_retained = kept + dropped_empty + dropped_low_confidence + dropped_hallucination_loop + dropped_filler_or_short + dropped_cps_or_too_short`

| 分量 | 值 | 来源字段 |
|---|---|---|
| kept | 42 | `.count` |
| dropped_empty | 0 | `.dropped_empty` |
| dropped_low_confidence | 12 | `.dropped_low_confidence` |
| dropped_hallucination_loop | 10 | `.dropped_hallucination_loop` |
| dropped_filler_or_short | 11 | `.dropped_filler_or_short` |
| dropped_cps_or_too_short | 0 | `.dropped_cps_or_too_short` |
| **本人实际和** | **75** | 本人相加 |
| **声称值** | **75**（`accounting` 字符串内 `inside_retained=75`） | `.accounting` |
| 顶层 `source_segments_inside_retained_windows` | **75** | `.source_segments_inside_retained_windows` |
| **闭合** | **75 == 75 == 75 → 差 0** | **PASS** |

**恒等式二**：`source_segments_total = inside_retained + straddling_a_cut + outside_retained_windows`

| 分量 | 值 | 来源字段 |
|---|---|---|
| inside_retained | 75 | `.source_segments_inside_retained_windows` |
| straddling_a_cut | 20 | `.split_at_cut`（= 20，`accounting` 字符串亦作 `straddling_a_cut=20`） |
| outside_retained_windows | 85 | `.outside_retained_windows` |
| **本人实际和** | **180** | 本人相加 |
| **声称值** | **180** | `.accounting` 尾部 `source_segments_total=180` 与顶层 `.source_segments = 180` |
| **闭合** | **180 == 180 == 180 → 差 0** | **PASS** |

**两条恒等式均严格闭合，无未解释余量。**

### 5c. `srt_crosscheck_v2.json` 复核

| 检查项 | 报告值 | **我的独立重算** | 判定 |
|---|---|---|---|
| `cue_count` | 42 | 42 | PASS |
| `cut_count` | 16 | 16（`program_map_v2.cuts`） | PASS |
| `cross_cut_spans` | **0** | **0** | PASS |
| `overlaps` | **0** | **0** | PASS |
| `timing_problems` | **0** | **0** | PASS |
| `gap_problems` | **0** | **0** | PASS |
| **`problems` 数组（本人独立数）** | `[]` | **长度 0，空数组** | **PASS** |
| `pass` | `true` | 我的六项独立复算全部一致 | PASS |
| `stats_declared_count` / `stats_match` | 42 / `true` | 42，且我的 SRT 实数 42 | PASS |

**`cross_cut_spans` 的正确定义与我的独立实现**（这一点极易算错，记录在案）：
> 交叉切点 = **某个节目切点严格落在某条字幕的 `[start, end)` 内部**。切点集合 = `program_map_v2.cuts` 的 15 个内部节目边界
> `[48.0, 80.5, 120.5, 167.5, 194.8, 217.3, 254.1, 260.7, 322.2, 346.0, 401.0, 408.1, 440.1, 528.1, 575.85]`。
> 我用此定义重算得 **0**。
> **反面提醒**：若误把"字幕与某切片窗口有重叠"当作交叉（切窗口本就铺满节目轴，42 条必然全部命中），会得到荒谬的 42 —— 本人先踩此坑后改正，正确值为 0。

**更强的独立验证**：本人另检查 **42/42 条字幕各自完整落在 16 个切片的某一个窗口之内**（`cue.start >= cut.program_start` 且 `cue.end <= cut.program_end`），不完整落入唯一窗口的 = **0**。这从另一侧证明零交叉断裂。

### 5d. SRT 对 `qa_gate` 字幕阈值的独立复核

`qa_gate.py` 常量（本人读出）：`MIN_SUBTITLE_GAP_S=0.08`、`MIN_SUBTITLE_DURATION_S=0.8`、`MAX_SUBTITLE_DURATION_S=7.0`、`MAX_CPS_ZH=12`。

| 检查项 | 我的实测值 | 阈值 | 判定 |
|---|---|---|---|
| 条目数（`qa_gate.parse_srt`） | 42 | — | — |
| 字幕时长 min / max | **0.88 / 6.48 s** | 0.8–7.0 s | PASS |
| 最小相邻间隔 | **0.12 s** | ≥ 0.08 s | PASS |
| 重叠条数 | **0** | 0 | PASS |
| 最大中文语速 | **9.091 cps** | ≤ 12 cps | PASS |
| 首 / 末条 | `(25.94, 28.10)` / `(583.10, 584.67)`，跨度 558.73 s | 均在 `[0, 587.33]` 内 | PASS |

> 注：`stats.thresholds.min_gap_seconds = 0.12` 与 `qa_gate.MIN_SUBTITLE_GAP_S = 0.08` 不同源、不同值，但 SRT 实际最小间隔 0.12 s 同时满足两者（更严的 0.12 已被满足），不构成问题。

### 5e. `source_transcript.json` 对账

| 检查项 | 我的实测值 | 依据 | 判定 |
|---|---|---|---|
| `source_transcript.json` 的 `segments` 数（本人独立数） | **180** | `…\captions\source_transcript.json` → `.segments`，`len()` = 180 | — |
| `stats.source_segments` | **180** | `…\captions\864-review-v2.stats.json` → `.source_segments` | — |
| **对账** | **180 == 180** | 本人比对 | **PASS** |
| `cross_cut_spans`（stats 侧） | 0 | `.cross_cut_spans` | PASS |

**结论：PASS。** 42 条字幕三方对账一致；`accounting` 两条恒等式分别以 75 和 180 **精确闭合（差 0）**；`problems` 数组经本人独立确认为**空**；零交叉、零重叠、零时序问题、零过近间隔；源转写 180 段与 stats 声明相符。

---

## 6. programbounds 视图的纯度（本项关键）

背景复核：本人读 `qa_gate.py::gate_subtitles`（第 239–265 行），确认第 261–262 行确实以
`for start, end in (episode_range(ep) for ep in episodes)` 把**节目秒**的字幕条目与**源秒**的 episode 区间比对 —— **属时钟错配**。

### 6a. `from_source` 与 `episode_segments()` 展开逐条比对

本人用 `episode_geometry.episode_segments()` 展开 11 个 episode 得 16 个切片，再与 `programbounds` 的 16 行逐条比对：

| # | programbounds id | `from_source`（源秒） | `episode_segments()`（源秒） | 源坐标相等 | id 相等 | 节目坐标 == `program_map.cuts` | `excluded_inside` 为空 |
|---|---|---|---|---|---|---|---|
| 1 | `combat_001#0` | [181.0, 229.0] | [181.0, 229.0] | ✅ | ✅ | ✅ | ✅ |
| 2 | `combat_001#1` | [234.0, 266.5] | [234.0, 266.5] | ✅ | ✅ | ✅ | ✅ |
| 3 | `combat_002#0` | [305.0, 345.0] | [305.0, 345.0] | ✅ | ✅ | ✅ | ✅ |
| 4 | `combat_003#0` | [357.0, 404.0] | [357.0, 404.0] | ✅ | ✅ | ✅ |
| 5 | `combat_004#0` | [416.7, 444.0] | [416.7, 444.0] | ✅ | ✅ | ✅ | ✅ |
| 6 | `combat_005#0` | [495.0, 517.5] | [495.0, 517.5] | ✅ | ✅ | ✅ | ✅ |
| 7 | `combat_006#0` | [517.5, 554.3] | [517.5, 554.3] | ✅ | ✅ | ✅ | ✅ |
| 8 | `combat_006#1` | [555.4, 562.0] | [555.4, 562.0] | ✅ | ✅ | ✅ | ✅ |
| 9 | `combat_007#0` | [598.0, 659.5] | [598.0, 659.5] | ✅ | ✅ | ✅ | ✅ |
| 10 | `combat_007#1` | [661.2, 685.0] | [661.2, 685.0] | ✅ | ✅ | ✅ | ✅ |
| 11 | `combat_008#0` | [726.0, 781.0] | [726.0, 781.0] | ✅ | ✅ | ✅ | ✅ |
| 12 | `combat_008#1` | [791.9, 799.0] | [791.9, 799.0] | ✅ | ✅ | ✅ | ✅ |
| 13 | `combat_009#0` | [911.0, 943.0] | [911.0, 943.0] | ✅ | ✅ | ✅ | ✅ |
| 14 | `combat_010#0` | [949.0, 1037.0] | [949.0, 1037.0] | ✅ | ✅ | ✅ | ✅ |
| 15 | `combat_011#0` | [1053.0, 1100.75] | [1053.0, 1100.75] | ✅ | ✅ | ✅ | ✅ |
| 16 | `combat_011#1` | [1115.97, 1127.45] | [1115.97, 1127.45] | ✅ | ✅ | ✅ | ✅ |

**16/16 完全相等（浮点零容差比较，差 0）。视图未改动任何源秒边界。**

### 6b. programbounds 节目秒 vs `program_map_v2.cuts` 节目秒

| 检查项 | 我的实测值 | 判定 |
|---|---|---|
| 16 行 `(source_start, source_end)`（节目秒）逐条 == `cuts[*].(program_start, program_end)` | **16/16 精确相等，差 0** | **PASS** |
| `id` 命名 == `<episode_id>#<part>` 且与 cuts 对齐 | **16/16 一致** | PASS |

### 6c. Σpart = 587.33，差 0

| 检查项 | 我的实测值 | 依据 | 判定 |
|---|---|---|---|
| `Σ(pb.source_end − pb.source_start)` | **587.33** | 本人对 16 行求和 | — |
| 声称/目标值 | **587.33** | `…\timeline\program_map_v2.json` → `.program_seconds_total`；`…\reports\qa_v2_programbounds.json` → `program_sum.measured = 587.33` | — |
| **差** | **0.000000** | 本人相减 | **PASS** |
| `pb.program_seconds_total` 头 | 587.33（与上同） | `…\timeline\combat_episodes_v2_programbounds.json` | PASS |
| `qa_gate.gate_program_sum` 独立重跑（programbounds vs pm 头） | `PASS, measured 587.33, "header program_seconds_total 587.33 ±0.01s"` | 本人调用 `qa_gate.gate_program_sum` | PASS |
| programbounds 节目坐标自身铺满 | 首 0.0、末 587.33、**最大间隔 0.0**、重叠 0 | 本人逐对检查 | PASS |

### 6d. `excluded_inside` 一律为空（洞已在展开时消化）

| 检查项 | 我的实测值 | 依据 | 判定 |
|---|---|---|---|
| `pb` 中 `excluded_inside` 非空的行数 | **0 / 16**（16 行全部为 `[]`） | `…\timeline\combat_episodes_v2_programbounds.json` | **PASS** |
| 源时间线洞数 | 6（`v2` 真源 6 个） | `…\timeline\combat_episodes_v2.json` | — |
| 洞是否已在展开时消化 | **是** —— 6 个洞全部被摊成 16 个无洞切片（11 + 5 个额外切片：`_001#1`、`_006#1`、`_007#1`、`_008#1`、`_011#1`），6 个洞长度合计 44.92 已在 `program_map` 与 pb 中扣除 | 本人比对 | PASS |
| `pb.deleted_intervals` | `[]`（空） | 同上 | PASS（验证视图不参与删除段判定） |

### 6e. `qa_gate.py` 从不读 `engage_start` / `outcome_time`（grep 验证）

| 验证手段 | 匹配数 | 结论 |
|---|---|---|
| `Select-String -Pattern 'engage_start\|outcome_time' -AllMatches` on `qa_gate.py` | **0** | 无匹配 |
| 本人读源码全文统计字面量 `"engage_start"` | **0 次** | 无引用 |
| 本人读源码全文统计字面量 `"outcome_time"` | **0 次** | 无引用 |
| `gate_subtitles` 读取 episode 的方式 | 仅 `episode_range(ep)`（返回 `source_start/source_end`） | 确认只用区间端点 |

**推论（关键）**：`gate_subtitles` 与 `gate_source_range` 对 episode 只用 `source_start/source_end`，从不读 `engage_start` / `outcome_time`。因此在 programbounds 视图中把这两字段压平为行边界（`engage_start = source_start`、`outcome_time = source_end`）对**两遍门禁的任何判定都不产生影响**。

**本人实测压平程度**：pb 中 `engage_start != source_start` 或 `outcome_time != source_end` 的行 = **0 / 16**（16 行全部完全压平为行边界）。

**压平的代价与安全性**（诚实记录）：pb 作为"验证视图"确实丢失了每场真实的交战起点与收束点（源秒语义），因此**不可用于**交战点/收束点级别的检查。但这些字段对两遍 `qa_gate` 门禁完全无用（0 引用），且 pb 保留了 `from_source` 字段（16/16 可回溯到源秒切片）并带 `derived_from` / `program_map` 溯源路径，故定位为"仅供 qa_gate 换算验证"是自洽的。**这不是缺陷，是设计取舍。**

### 6f. 我本人复现"时钟错配"与修复（关键独立证据）

本人直接 import `qa_gate`（**只调用其纯函数，不运行 main、不写文件**），用同一份 42 条字幕，分别对两种时钟跑 `gate_subtitles`：

| 时钟 | 输入 | 我的实测返回值 |
|---|---|---|
| **源秒** | `combat_episodes_v2.json` 的 11 个 episode | **`{'name': 'subtitle_span', 'result': 'FAIL', 'measured': '179.72-183.05 crosses cut'}`** |
| **节目秒** | `combat_episodes_v2_programbounds.json` 的 16 行 | **`{'name': 'subtitle_span', 'result': 'PASS', 'measured': '42 cues'}`** |

**本人独立判定该源秒 FAIL 为假阳性，并给出证明**：
- 触发条件是第 262 行 `start < entry["start"] < end < entry["end"]`（或反向），其中源秒边界 **181.0**（`combat_001.source_start`）严格落在字幕 `[179.72, 183.05)` 内部，且 `|179.72−181.0| = 1.28 > 0.2`、`|183.05−266.5| = 83.45 > 0.2`，故触发。
- 但该字幕在**节目秒**中完整位于切片 `vseg005` 节目区间 `[167.5, 194.8)` 内（第 21 条），对应源秒 `combat_004` `[416.7, 444.0)`，反算源秒为 `416.7 + (179.72−167.5) = 428.92` 至 `416.7 + (183.05−167.5) = 432.25`，**完整落在 `combat_004` 内部，距两端 12.2 s / 11.75 s 余量**。
- 即：**节目时间轴上毫无断裂，断裂纯属两个时钟相减产生的幻觉**。这独立证实了 v1 曾误报 `subtitle_span` FAIL 的根因诊断，也证实 programbounds 视图是**正确且必要**的修法。
- 同时，`qa_v2.json`（源秒那遍）`subtitle_span` 为 `WARN / "no srt"`、`subtitle_stats` 为 `WARN / "no stats"` —— 说明那遍门禁**根本没有载入 SRT**（未传 `--srt`），所以它压根没做出这个错误判定；错误只在传了 SRT 的源秒组合下才会出现。这一点让两遍门禁的关系更清楚：**v2 的 `qa_v2.json` 未被 SRT 污染，`qa_v2_programbounds.json` 才是唯一真正验证了字幕的产物**。

### 6g. programbounds 门禁报告的独立复核

| 检查项 | `qa_v2_programbounds.json` 声称 | 我的独立复算 | 判定 |
|---|---|---|---|
| `timeline_mutex` | PASS, "16 episodes ordered" | 16 行按节目秒升序，最大间隔 0.0，重叠 0 | PASS |
| `source_range` | PASS, "16 in range" | 我调用 `gate_source_range(pb, 587.33)` → `PASS, "16 in range"`，**字符串完全一致**；且 pb 最大 end 587.33 ≤ 源 1152.233 | PASS |
| `in_segment_holes` | PASS, "no holes declared" | 16/16 `excluded_inside == []` | PASS |
| `program_sum` | PASS, 587.33 | 我调用 `gate_program_sum` → 587.33 PASS | PASS |
| `preview_duration` | PASS, 587.354 | 我的 ffprobe 587.354333，差 0.000333 | PASS |
| `av_sync` | PASS, 0.015 | 我的 ffprobe 差 0.015334 | PASS |
| `frame_rate` | PASS, "60/1" | 我的 ffprobe `r=avg=60/1` | PASS |
| `subtitle_span` | **PASS, "42 cues"** | 我调用 `gate_subtitles`（节目秒）→ `PASS, "42 cues"`，**字符串完全一致** | PASS |
| `subtitle_stats` | **PASS, 42** | 我的 SRT 实数 42 == stats 42 | PASS |
| `no_subtitle_stream` | PASS, 0 | 我的 ffprobe 字幕流 0 | PASS |
| `fail` | **0** | 0 | PASS |
| `warn` | 2（`media_filters`、`no_burned_variant`） | 2（`no_burned_variant` 因"尚无 4K master"，属冻结候选阶段的预期状态，非缺陷） | PASS |
| `pass` / `status` | `true` / `FROZEN_CANDIDATE` | 0 FAIL | PASS |

**唯一记录在案的证据缺口（非 FAIL）**：`qa_v2_programbounds.json` **不记录所传入的 `--source-duration` 数值**，故其 `source_range` 的 "16 in range" 无法单凭该文件锁定到具体阈值。缓解：本人已独立调用 `gate_source_range(pb, 587.33)` 得到与报告**逐字相同**的 `"16 in range"`，且 pb 最大 end = 587.33，在 587.33 ~ 1152.233 之间任一阈值下均通过。实质判定不受影响。

**结论：PASS。** programbounds 是**纯坐标换算视图**：16/16 `from_source` 与 `episode_segments()` 展开精确相等（差 0），16/16 节目秒与 `program_map_v2.cuts` 精确相等，Σpart = 587.33 差 0，`excluded_inside` 16/16 为空且 6 个洞已在展开时消化；`qa_gate.py` 对 `engage_start`/`outcome_time` 的字面量引用数 = **0 / 0**，故压平为行边界对两遍门禁无影响。本人并复现了源秒门的假 FAIL（`179.72-183.05 crosses cut`）与节目秒门的 PASS，从正反两面证明该视图只换坐标、不改边界。

---

## 汇总

| # | 验收项 | 判定 | 关键数字 |
|---|---|---|---|
| 1 | validate 复核 | **PASS** | `pass=true`；11 场；27 checks；`warnings=[]`（0 条）；`pass=false` 0 条；重跑退出码 0，与存档**对象级完全相等**，逐条 diff 0 |
| 2 | 分段求和 | **PASS** | 节目秒复算 **587.33** == `program_map_v2` 头 **587.33**，差 **0.000**；原始跨度 **632.25**；差 **44.92** = 6 洞之和（5.00+1.10+1.70+10.90+11.00+15.22）；16/16 cut 与展开切片逐条相等 |
| 3 | 单调/无重叠/无缝覆盖 | **PASS** | 重叠对 **0**；`combat_005`/`combat_006` 共享边界 **517.5**（有意，零帧重叠）；**22 区间**（11 ep + 11 del）**精确铺满 [0, 1152.233]**，首 0.0、末 1152.233、21 对间隔全 **0.0**、最大间隔 0.0、合并为 1 段、覆盖 1152.233；(del, ep) 121 组合相交 **0**；6 洞全在洞内 |
| 4 | ffprobe 对照 | **PASS** | `format.duration` **587.354333** vs 节目 587.33，差 **+0.024333 s**（≤0.3）；video **587.333333** / audio **587.348667**，差 **0.015334 s**（≤0.2）；**字幕流 0**（`nb_streams=2`）；`r=avg=60/1` **CFR**；`nb_frames` **35240** vs 587.33×60=35239.8，差 **0.2 帧**，且 == Σ`rendered_frames` 35240；视频 21 ms 起始偏移与 v1 同为管线常量 |
| 5 | 字幕条数与断裂 | **PASS** | SRT 实数 **42** == `stats.count` 42 == `stats.total` 42，序号 1…42 连续；`accounting` 恒等式一 **42+0+12+10+11+0 = 75** == 声称 **75**（差 0）；恒等式二 **75+20+85 = 180** == 声称 **180**（差 0）；`crosscheck` cross_cut/overlaps/timing/gap 全 **0**，`problems` **长度 0**（本人独立确认为空）；本人以"切点严格落入字幕内部"重定义独立重算 `cross_cut_spans = 0`，另证 42/42 字幕完整落入唯一切片窗口；`source_transcript.segments` **180** == `stats.source_segments` **180** |
| 6 | programbounds 纯度 | **PASS** | 16/16 `from_source` == `episode_segments()` 展开（差 0）；16/16 节目秒 == `program_map_v2.cuts`（差 0）；**Σpart = 587.33，差 0.000000**；`excluded_inside` 16/16 空、`deleted_intervals` 空；`qa_gate.py` 中 `engage_start` 引用 **0** 次、`outcome_time` 引用 **0** 次（Select-String 0 匹配 + 全文计数 0/0）；本人复现源秒门 `FAIL '179.72-183.05 crosses cut'`（假阳性，已证源秒应为 428.92–432.25 完整落在 `combat_004` 内）与节目秒门 `PASS '42 cues'` |

### 问题清单

**无 FAIL，无阻塞问题。**

非阻塞观察（3 条，均不影响判定，记录备查）：

1. **帧量化 0.2 帧**：`587.33 s × 60 = 35239.8` 帧不可整除，实际 `nb_frames = 35240`。根因是末条切片 `combat_011#1` 节目时长 **11.48 s × 60 = 688.8 帧**必须取整为 689 帧。此为帧粒度固有量化，**16 条切片中仅此 1 条出现非整数帧**，且已与 `program_map_v2.rendered_frames` 精确对上。判定 PASS。
2. **预览容器 21 ms 视频起始偏移**：`streams[0].start_time = 0.021`（1260 pts @ `1/60000`）。本人对 `864-review-v1.mp4` 做同样 ffprobe 得 `start_time = 0.021029`，**同一常数**，属渲染管线级既有行为，**非 v2 引入的回归**。判定 PASS。
3. **programbounds 门禁未记录 `--source-duration` 值**：`qa_v2_programbounds.json` 的 `source_range: "16 in range"` 无法单凭该文件锁定阈值。已由本人独立复现相同字符串并证明在 587.33 ~ 1152.233 任一阈值下均通过。属**记录完整性小缺口**，非计算缺陷。
4. **`qa_v2.json`（源秒那遍）未载入 SRT**：`subtitle_span` 与 `subtitle_stats` 均为 `WARN "no srt"/"no stats"`。即真正完成字幕验证的是 `qa_v2_programbounds.json`（PASS / 42 cues）。两遍门禁**结论不冲突**（v2 无 FAIL），但阅读时不应把 `qa_v2.json` 当作字幕已验证的证据。

### 冻结件与源素材状态

- 预览：`…\preview\864-review-v2.mp4`，781,042,716 bytes，mtime `2026-09-30 17:18:47`，**1280×720 / h264 High / yuv420p / CFR 60 / 10,465,670 bps video + 160,195 bps AAC 48 kHz stereo**。
- 字幕：**纯外挂** `…\captions\864-review-v2.srt`（2,367 B，42 条）+ `…\captions\864-review-v2.stats.json`；**MP4 内字幕流 0，无烧录像素字，无烧录版预览**（本人 ffprobe 确认）。
- **源素材未被改动**：`E:\PR导出\864永劫无间 2026-09-30 02-57-13.mp4` 2,984,729,760 bytes，mtime `2026-09-30 09:38:25`（早于本任务全部产物，为只读访问）。
- 本角色**未渲染、未安装、未建环境、未改任何既有文件**；仅写入本报告与 `acceptB_revalidate_v2.json`。**看图 0 张。**

---

STATUS: PASS
