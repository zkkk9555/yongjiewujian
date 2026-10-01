# v3 独立验收作业书（任务 21 / 素材 864）

三个角色彼此独立，**都未参与 v3 的任何执行**。每个角色只信自己从原始产物重算的数字，**不采信任何他人报告里的结论**（`merge_decision_v3.md` / `adversarial_864_v3_*` / `selfaudit_864_v3.md` / `accept*_v2.md` / `adjudicate_*` 只能当线索，结论必须自己重算）。

TASK = `C:\Project\永劫无间\123\21.864永劫无间 2026-09-30 02-57-13`
SRC（**只读，严禁写入/移动/改名**）= `E:\PR导出\864永劫无间 2026-09-30 02-57-13.mp4`
FFmpeg/FFprobe = `C:\Project\永劫无间\.video-tools\LosslessCut\resources\ffmpeg.exe` / `ffprobe.exe`
Python = `C:\Project\永劫无间\.video-tools\venv\Scripts\python.exe`

## v3 冻结件（唯一 QA 依据）

| 用途 | 路径 |
|---|---|
| 冻结预览 v3 | `TASK\preview\864-review-v3.mp4`（1280×720 / 60fps CFR / 580.304333 s / 34,817 帧 / **0 字幕流** / 干净画面） |
| 时间线 v3（真源） | `TASK\timeline\combat_episodes_v3.json`（11 场 / 11 条删除段 / **10 处段内挖洞**） |
| 节目映射 v3 | `TASK\timeline\program_map_v3.json`（**20 个切口**） |
| 节目坐标视图 | `TASK\timeline\combat_episodes_v3_programbounds.json` |
| 校验存档 | `TASK\reports\v3_validate.json`（`pass=true`，27 check，warnings 0） |
| 媒体滤镜日志 | `TASK\reports\preview_media_filters_v3.log` |
| 解码日志 | `TASK\preview\864-review-v3.decode.log` |
| 外挂字幕 | `TASK\captions\864-review-v3.srt`（40 条）+ `864-review-v3.stats.json` + `TASK\reports\srt_crosscheck_v3.json` |
| 门禁 | `TASK\reports\qa_v3.json`（源坐标）、`qa_v3_programbounds.json`（节目坐标） |
| v1 / v2 冻结包 | `preview\864-review-v{1,2}.mp4`、`timeline\combat_episodes_v{1,2}.json` —— **只读对照，不得当 v3 的 QA 依据** |

工具脚本（只读引用，可运行但**输出只许写进你自己那份报告指定的文件名**）：
- `C:\Project\永劫无间\skills\naraka-highlight-studio\scripts\validate_combat_timeline.py`
- `C:\Project\永劫无间\skills\naraka-highlight-studio\scripts\episode_geometry.py`
- `C:\Project\永劫无间\skills\naraka-highlight-studio\scripts\qa_gate.py`

⚠ `qa_gate.py` 的 `gate_subtitles` 拿**节目时钟的字幕**去比**源时钟的区间**，属单位错配，会假报 FAIL。所以本项目跑两次：源坐标跑 `--no-srt`，节目坐标视图（`*_programbounds.json`）配 `--srt`。这是已登记的已知工具缺陷，**不要当成 v3 的缺陷报**。
⚠ `validate_combat_timeline.py` 第 113 行要求 `0 <= start < engage` **严格小于**。

---

## 角色 B · 时间线数字验收员（看图 0 张）

写入 `TASK\reports\acceptB_864_v3.md` + `TASK\reports\acceptB_revalidate_v3.json`（**仅此两件**）。

1. **validate 复核**：存档 `v3_validate.json` 的 `pass` / `episode_count` / `checks` 条数与构成 / `warnings` 逐条 / `program_sum` / `excavated_seconds` / `in_segment_holes_valid.problems` / `deleted_interval_N.overlaps_selected`。**自己重跑一次** `validate_combat_timeline.py 'TASK\timeline\combat_episodes_v3.json' --source-duration 1152.233 --output 'TASK\reports\acceptB_revalidate_v3.json'`，然后把两个 JSON 做**对象级相等比较**（必须逐字段一致）。
2. **分段求和**：自己 `import episode_geometry` 重算 `timeline_program_seconds()` 与 `timeline_raw_span_seconds()`，与 `program_map_v3.json` 头部 `program_seconds_total`、`programbounds` 头部三处核对。逐洞长度求和必须等于 `raw_span − program_sum`。逐条比对 20 个 `cuts[]` 与展开切片：`source_start/end`、`program_start/end`、`source_duration==program_duration`、`Σ program_duration`、`末 program_end`、`Σ rendered_frames` 对上 `ffprobe nb_frames`。
3. **源铺满**：11 条 `deleted_intervals` + 20 段选中区必须**精确铺满 `[0, 1152.233]`**，零缝零重叠。逐条程序化枚举并给出实测的最小缝隙值。
4. **挖洞合规**：10 处 `excluded_inside` 的 `start < end`、`start >= source_start`、`end <= source_end`、互不重叠、不与 `deleted_intervals` 重叠；并核 `combat_004` `lead_in = 0.01`、`combat_003` 无洞、`combat_006` 尾窗 12.2 s、`combat_008` 可见尾窗 1.4 s 这几条已登记例外的数值是否与 JSON 一致。
5. **`needs_review` 残留必须为 0**；每场的 `engage_start` / `outcome_time` 必须落在 `[source_start, source_end]` 内且 `engage_start >= source_start`。
6. **坐标换算零改动**：`combat_episodes_v3_programbounds.json` 必须与 `combat_episodes_v3.json` **边界数值完全相同**（只允许字段名/坐标系标注不同，不允许任何一个秒数被改）。
7. 报告每项给「我的实测值 + 绝对路径 + 字段」+ PASS/FAIL，末尾单独一行 `STATUS: PASS` 或 `STATUS: FAIL`。

**禁止**：改 `timeline\`、改预览、装环境、跑 whisper/scenedetect/auto-editor、写出 TASK 以外任何路径。

---

## 角色 C · 预览与字幕验收员（看图 0 张）

写入 `TASK\reports\acceptC_864_v3.md`（**仅此一件**）。

1. **存在性 + 体积**：实测 `format.duration` / `size` / `bit_rate`；视频 `codec_name`/`profile`/`width`/`height`/`r_frame_rate`/`avg_frame_rate`/`nb_frames`/`bit_rate`/`time_base`/`duration_ts`/`pix_fmt`；音频 `codec`/`sample_rate`/`channels`/`bit_rate`/`nb_frames`/`duration`。**自证不是 4K**（预览 1280×720 vs 源 3840×2160 精确 1/3）。**自证 CFR**：`r_frame_rate == avg_frame_rate == 60/1` 整数相等，且 `nb_frames ÷ 60` 与 `duration` 六位小数相等。
2. **解码**：自己跑 `ffmpeg -v error -xerror -i <preview> -f null -`，记录退出码与 stderr 行数；与 `preview\864-review-v3.decode.log` 对账。再自己跑一遍 `blackdetect` / `freezedetect` / `silencedetect`，与 `reports\preview_media_filters_v3.log` 逐字符对账。
   **黑屏/冻结/静音归因**：把命中点换算回源秒（`S = cut.source_start + (P − cut.program_start)`），逐条证明它（a）离所有切口边界都足够远、(b) 不在任何 `deleted_intervals` 覆盖内、(c) 不在任何 `excluded_inside` 覆盖内、(d) 被该场的 `boundary_reason` 明文要求保留。v3 媒体滤镜日志里已知三处命中：`black 563.921–565.821`、`freeze 563.921`、`silence 568.814–574.621`。
3. **时长对照**：容器 duration vs `program_seconds_total` vs 自己加总 20 个 `cuts[].source_duration`；差值须在 ±0.3 s 内。视频流 vs 音频流 duration 差。
4. **画面污染 + 字幕**：自己跑 `ffprobe -select_streams s` 确认 `streams == []`；全 TASK 扫 `.srt/.ass/.ssa/.vtt/.sub/.idx`，除 `captions\` 外应 0 个；核对 `reports\qa_v3.json` 的 `no_subtitle_stream`；核对渲染脚本**零 burn 滤镜**（扫 `cache\*.py` 的 `drawtext|subtitles=|ass=|overlay=`）。
5. **外挂字幕**：`captions\864-review-v3.srt` 40 条。逐条验证：① 不跨切口；② 无重叠；③ 起止在节目 `[0, duration]` 内；④ 文本与 `source_transcript.json` 对得上；⑤ 统计台账可复算（`72 = 40+0+12+10+10+0`，`180 = 72+22+86`，字段名以 `.stats.json` 为准）。与 `reports\srt_crosscheck_v3.json` 的 `cross_cut/overlap/timing/gap/pass` 对账。
6. 末尾单独一行 `STATUS: PASS` 或 `STATUS: FAIL`。WARN 项要单独列，不影响 PASS/FAIL 判定。

**禁止**：改 `timeline\`、改预览、重渲、装环境、写出 TASK 以外任何路径。

---

## 角色 D · 合规验收员（看图 0 张）

写入 `TASK\reports\acceptD_864_v3.md`（**仅此一件**）。

1. **源片未改**：`SRC` 的 `size` / `mtime` 与 `reports\` 里登记的基线（2,984,729,760 B / mtime `2026-09-30 09:38:25`）逐项比对；`E:\OBS`、`E:\PR导出` 下无本次新增文件；无任何文件被移动/改名。
2. **没偷跑 4K**：全 TASK 扫 mp4，逐个 `ffprobe` 宽度；`E:\Cujian导出\` 下无 `864*`；无 `*master*`/`*3840*`/`*final*`/`*cujian*` 成片；`deliverables\` 空或只有 ≤720p。
3. **目录卫生**：TASK 内没有多余顶层目录；`C:\Project\` 旁边的乱码目录（`姘稿姭鏃犻棿\` 等）与 `123\` 下的 `.txt` 文件属**并发会话（860/861）**，只**登记 + 用 mtime/内容举证 + 建议交给人处置**，**严禁删除**；本任务自己造成的任何残留也要点名。
4. **路径字面量卫生**：本任务全部 `.ps1` 逐个统计非 ASCII 字节数与有无 BOM。**规则**：含非 ASCII 且无 BOM = 违规（PS 5.1 会按 ANSI 读源码把中文路径读成乱码）。全 ASCII 或有 UTF-8 BOM = 合规。
5. **渲染脚本**：`-i` 只有 `--source` 一个来源；`-map` 只取源音视频；零 `drawtext`/`subtitles`/`ass` 滤镜；无 BGM 混入（音频应只有源直通 AAC）。
6. **命名规范**：`preview\864-review-v3.mp4`、`captions\864-review-v3.srt`、`timeline\combat_episodes_v3.json`、`program_map_v3.json`、`reports\accept*_864_v3.md`、`reports\reverify_864_v3.md`、`reports\freeze_gate_864_v3.md` —— 版本号三位、源文件名去扩展名、无空格异常。
7. **阶段范围**：本阶段只产 720p 审片预览，**没有 BGM、没有装饰特效、没有字幕烧录/内嵌**。若发现越界产物单独报。
8. 末尾单独一行 `STATUS: PASS` 或 `STATUS: FAIL`。只有「工作路径卫生」类问题可以单独 FAIL，其余必须 PASS。

**禁止**：删除任何文件或目录（含乱码目录）、改 `timeline\`、改预览、装环境、写出 TASK 以外任何路径。

---

## 三角色共同硬约束

- **看图 0 张**（角色 B/C/D 全部只做数值与命令取证，不抽帧、不看帧）。
- 全程只读既有文件，**只许写自己那一份报告**（B 另加那份 revalidate JSON）。
- 不得修改 v1/v2 任何文件，不得重渲预览，不得运行 4K 渲染。
- 不得安装/升级任何包或工具。
- 不得写出 TASK 目录以外的任何路径。
- 报告用 UTF-8 写入。