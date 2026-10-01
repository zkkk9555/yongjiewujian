# v4 独立验收作业书（任务 21 / 素材 864）

三个角色彼此独立，**都未参与 v4 的任何执行**。**所有数字必须自己从原始产物重算**，不采信任何他人报告的结论（`issue_list_v3.md` / `change_order_v4.md` / `merge_decision_v3.md` / `adjudicate_v3_*.md` / v3 的任何验收报告只能当线索）。

TASK = `C:\Project\永劫无间\123\21.864永劫无间 2026-09-30 02-57-13`
SRC（**只读，严禁写入/移动/改名**）= `E:\PR导出\864永劫无间 2026-09-30 02-57-13.mp4`（基线：2,984,729,760 B / mtime `2026-09-30 09:38:25`）
FFmpeg/FFprobe = `C:\Project\永劫无间\.video-tools\LosslessCut\resources\`
Python = `C:\Project\永劫无间\.video-tools\venv\Scripts\python.exe`
skill 脚本 = `C:\Project\永劫无间\skills\naraka-highlight-studio\scripts\`

## v4 冻结件（唯一 QA 依据）

| 用途 | 路径 | 指挥声明值（**你要自己复算，不要采信**） |
|---|---|---|
| 冻结预览 v4 | `TASK\preview\864-review-v4.mp4` | 563.021 s / 751,095,441 B / 1280×720 / 60fps CFR / 33,780 帧 / 0 字幕流 |
| 时间线 v4（真源） | `TASK\timeline\combat_episodes_v4.json` | 11 场 / 11 删除段 / **11 处挖洞** / 节目 562.97 s |
| 节目映射 v4 | `TASK\timeline\program_map_v4.json` | **21 个切口** |
| 节目坐标视图 | `TASK\timeline\combat_episodes_v4_programbounds.json` | — |
| 校验 | `TASK\reports\v4_validate.json` | pass=true, 27 check, warnings 0 |
| 解码日志 | `TASK\preview\864-review-v4.decode.log` | exit 0, 0 字节 |
| 媒体滤镜日志 | `TASK\reports\preview_media_filters_v4.log` | freeze 546.638–547.804；silence 551.531–557.338；blackdetect **546.638–548.538（1.9 s）**（v4 日志曾因 `-af` 误用而空段，已用 `-vf` 重生）；I −17.7 LUFS / LRA 9.6 / TP −0.2 dBFS |
| 外挂字幕 | `TASK\captions\864-review-v4.srt` + `.stats.json` + `TASK\reports\srt_crosscheck_v4.json` | 38 条；台账 `68 = 38+0+11+9+10+0`、`180 = 68+24+88` |
| 门禁 | `TASK\reports\qa_v4.json`（源坐标）、`qa_v4_programbounds.json`（节目坐标+SRT） | 均 fail 0 |
| 改动依据 | `TASK\reports\change_order_v4.md` / `TASK\reports\issue_list_v3.md` | — |
| v1/v2/v3 | `preview\864-review-v{1,2,3}.mp4`、`timeline\combat_episodes_v{1,2,3}.json` | **只读对照，不得当 v4 的 QA 依据** |

⚠ `qa_gate.py` 的 `gate_subtitles` 拿**节目钟字幕**比**源钟区间**，属单位错配会假报 FAIL —— 本项目跑两次（源坐标不带 `--srt`；节目坐标视图配 `--srt`）。这是**已登记的工具缺陷，不要当成 v4 的缺陷报**。
⚠ `validate_combat_timeline.py` 第 113 行要求 `0 <= start < engage` **严格小于**。
⚠ **`shots\segN\hd\tXXXX.0.jpg` 的文件名秒点有系统性 +0.4667 s 偏移**（指挥已独立复核两帧）。**不要把那些帧的秒点标签当真值。**

---

## 角色 B · 时间线数字验收员（看图 0 张）

写入 `TASK\reports\acceptB_864_v4.md` + `TASK\reports\acceptB_revalidate_v4.json`（**仅此两件**）。

1. **validate 复核**：存档 `v4_validate.json` 的 `pass`/`episode_count`/`checks` 条数与构成/`warnings`/`program_sum`/`excavated_seconds`/`in_segment_holes_valid.problems`/`deleted_interval_N.overlaps_selected`。**自己重跑**一次 `validate_combat_timeline.py '…\timeline\combat_episodes_v4.json' --source-duration 1152.233 --output '…\reports\acceptB_revalidate_v4.json'`，再与存档做**对象级相等比较**（逐字段 diff 必须 0）。
2. **分段求和**：自己 `import episode_geometry` 重算 `timeline_program_seconds()` 与 `timeline_raw_span_seconds()`；与 `program_map_v4.json` 头部、`programbounds` 头部三处核对。逐洞长度求和必须等于 `raw_span − program_sum`。逐条比对 **21** 个 `cuts[]` 与展开切片：`source_start/end`、`program_start/end`、`source_duration==program_duration`、`Σ program_duration`、`末 program_end`、`Σ rendered_frames` 对上 `ffprobe nb_frames`。
3. **源铺满**：11 条 `deleted_intervals` + 21 段选中区必须**精确铺满 `[0, 1152.233]`**，零缝零重叠（程序化枚举，给出最小缝隙值）。
4. **挖洞合规（v4 有 11 处，比 v3 多 1）**：每处 `excluded_inside` 的 `start<end`、`start>=source_start`、`end<=source_end`、互不重叠、不与 `deleted_intervals` 重叠。**特别核 `combat_007` 新洞 `[624.0, 624.3)`**：两侧邻帧带敌方红条（登记值 166 / 241 px）。
5. **`needs_review` 残留必须 0**；每场 `engage_start`/`outcome_time` 落在 `[source_start, source_end]` 内且 `engage_start >= source_start`。**特别核 v4 的两个新边界**：`combat_002` `source_start=320.27 < engage_start=333.0`；`combat_010` `engage_start` 953.0。
6. **坐标换算零改动**：`combat_episodes_v4_programbounds.json` 与 `combat_episodes_v4.json` **边界数值必须完全相同**。
7. **v3→v4 的 9 项改动逐条核对**：7 项数值改动 + 2 项纯标注（`combat_010` `engage_start`/`impact_points`）。逐条确认**只改了该改的、没顺手改别的**。
8. 每项给「我的实测值 + 绝对路径 + 字段」+ PASS/FAIL，末尾单独一行 `STATUS: PASS` 或 `STATUS: FAIL`。

**禁止**：改 `timeline\`、改预览、装环境、跑 whisper/scenedetect/auto-editor、写出 TASK 以外任何路径。

---

## 角色 C · 预览与字幕验收员（看图 0 张）

写入 `TASK\reports\acceptC_864_v4.md`（**仅此一件**）。

1. **存在性 + 体积**：自己 `ffprobe` 取 `format.duration`/`size`/`bit_rate`；视频 `codec_name`/`profile`/`width`/`height`/`r_frame_rate`/`avg_frame_rate`/`nb_frames`/`bit_rate`/`time_base`/`duration_ts`/`pix_fmt`；音频 `codec`/`sample_rate`/`channels`/`bit_rate`/`nb_frames`/`duration`。**自证不是 4K**（预览 1280×720 vs 源 3840×2160 精确 1/3）。**自证 CFR**：`r==avg==60/1` 整数相等，且 `nb_frames÷60` 与 `duration` 六位小数相等。
2. **解码**：自己跑 `ffmpeg -v error -xerror -i <preview> -f null -`，记退出码与 stderr 行数，与 `preview\864-review-v4.decode.log` 对账。再自己跑 `blackdetect`/`freezedetect`/`silencedetect`/`ebur128` 与 `reports\preview_media_filters_v4.log` 对账。
   **归因（必做）**：把命中点 P 换算回源秒（`S = cut.source_start + (P − cut.program_start)`，`program_map_v4.json` 有 21 个切口），逐条证明 (a) 离所有切口边界足够远 (b) 不在任何 `deleted_intervals` 覆盖内 (c) 不在任何 `excluded_inside` 覆盖内 (d) 被该场 `boundary_reason` 明文要求保留。已知：freeze 546.638–547.804（combat_011 终局黑屏过场）、silence 551.531–557.338（名次屏自身静音）。**另注：blackdetect 本轮零命中，而 v3 曾命中 1.9 s 黑屏 —— 请判断这是「黑屏真的没了」还是「阈值未触发」，给出证据。**
3. **时长对照**：容器 duration vs `program_seconds_total` vs 自己加总 21 个 `cuts[].source_duration`；差值须在 ±0.3 s 内。视频流 vs 音频流 duration 差。
4. **画面污染 + 字幕**：自己 `ffprobe -select_streams s` 确认 `streams == []`；全 TASK 扫 `.srt/.ass/.ssa/.vtt/.sub/.idx`；核对 `qa_v4.json` 的 `no_subtitle_stream`；扫 `cache\*.py` 的 `drawtext|subtitles=|ass=|overlay=`。
5. **外挂字幕**：逐条验 **38** 条 —— ① 不跨切口 ② 无重叠 ③ 起止在节目 `[0, duration]` 内 ④ 文本与 `captions\source_transcript.json` 对得上 ⑤ 台账可复算（`68 = 38+0+11+9+10+0`、`180 = 68+24+88`，字段名以 `.stats.json` 为准）。与 `srt_crosscheck_v4.json` 的 `cross_cut/overlap/timing/gap/pass` 对账。
   **另核**：`cache\srt_crosscheck.py` 的 `MIN_GAP` 现为 **0.12**（v3 时是 0.08，比字幕自报规格松一档），与 `.stats.json` 的 `thresholds.min_gap_seconds` 是否已一致。
6. 末尾单独一行 `STATUS: PASS` 或 `STATUS: FAIL`。WARN 单列，不影响 PASS/FAIL。

**禁止**：改 `timeline\`、改预览、重渲、装环境、写出 TASK 以外任何路径。

---

## 角色 D · 合规验收员（看图 0 张）

写入 `TASK\reports\acceptD_864_v4.md`（**仅此一件**）。

1. **源片未改**：`SRC` 的 `size`/`mtime` 对基线（2,984,729,760 B / `2026-09-30 09:38:25`）；`E:\OBS`、`E:\PR导出` 下无本次新增；无移动/改名。
2. **没偷跑 4K**：全 TASK 扫 mp4 并逐个 `ffprobe` 宽度；`E:\Cujian导出\` 下无 `864*`；无 `*master*`/`*3840*`/`*final*`/`*cujian*` 成片。
3. **目录卫生**：TASK 顶层清单；`C:\Project\` 一级目录清单；`C:\Project\永劫无间\123\` 全部条目。**乱码目录（`姘稿姭鏃犻棿` 之类）与 `123\` 下的 `.txt` 属并发会话（860/861/863），只登记 + 举证 + 建议交人处置，🚫 严禁删除**。**特别核 v3 轮登记过的两处新乱码空壳**：`…\21.864…\shots\adv3r6`、`…\20.863…\shots\segR2\probe`，它们现在是否仍为 0 文件。
4. **路径字面量卫生**：全 TASK 逐个 `.ps1` 统计非 ASCII 字节数 + 有无 UTF-8 BOM。**含非 ASCII 且无 BOM = 违规**。⚠ v3 轮已修过 `shots\selfaudit_v2\build_r1.ps1` / `build_r2.ps1` 两处（加 BOM，载荷逐字节一致），**请复核这两处确已合规**。
5. **渲染脚本**：`cache\render_preview.py` 的 `-i` 只有 `--source`、`-map` 只取源音视频、零 burn 滤镜、无 BGM。
6. **命名规范**：`preview\864-review-v4.mp4`、`captions\864-review-v4.srt`、`timeline\combat_episodes_v4.json`、`program_map_v4.json`、`reports\accept*_864_v4.md` 等三位版本号、无异常空格。
7. **阶段范围**：只应有 720p 预览，**无 BGM、无装饰特效、无字幕烧录/内嵌**。
8. 末尾单独一行 `STATUS: PASS` 或 `STATUS: FAIL`（**只有「工作路径卫生」类问题可以单独 FAIL**）。

**禁止**：删除任何文件或目录（含乱码目录）、改 `timeline\`、改预览、装环境、写出 TASK 以外任何路径。

---

## 三角色共同硬约束

- **看图 0 张**（全部只做数值与命令取证，不抽帧、不看帧）。
- 全程只读既有文件，**只许写自己那一份报告**（B 另加那份 revalidate JSON）。
- 不得修改 v1/v2/v3 任何文件，不得重渲预览，不得运行 4K 渲染，不得安装/升级任何包。
- 不得写出 TASK 目录以外的任何路径。临时脚本放 `TASK\cache\`，文件名带 `_accept{B,C,D}_v4` 前缀；⚠ 新建 `.ps1` **必须纯 ASCII 源码**。
- 报告用 UTF-8 写入。