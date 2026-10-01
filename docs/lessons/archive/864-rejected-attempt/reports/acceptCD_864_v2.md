# acceptCD_864_v2.md — 预览字幕验收（C）+ 合规验收（D）

- **角色**：C 预览字幕验收员 与 D 合规验收员（独立验收，我未参与 v2 任何执行：未渲预览、未做字幕、未做扫描或对抗审）
- **验收对象**：任务 21 / 素材 864 的 **v2 冻结候选**
- **TASK** = `C:\Project\永劫无间\123\21.864永劫无间 2026-09-30 02-57-13`
- **SRC（只读）** = `E:\PR导出\864永劫无间 2026-09-30 02-57-13.mp4`
- **FFmpeg/FFprobe** = `C:\Project\永劫无间\.video-tools\LosslessCut\resources\`
- **验收时刻** = 2026-09-30 17:39:37（本机时钟）
- **纪律自证**：全程只读（`Get-ChildItem` / `Get-Item` / 读文本 / `ffprobe` / `ffmpeg -f null` 解码检验 / 两次滤镜空跑）。未渲染任何新视频、未安装、未建环境、未改任何既有文件。**看图 0 张。**
- **本文件是本次唯一写入物。**

---

## 角色 C · 预览与字幕

### C1 存在性 + 体积 —— PASS

| 检查项 | 我的实测值 | 依据（绝对路径） | 判定 |
|---|---|---|---|
| 文件存在 / 非空 | 存在，**781,042,716 B** | `C:\Project\永劫无间\123\21.864永劫无间 2026-09-30 02-57-13\preview\864-review-v2.mp4`（`Get-Item`；mtime **2026-09-30 17:18:47**） | PASS |
| `format.duration` | **587.354333 s** | 同上，`ffprobe -show_format` | PASS |
| `format.size` | **781,042,716** | 同上 | PASS |
| `format.bit_rate` | **10,638,112 bps**（≈10.64 Mbps） | 同上 | PASS |
| 视频流 `codec_name` / `profile` | **h264** / **High**（level 32，`libx264` Lavc62.11.100） | 同上 `-show_streams` | PASS |
| 视频流 `width`×`height` | **1280 × 720** | 同上 | PASS |
| 视频流 `r_frame_rate` / `avg_frame_rate` | **60/1** / **60/1** | 同上 | PASS |
| 视频流 `nb_frames` / `bit_rate` | **35,240** / **10,465,670 bps** | 同上 | PASS |
| 视频流 `time_base` / `duration_ts` | **1/60000** / **35,240,000** | 同上 | PASS |
| 音频流 | **aac LC / 48,000 Hz / 2ch stereo / 160,195 bps / 27,542 帧 / 587.348667 s** | 同上 | PASS |
| **不是 4K**（三重佐证 ①） | 预览 `1280×720`；源实测 `3840×2160` = **精确 1/3 缩放** → 预览是源的下采样，物理上不可能是 4K | 预览见上；源：`E:\PR导出\864永劫无间 2026-09-30 02-57-13.mp4`（`ffprobe -select_streams v:0` → width=3840 height=2160 avg_frame_rate=60/1） | PASS |
| **60 fps CFR**（佐证 ②） | `r_frame_rate == avg_frame_rate == "60/1"`（**整数相等，非近似**）。对照：`reports\preview_probe_v2.json` 记的是 `270643200/4510843` ≈ 59.99995，**不等于** 60/1 —— 见下方 WARN | 同上 | PASS |
| **CFR 帧数自洽**（佐证 ③） | `nb_frames 35,240 ÷ 60 = 587.3333333 s`，与视频流 `duration 587.333333 s` **六位小数完全相等**；且 `duration_ts 35,240,000 ÷ time_base 60,000 = 587.333333 s` 二次互证 | 同上 | PASS |
| **1280×720 720p**（佐证 ④） | `program_map_v2.json` 头声明 `preview_width=1280` / `preview_height=720` / `preview_fps=60`，与实测三项全等 | `C:\Project\永劫无间\123\21.864永劫无间 2026-09-30 02-57-13\timeline\program_map_v2.json` L9–L11 | PASS |

> **⚠ WARN（本项附带，不影响 C1 判定）—— `reports\preview_probe_v2.json` 是过期快照，不得引作交付证据。**
> 该文件 mtime **2026-09-30 17:13:31**，比成品 mp4（17:18:47）早 5 分 16 秒，记录 `size=781,114,172`（差 71,456 B）、`time_base=1/15360`、`duration=587.349349`、视频 `bit_rate=10,466,301`、音频 `nb_frames=27,553`。我的实跑值与之**逐项不同**（781,042,716 / 1/60000 / 587.333333 / 10,465,670 / 27,542）→ 它描述的是**另一个（重渲前的）编码产物**。
> 根因已由渲染员自述落档：`cache\render_preview.py` L93–L99 与 `reports\preview_build_v2.md` L35–L39 记载，v1→v2 之间把切段从 `-ss/-t` 改成 `-frames:v N` 正是为了修 `avg_frame_rate` 59.99995 → 60/1；过期 JSON 是那次修之前的 capture，未刷新。
> **处置建议**：重渲后应重跑一次 `ffprobe` 覆写此文件。交付数字一律以我的实跑值为准（`reports\preview_build_v2.md` L24/L27/L31/L32 引用的正是**正确**的新值，未被污染；`reports\qa_v2.json` 的 `frame_rate=60/1` 也是新的，同样正确）。
> 来源：`C:\Project\永劫无间\123\21.864永劫无间 2026-09-30 02-57-13\reports\preview_probe_v2.json`、`...\reports\preview_build_v2.md`、`...\cache\render_preview.py`

---

### C2 解码 —— PASS

| 检查项 | 我的实测值 | 依据（绝对路径） | 判定 |
|---|---|---|---|
| 我自己跑的全片解码检验 | `ffmpeg -v error -xerror -i <preview> -f null -` → **退出码 0**，**stderr 0 行**，耗时 **107.2 s** | 目标：`C:\Project\永劫无间\123\21.864永劫无间 2026-09-30 02-57-13\preview\864-review-v2.mp4`；ffmpeg：`C:\Project\永劫无间\.video-tools\LosslessCut\resources\ffmpeg.exe` | PASS |
| 与已有 `decode.log` 对账 | 已有 `864-review-v2.decode.log` = **0 字节 = 零行**，与我的 0 行**完全一致**；退出码均为 0 | `C:\Project\永劫无间\123\21.864永劫无间 2026-09-30 02-57-13\preview\864-review-v2.decode.log`（mtime 17:22:36） | PASS |
| 我独立跑 `blackdetect d=0.5 pix_th=0.10` | **`black_start:570.971 black_end:572.871 black_duration:1.9`** | 同上 ffmpeg，退出码 0，耗时 135.1 s | PASS |
| 我独立跑 `freezedetect n=-60dB d=1.0` | **`freeze_start: 570.971`** / **`freeze_end: 572.137667`**（duration 1.166667 s） | 同上 | PASS |
| 与 `preview_media_filters_v2.log` 对账 | **逐字符全等**：log L? 记 `blackdetect … black_start:570.971 black_end:572.871 black_duration:1.9`、`freezedetect … freeze_start: 570.971` / `freeze_duration: 1.166667` / `freeze_end: 572.137667` | `C:\Project\永劫无间\123\21.864永劫无间 2026-09-30 02-57-13\reports\preview_media_filters_v2.log`（1,029,089 B / 5,896 行） | PASS |

#### C2-b 黑屏 / 冻结帧归因：**游戏原生的终局结算过场，不是剪辑引入的缺陷**

| 核验步骤 | 我的实测 | 依据（绝对路径） |
|---|---|---|
| 命中位置 → 哪个切口 | 节目 570.971 与 572.871 **都落在切口 #15**（`vseg015.mp4`，节目 528.1–575.85 / 源 1053.0–1100.75），**不是** #16 | `C:\Project\永劫无间\123\21.864永劫无间 2026-09-30 02-57-13\timeline\program_map_v2.json` L183–L194 |
| 换算到源 | `S = cut.source_start + (P − cut.program_start)`：`570.971 → 1053.0 + 42.871 = ` **源 1095.871**；`572.871 → ` **源 1097.771**；冻结 `572.137667 → ` **源 1097.038** | 同上（我按公式实算） |
| **核验 1：不是切点** | 16 个切口共 32 个节目边界，距 570.971 **最近的边界距离 = 4.879 s**。黑屏整段离两端切点都极远，不可能由拼接造成 | `program_map_v2.json` `cuts[]` 全部 `program_start`/`program_end` |
| **核验 2：未被 `deleted_intervals` 覆盖** | 源 1095.871 **不被 11 条删除段中任何一条覆盖**（相邻两条是 #10 `[1037.0, 1053.0)` 与 #11 `[1127.45, 1152.233)`）。11 条逐条在 `v2_validate.json` 里带 `overlaps_selected:false`，我程序化枚举确认 0 命中 | `C:\Project\永劫无间\123\21.864永劫无间 2026-09-30 02-57-13\timeline\combat_episodes_v2.json`（`deleted_intervals`）与 `...\reports\v2_validate.json`（11 条 `deleted_interval_N`，`overlaps_selected: false`） |
| **核验 3：未被段内挖洞覆盖** | `combat_011.excluded_inside` 全片唯一挖洞 = `[1100.75, 1115.97)`（`category: loading_screen`），**不覆盖** 1095.871 | `combat_episodes_v2.json` → `combat_episodes[id=combat_011].excluded_inside` |
| **核验 4：`boundary_reason` 明文要求保留** | combat_011 `source_start=1053.0` / `source_end=1127.45`；`boundary_reason` 原文含「**1096.0–1097.8 黑屏结算过场**、1097.8–1100.8 队伍战绩展示（含返回大厅/分享）、1098 三角铁 3D 列队过场、1099–1100 分数卡**全部保留在段内**」，且明令「切点正好落在场景切换上，**绝不能切在『打斗→黑屏/结算前』**」 | `combat_episodes_v2.json` → `combat_episodes[id=combat_011].boundary_reason` |
| 数值吻合度 | 我测得源 **1095.871–1097.771** vs 边界理由写 **1096.0–1097.8**。**尾端差 0.029 s，头端差 0.129 s**。头端偏差属 `blackdetect` 语义正常（报的是像素均值首次跌破阈值的帧，早于人工叙述的整零点），尾端几乎重合 | 同上 |
| 结论 | **PASS —— 这是游戏在团灭瞬间原生播放的结算转场黑屏，是"保留"而非"缺陷"。若按剪辑缺陷去挖，反而会切断"战报 → 段位 → 熟练"的终局链。保留、不挖，判定正确。** | 综合上列六项 |

---

### C3 时长对照 —— PASS

| 检查项 | 我的实测值 | 依据（绝对路径） | 判定 |
|---|---|---|---|
| `format.duration` | **587.354333 s** | `C:\Project\永劫无间\123\21.864永劫无间 2026-09-30 02-57-13\preview\864-review-v2.mp4` | — |
| 头声明 `program_seconds_total` | **587.33** | `...\timeline\program_map_v2.json` L6 | — |
| **我自己把 16 条 `cuts[].source_duration` 加一遍** | **587.330000 s**（16 条逐条相加），与头声明**差 0.000000 s** | 同上 L14–L206（我程序化求和） | PASS |
| **差值（容器 vs 节目口径）** | **587.354333 − 587.330000 = +0.024333 s**，**远在 ±0.3 s 内** | 上两行 | PASS |
| 节目轴连续性自检 | 16 条 `program_start`/`program_end` 首尾相接，**0 处断裂**（`program_end[i] == program_start[i+1]`，误差 <1e-6） | 同上 | PASS |
| `rendered_frames` 求和 | **35,240**（= `program_map_v2.json` 16 条 `rendered_frames` 之和）；÷60 = **587.333333** = 视频流 `duration` **精确相等** | 同上 + 预览 `ffprobe` | PASS |
| **视频流 vs 音频流 duration 之差** | 视频 **587.333333** − 音频 **587.348667** = **0.015334 s** | 预览 `ffprobe -show_streams` | PASS |

---

### C4 字幕条数 + 断裂 —— PASS

| 检查项 | 我的实测值 | 依据（绝对路径） | 判定 |
|---|---|---|---|
| SRT **实际条数**（我自己解析） | **42 条**，序号 1–42 连续无缺，时码行 42/42 全部严格匹配 `HH:MM:SS,mmm --> HH:MM:SS,mmm` | `C:\Project\永劫无间\123\21.864永劫无间 2026-09-30 02-57-13\captions\864-review-v2.srt`（2,367 B，LF 换行，UTF-8） | — |
| 与 `.stats.json` 的 `count` 对账 | stats `count=42`、`total=42`；**实际 42 = 声明 42** ✓ | `...\captions\864-review-v2.stats.json` | PASS |
| `dropped_*` 自洽性 | `42 + 0(dropped_empty) + 12(low_conf) + 10(hallucination_loop) + 11(filler_or_short) + 0(cps_or_too_short) = ` **75**，**等于** 声明 `source_segments_inside_retained_windows = 75` ✓ | 同上 | PASS |
| `accounting` 全式自洽 | `inside_retained 75 + split_at_cut(straddling_a_cut) 20 + outside_retained_windows 85 = ` **180**，**等于** 声明 `source_segments = 180` ✓ | 同上 | PASS |
| `source_transcript.json` `segments` 数 | 我数得 **180** 条；与 stats `source_segments=180` **完全一致** ✓ | `...\captions\source_transcript.json`（24,647 B；`segments[0]` 键 = `start/end/text/avg_logprob/no_speech_prob`） | PASS |
| `srt_crosscheck_v2.json` 各计数 | `cue_count=42`、`cross_cut_spans=0`、`overlaps=0`、`timing_problems=0`、`gap_problems=0`、`pass=true`、`stats_match=true` | `...\reports\srt_crosscheck_v2.json`（696 B） | — |
| **我自己再独立数一遍 `problems` 数组** | `problems` = **`[]`（空数组，长度 0）** ✓ | 同上（程序化读 `len(problems)`） | PASS |
| **我自己的断裂复算**（不采信现成 JSON） | `overlaps = 0`（无一条与下一条重叠）；**最小间隔 0.1200 s**（= 阈值 `min_gap_seconds 0.12`，**恰好达标、无一低于阈值**）；`cross_cut_spans = 0`（42 条 cue 的起止落在同一个切口内）；**0 条** cue 时长越界 `[0.8, 7.0]`；单调递增 True；最大结束时刻 584.670 s < 节目 587.33 | 我对 42 条 cue 逐条复算 | PASS |

#### C4-b 抽查 5 条 cue：文本逐字一致 + 时间可反算

| # | cue 节目时间 | cue 文本 | 反算源段 `S = source_start + (P − program_start)` | 命中的 `source_transcript` 源段 | 逐字一致 | 源段在切口内 |
|---|---|---|---|---|---|---|
| 1 | 00:00:25,940 → 00:00:28,100 | `我去与同仁游戏` | 切口 #1 `vseg001`（节目 0–48 / 源 181–229），偏移 25.940 → **源 206.940–209.100** | `src[206.94–209.10] '我去与同仁游戏'` | **✅ 逐字一致** | ✅ 181 ≤ 206.94 且 209.10 ≤ 229 |
| 7 | 00:01:47,150 → 00:01:49,860 | `我去打药` | 切口 #3 `vseg003`（节目 80.5–120.5 / 源 305–345），偏移 26.650 → **源 331.650–334.360** | `src[331.65–334.36] '我去打药'` | **✅ 逐字一致** | ✅ 305 ≤ 331.65 且 334.36 ≤ 345 |
| 14 | 00:02:30,190 → 00:02:32,190 | `这他妈的给我震了` | 切口 #4 `vseg004`（节目 120.5–167.5 / 源 357–404），偏移 29.690 → **源 386.690–388.690** | `src[386.69–388.69] '这他妈的给我震了'` | **✅ 逐字一致** | ✅ 357 ≤ 386.69 且 388.69 ≤ 404 |
| 25 | 00:04:32,270 → 00:04:36,870 | `有人在削一刀` | 切口 #9 `vseg009`（节目 260.7–322.2 / 源 598–659.5），偏移 11.570 → **源 609.570–614.170** | `src[609.45–614.17] '有人在削一刀'` | **✅ 逐字一致** | ✅ 598 ≤ 609.45 且 614.17 ≤ 659.5 |
| 42 | 00:09:43,100 → 00:09:44,670 | `我要去睡觉了` | 切口 #16 `vseg016`（节目 575.85–587.33 / 源 1115.97–1127.45），偏移 7.250 → **源 1123.220–1124.790** | `src[1123.22–1124.79] '我要去睡觉了'` | **✅ 逐字一致** | ✅ 1115.97 ≤ 1123.22 且 1124.79 ≤ 1127.45 |

依据：`...\captions\864-review-v2.srt`、`...\captions\source_transcript.json`、`...\timeline\program_map_v2.json`。**5/5 零改写、零幻觉、零跨切口。**

#### C4-c 主动加严：把抽查扩到全部 42 条

抽 5 条不构成证据强度，我自己把同一套核验跑满了全部 42 条：

| 指标 | 结果 |
|---|---|
| cue 文本在其**自身切口窗口内**逐字命中源段 | **42 / 42** |
| 文本只存在于窗口之外（会造成时间错配） | **0** |
| 文本在整个转写里**根本不存在**（幻觉） | **0** |
| 命中的源段**跨切点**（cue 被撕开） | **0** |
| 重复文本歧义 | 2 处（`得做好万全准备` 在源里 3 次、`我在干 我在干` 2 次）—— 但每条 cue 都在**自己切口窗口内**唯一命中对应源段，**不构成错配** |

**判定 PASS。字幕既无改写也无幻觉，时间轴与节目时钟自洽。**

---

### C5 零字幕流 + 零烧录 —— PASS

| 检查项 | 我的实测值 | 依据（绝对路径） | 判定 |
|---|---|---|---|
| **我自己跑 `ffprobe -select_streams s`**（不采信现成 JSON） | 返回 `"streams": []` → **`codec_type == "subtitle"` 的流数 = 0** ✓ | `C:\Project\永劫无间\123\21.864永劫无间 2026-09-30 02-57-13\preview\864-review-v2.mp4` + `C:\Project\永劫无间\.video-tools\LosslessCut\resources\ffprobe.exe` | PASS |
| **全部流清单** | `0 = h264 / video / avc1`、`1 = aac / audio / mp4a`。**仅此两条** | 同上 | PASS |
| `nb_streams` / `nb_programs` / `nb_stream_groups` | **2 / 0 / 0** → 无章节轨、无流组、无附加轨 | 同上 `-show_entries format=...` | PASS |
| 容器 `disposition` 全字段 | 视频流 `attached_pic/timed_thumbnails/captions/descriptions/lyrics/…` **全为 0**；无 `default` 之外的额外处置标记 | 同上 | PASS |
| `preview\` 下所有文件（4 个，逐个列出） | `864-review-v1.mp4`（802,410,248 B）、`864-review-v1.decode.log`（3 B）、`864-review-v2.decode.log`（0 B）、`864-review-v2.mp4`（781,042,716 B） | `C:\Project\永劫无间\123\21.864永劫无间 2026-09-30 02-57-13\preview\` | PASS |
| **`preview\` 下无 `.srt` 兄弟文件** | **0 个 `.srt`** ✓ | 同上 | PASS |
| `preview\` 下无 `*burn*` / `*sub*` / `*caption*` / `*字幕*` | 全 TASK 名称扫描：`preview\` 命中 **0** | 同上 | PASS |
| **全 TASK 搜字幕文件 → 只住在 `captions\`** | 全 TASK（8,066 文件）扩展名扫描 `.srt/.ass/.ssa/.vtt/.sub/.idx` 共命中 **2 个**：`captions\864-review-v1.srt`(2,923 B)、`captions\864-review-v2.srt`(2,367 B)。**全部在 `captions\`，`preview\` / `cache\` / `shots\` / `reports\` / `timeline\` / `analysis\` / `audio\` 零命中。** | `C:\Project\永劫无间\123\21.864永劫无间 2026-09-30 02-57-13\`（递归） | PASS |
| **零烧录（独立证据链）** | ① 字幕流 0（上方）；② 渲染命令滤镜链只有 `scale=1280:720:flags=lanczos,fps=60`，**无任何字幕/文字滤镜**（见 D5 逐行核对）；③ `preview\` 无任何 burn 变体文件 | 见 D5 | PASS |

> **明确结论：本版预览是「零字幕流、零烧录」。字幕只以外挂 SRT 交付** —— 唯一交付物为
> `C:\Project\永劫无间\123\21.864永劫无间 2026-09-30 02-57-13\captions\864-review-v2.srt`，
> 播放器按需挂载。**不存在合法烧录版，本次也未产出任何烧录产物。**

---

## 角色 D · 合规

### D1 源片未动 —— PASS

| 检查项 | 我的实测值 | 依据（绝对路径） | 判定 |
|---|---|---|---|
| 源片 `Length` | **2,984,729,760 B** | `Get-Item` → `E:\PR导出\864永劫无间 2026-09-30 02-57-13.mp4` | — |
| 与探测记录对账 | `analysis\source_probe_raw.json` 的 `format.size` = **2,984,729,760** → **完全一致，差 0 字节** ✓ | `C:\Project\永劫无间\123\21.864永劫无间 2026-09-30 02-57-13\analysis\source_probe_raw.json`（`format.size`，mtime 12:54:26） | PASS |
| `CreationTime` | **2026-09-30 09:38:10** | 同源片 `Get-Item` | PASS |
| `LastWriteTime` | **2026-09-30 09:38:25** —— **早于本任务第一件产物（12:54:26）3 小时 16 分** | 同上 | PASS |
| `LastAccessTime` | 2026-09-30 09:38:25（未变，读访问不刷新此卷的 atime） | 同上 | PASS |
| 源参数未被改写的旁证 | 探测记录：3840×2160、60/1、`nb_frames 69,134`、`duration 1152.233333`、`bit_rate 20,723,092`；`creation_time` 标签 `2026-09-30T01:38:10Z`（= 本地 09:38:10，与文件系统 `CreationTime` 自洽） | `...\analysis\source_probe_raw.json` | PASS |

**`E:\PR导出\` 下全部 `86*.mp4`（8 个，逐个列出）：**

| 修改时间 | 创建时间 | 字节 | 文件名 |
|---|---|---|---|
| 2026-09-29 09:13:20 | 2026-09-29 09:12:34 | 6,191,704,638 | `860永劫无间2026-09-26 22-43-03.mp4` |
| 2026-09-29 09:31:05 | 2026-09-29 09:30:45 | 6,226,961,899 | `861永劫无间 2026-09-26 23-26-54.mp4` |
| 2026-09-30 07:00:03 | 2026-09-30 06:59:32 | 9,072,741,151 | `862.1永劫无间 2026-09-29 22-50-22.mp4` |
| 2026-09-30 07:23:13 | 2026-09-30 07:22:47 | 8,922,892,704 | `862.2永劫无间 2026-09-29 22-50-22.mp4` |
| 2026-09-30 07:33:54 | 2026-09-30 07:33:34 | 3,735,036,246 | `862.3永劫无间 2026-09-29 22-50-22.mp4` |
| 2026-09-30 08:27:20 | 2026-09-30 08:26:35 | 21,730,420,482 | `862永劫无间 2026-09-29 22-50-22.mp4` |
| 2026-09-30 08:34:31 | 2026-09-30 08:34:23 | 2,894,848,189 | `863永劫无间 2026-09-30 02-57-13.mp4` |
| **2026-09-30 09:38:25** | **2026-09-30 09:38:10** | **2,984,729,760** | **`864永劫无间 2026-09-30 02-57-13.mp4`（本任务源）** |

**判定：无任何在本任务窗口（约 12:50 起）内被写入或改名的迹象。** 8 个文件最新 `LastWriteTime` = **09:38:25**，全部早于窗口起点；`864` 的 mtime 与 ctime 相差 15 秒且都落在 09:38，是 PR 导出的产物特征时间，与本任务无因果关系。**结论：源片原始素材未被修改、未被覆盖、未被改名。**

---

### D2 无 4K 偷跑 —— PASS

| 检查项 | 我的实测值 | 依据（绝对路径） | 判定 |
|---|---|---|---|
| 递归列 `TASK\` 下所有 `*.mp4` 逐个 `ffprobe` | **共 35 个 mp4，全部实测完毕** | `C:\Project\永劫无间\123\21.864永劫无间 2026-09-30 02-57-13\`（递归） | — |
| 分辨率分布 | **34 个 = 1280×720 @ 60/1**；**1 个 = 640×360 @ 30/1**（即 `cache\proxy_360p30.mp4`，分析代理）。**3840×2160 命中数 = 0** | 同上 + `ffprobe -select_streams v:0` | PASS |
| **不存在任何 4K 视频产物** | 无一文件 width=3840 或 height=2160；最高分辨率即 1280×720 | 同上 | **PASS** |
| `cache\v2segs\` 的 16 个分段 | **16/16 全部 1280×720 @ 60/1**，时长 48.000 / 32.500 / 40.000 / 47.000 / 27.300 / 22.500 / 36.800 / 6.600 / 61.500 / 23.800 / 55.000 / 7.100 / 32.000 / 88.000 / 47.750 / 11.483333，合计 **587.333333 s** | `...\cache\v2segs\vseg001.mp4` … `vseg016.mp4` | PASS |
| `cache\v1segs\` 12 个 + `cache\smoke\` 4 个 | 16 个也全部 1280×720 @ 60/1（v1 遗留 + 冒烟） | `...\cache\v1segs\`、`...\cache\smoke\` | PASS |
| `*master*` 命名 | **0 命中** | 全 TASK 8,066 文件名扫描 | PASS |
| `*3840*` 命名 | **0 命中** | 同上 | PASS |
| `*final*` 命名 | **0 命中** | 同上 | PASS |
| `*cujian*` 命名 | **0 命中** | 同上 | PASS |
| `*burn*` 命名 | **0 命中** | 同上 | PASS |
| `*4k*` 命名 —— **需分开说明** | **8 命中，全部是 `.jpg` 取证联系表，0 个是视频产物**：`shots\seg11\verify\banner4k\sheets\b4k_01..03.jpg`、`shots\seg11\verify\feed4k\sheets\f4k_01..02.jpg`、`shots\seg11\verify\feed4k_early\sheets\e4k_01..03.jpg`。这些是 4K 源取证的抽帧（`*.jpg`，无视频流），**不构成 4K 成片/4K 预览** | 同上 | PASS |
| `TASK\deliverables\` 状态 | **目录不存在**（粗剪阶段正确状态：既无空目录也无成片副本） | `C:\Project\永劫无间\123\21.864永劫无间 2026-09-30 02-57-13\deliverables`（`Test-Path` = False） | PASS |
| `E:\Cujian导出\` 下有无 `864*` 成片 | **`864*` 命中 = 0**。该目录现有 21 个 `cujian.mp4`（830/832/834/835/837/838/839/840/841/842/844/846/847/848/849/852/853/854/855/858/859），**最新一个是 859**（2026-09-30 10:00:03）。本素材 864 未出现在交付目录 | `E:\Cujian导出\` | PASS |

**判定：本任务全程只做了 720p 预览渲染，无 4K 偷跑，交付目录未被提前占用。**

---

### D3 目录合规 —— PASS（附 3 条登记与 1 条需人处置的越界）

| 检查项 | 我的实测值 | 依据（绝对路径） | 判定 |
|---|---|---|---|
| `TASK\` **根级文件** | **0 个**（根级只有目录，无游离文件） | `C:\Project\永劫无间\123\21.864永劫无间 2026-09-30 02-57-13\` | PASS |
| 8 个根级子目录逐一判断 | `analysis\`(3 文件，探测/场景/音频活动) ✔ 合法；`audio\`(1，转写用 wav) ✔ 合法；`cache\`(77，分段中间件+脚本) ✔ 合法；`captions\`(5，外挂 SRT+stats+转写源) ✔ 合法；`preview\`(4，v1/v2 预览+解码日志) ✔ 合法；`reports\`(59，审计/验收/门禁/裁决) ✔ 合法；`shots\`(7,989，取证抽帧) ✔ 合法；`timeline\`(8，时间线与节目映射) ✔ 合法。**8/8 全部合法，无一处越界** | 同上 | PASS |
| 项目根游离物扫描 | `C:\Project\永劫无间\` 下 `f_*.jpg` = **0**、`thumb_*.jpg` = **0**、`*.mp4` = **0**、`*.srt` = **0** | 同上 | PASS |
| `qa_v2.json` 的 `workspace_hygiene` | `"PASS" / "no root strays"` —— 与我的独立扫描结论一致 | `...\reports\qa_v2.json` | PASS |

#### D3-登记 ①：`C:\Project\` 下的乱码目录（**只列、登记，不删不改**）

| 项 | 我的实测 |
|---|---|
| 路径 | `C:\Project\姘稿姭鏃犻棿`（码位 `U+59D8 U+7A3F U+59ED U+93C3 U+72BB U+68FF`，正是「永劫无间」UTF-8 字节被按 GBK 读的乱码形态） |
| mtime | **2026-09-30 13:13:59**（根） |
| 体量 | **0 个文件，8 个目录**（是空壳目录树，不是副本） |
| 内含 | `123\18.860姘稿姭鏃犻棿2026-09-26 22-43-03\shots\adv_v5_3`（mtime 13:13:59）**和** `123\21.864姘稿姭鏃犻棿 2026-09-30 02-57-13\shots\adv2r2\sel_r2_residue`（mtime **2026-09-30 17:38:19**） |
| **判据（为何判定为非本任务产物 / 为何现在要紧）** | 该乱码树里**出现了本任务编号 21 的乱码孪生目录**，mtime **17:38:19 落在本次验收窗口之内**；而本任务真实目录下 `shots\adv2r2\mk.ps1` 的写入时间是 **17:38:29**，其产物 `shots\adv2r2\sel_r2_residue\sheets\r2_residue_01.jpg` 是 **17:39:01**。乱码孪生树比脚本落盘早 10 秒 → 结论：**本任务内某个对抗审复核动作在命令行传 `-TaskDir` 时用了被 ANSI 读坏的 CJK 路径**，把目录建到了乱码树下。 |
| 我查了脚本本身 | `shots\adv2r2\mk.ps1`（1,498 B）**是纯 ASCII**，并且脚本头部注释明确写着「ASCII-only on purpose: a UTF-8-no-BOM .ps1 holding the CJK task path gets read as ANSI by PowerShell 5.1 and mangles it. TaskDir arrives on the command line.」→ **脚本本身合规，乱码在调用方**（与 AGENTS.md §1 的成因描述一致） |
| **处置** | **登记，不删不改。** 这是 `check_video_environment.ps1` 的 `[BLOCKER] stray dirs beside project`（退出码 2），会阻断"新任务开工"，但不影响本任务在途。删目录属破坏性动作，须人确认后由 `scripts\sanitize_stray_dirs.ps1 -Remove` 执行。 |

#### D3-登记 ②：`123\` 根的 `.txt` 副本（**只列、登记，不删不改**）

| 项 | 我的实测 |
|---|---|
| 路径 | `C:\Project\永劫无间\123\19.861永隙无间_x.txt` |
| 大小 / mtime | **78,884 B** / **2026-09-30 13:19:35** |
| 同级合法文件 | `README.md`(4,268 B，取号规则)、`cleanup_log_top_2026-09-24.md`(2,449 B) —— 属项目自带，不是游离物 |
| 判据 | 文件名主体是 **`19.861`**（并发会话的编号），本任务是 **21**；内容为 `19.861` 任务的文本副本（`cleanup_log_v2.md` 记其 SHA256 与 `19.861…\shots\adv_v5\adv1\lane_meta.txt` 相同）。它落在 `123\` 根而非任务目录内 = 路径写坏的指纹。 |
| **判据（并发起义的独立证据）** | `123\18.860永劫无间2026-09-26 22-43-03\` 内**最新文件 mtime = 2026-09-30 17:37:16**（`cache\v7_episodes.txt`）→ **该目录在本次验收期间仍在被写入**；`123\19.861永劫无间 2026-09-26 23-26-54\` 内**最新文件 mtime = 2026-09-30 16:41:28**（`reports\accept_19_v9.md`）→ **今天仍在被写入**。两者都不是本任务目录，与本任务无因果关系。 |
| 处置 | **登记，不删不改。** |

#### D3-编号无重复 + 误建残留 —— PASS

| 检查项 | 我的实测值 | 依据 | 判定 |
|---|---|---|---|
| `123\` 下全部目录名 | `13.849…`、`14.854…`、`15.855…`、`16.858…`、`17.859…`、`18.860…`、`19.861…`、`20.863…`、`21.864…`、`workflow_upgrade` | `C:\Project\永劫无间\123\` | — |
| **编号无重复（目录层面）** | 数字前缀 `13,14,15,16,17,18,19,20,21` —— **8 个连续编号各 1 次，0 重复**。（我的正则首轮误报 `19` 重复，追查后确认是 D3-登记② 那个 `.txt` **文件**被前缀正则捞进来了，目录层面不存在重复。） | 同上（程序化正则 + `isdir` 过滤） | PASS |
| **`20.863永劫无间 2026-09-30 02-57-13` 与本任务是否冲突？** | 不冲突：素材号不同（863 vs 864），源文件不同（`863永劫无间 2026-09-30 02-57-13.mp4`，2,894,848,189 B vs 本任务 864 的 2,984,729,760 B），只是 OBS 录制时刻相同导致文件名尾巴一样 | `E:\PR导出\` | PASS |
| **14:42 误建的 `21.864永劫无间 2026-05-13` 是否残留？** | **否。** 我对 `123\` 整树递归扫描，匹配 `2026-05-13` 的路径 = **`[]`（0 处）** | `C:\Project\永劫无间\123\`（递归） | PASS |
| 与 `cleanup_log_v2.md` 的记录对账 | 该文件「一次已执行的纠正性删除」节记载：误建目录内只有 1 个文件 `cache\srt_crosscheck.py`（3,357 B），删除前验证「目录内文件数 == 1 且文件名 == srt_crosscheck.py」，随后删文件与两个空目录 —— **我的独立扫描结果（0 残留）与之一致** | `...\reports\cleanup_log_v2.md`；`...\cache\srt_crosscheck.py`（4,357 B，正确路径下确实存在） | PASS |

#### D3-脚本编码自查 —— PASS

| 检查项 | 我的实测值 | 依据 | 判定 |
|---|---|---|---|
| 列 `TASK\**\*.ps1` 逐个读字节 | **19 个 .ps1**（首轮 18 个 → 复检时 `shots\adv2r2\mk.ps1` 于 17:38:29 新建，计数变 19；我已复检全部 19 个） | `C:\Project\永劫无间\123\21.864永劫无间 2026-09-30 02-57-13\`（递归） | — |
| 含非 ASCII 字节的个数 | **0 个**（19/19 **全部纯 ASCII**，0 个含非 ASCII 字节） | 逐文件 `[IO.File]::ReadAllBytes` 统计 `_ > 127` | PASS |
| 有 UTF-8 BOM 的个数 | **0 个**（19/19 无 BOM）—— 因内容纯 ASCII，**无 BOM 不构成风险** | 同上（查 `EF BB BF`） | PASS |
| **高风险脚本数（含非 ASCII 且无 BOM）** | **0** —— 全部 19 个均为「纯 ASCII = 无所谓」，**不存在 AGENTS.md §1 描述的 PS 5.1 按 ANSI 读源码把中文路径读成乱码的触发条件** | 同上 | PASS |
| 附带发现 | `shots\adjudicate_c\tools\`、`shots\adjudicate_a\fastseek.ps1` 等中间脚本也全部纯 ASCII；项目级 `C:\Project\永劫无间\scripts\*.ps1` 不在本次范围（预检 WARN 项，非本任务产物） | 同上 | PASS |

---

### D4 命名规范 —— WARN（后缀差异声明 + 两项三分立报告未落盘）

| 规范项 | 实际 | 判定 |
|---|---|---|
| `preview\864-review-v2.mp4`（序号 = 素材编号、`-review-v<N>`） | ✔ `864` = 素材号，`-review-v2` = 第 2 版 | PASS |
| `timeline\combat_episodes_v2.json` | ✔ 存在（110,489 B，17:00:53） | PASS |
| `timeline\program_map_v2.json` | ✔ 存在（5,014 B，17:18:47） | PASS |
| `captions\864-review-v2.srt` + `.stats.json` | ✔ 两者都在（2,367 B / 1,068 B，17:20:12），且与预览同名同版本 | PASS |
| `reports\v2_validate.json` | ✔ 存在（6,910 B，17:10:44）。**声明映射**：规范名为 `v2_validate.json`，不带 `864` 前缀 —— 与「已知后缀差异」清单同批，此处按规范名本身核对，**不算缺失** | PASS（声明） |
| 三分立 `selfaudit_864_v2.md` | ✖ **未落盘**。`reports\` 里只有 `selfaudit_864_v1.md`（62,345 B，15:43:27）。而 `cleanup_log_v2.md` 开头把「`selfaudit_864_v2.md`」写成 v2 冻结的触发条件之一 → **声明的冻结件与磁盘实况不符** | **WARN** |
| 三分立 `accept*_864_v2.md` | ✔ `acceptB_864_v2.md`（36,918 B，17:32:28）已在；**本文件 `acceptCD_864_v2.md` 即 C+D 两席**；v1 有 `acceptC_864_v1.md` / `acceptD_864_v1.md` | PASS |
| 三分立 `reverify_*` | ✖ **`reports\` 下 `*reverify*` 命中 = 0**。v1 的复验件也不存在（v1 只有 `acceptB_revalidate_v1.json`） | **WARN** |
| **已知后缀差异（按要求声明映射，不记为缺失）** | ① `timeline\combat_episodes_v2_programbounds.json`（4,781 B）← 程序边界视图；② `timeline\proxy_map_v2.json`（785 B）← 代理对账；③ `reports\qa_v2_programbounds.json`（4,360 B）← 门禁的程序边界版；④ `reports\acceptB_revalidate_v2.json`（6,910 B）← B 席复验数据。四者均缺 `864` 前缀，但**版本号 `v2` 一致、归属明确**，按声明处理 | PASS（声明） |
| 附带观察 | v2 的对抗审只落了 `adversarial_864_v2_adv1/adv4/adv5`（3 篇，adv2/adv3/adv6/adv7/adv8 尚缺），v1 是 8 篇。对抗审是否收齐属于流程进度，不在 C/D 两席的验收口径内，仅登记 | 登记 |

---

### D5 无烧录 / 无内嵌 —— PASS

| 检查项 | 我的实测值 | 依据（绝对路径） | 判定 |
|---|---|---|---|
| 滤镜链（逐行读脚本） | **L107**：`"-vf", f"scale={args.width}:{args.height}:flags=lanczos,fps={args.fps}"` —— **整条视频滤镜链只有 `scale`（lanczos）+ `fps`**，**没有任何字幕/文字滤镜**，没有 `overlay`、`amix`、`sidechaincompress`、`eq`、`drawtext`、`subtitles` | `C:\Project\永劫无间\123\21.864永劫无间 2026-09-30 02-57-13\cache\render_preview.py` | PASS |
| `-filter_complex` | **脚本中不存在 `-filter_complex`**（grep `"-filter"` 仅命中 `-vf`，见 L107） | 同上 | PASS |
| **烧录开关** | **不存在任何烧录开关。** `argparse` 的 9 个参数为 `--timeline / --source / --out / --map-out / --seg-dir / --width / --height / --fps / --crf / --preset / --reuse`，**无 `--burn`、无 `--sub`、无 `--subtitle`、无 `--caption`**；模块 docstring L8–L9 反向声明「no subtitle stream, no burned-in text, no BGM, no decorative effects」 | 同上 L36–L51、L8–L9 | PASS |
| **`-map` 只取源的一条视频与一条音频** | **L106**：`"-map", "0:v:0", "-map", "0:a:0"` —— **恰好两条，且都来自 `0:`（唯一输入 = 源文件）**。L104–L105 显示 `-ss <source_start>` 后只有**一个** `-i args.source`，即整个滤镜链**只有一个视频输入、一个音频输入**，物理上不存在可混入的第二路画面或声音 | 同上 L102–L115 | PASS |
| 音频编码参数（反证无混音） | L112：`-c:a aac -b:a 160k -ar 48000 -ac 2` —— 纯转码，**无第二路音频输入、无 `amix`/`volume`/`loudnorm`/`atempo`**；实测预览音频 `aac LC 48 kHz stereo 160,195 bps` 与源 `aac LC 48 kHz stereo 317,370 bps` 同规格，码率下降来自选段而非混音 | 同上 L112；预览与 `analysis\source_probe_raw.json` 的 `ffprobe` | PASS |
| 合成阶段 | L126–L128：`-f concat -safe 0 -i concat.txt -c copy -r 60 -video_track_timescale 60000 -movflags +faststart` —— **纯流拷贝，无滤镜**，烧录不可能在此注入 | 同上 | PASS |
| **`drawtext` / `subtitles` / `ass` 在本任务脚本中的全部出现位置** | **预览渲染链（`render_preview.py`）内出现次数 = 0**。全 `cache\` 目录扫 `*.py`：`drawtext|subtitles=|ass=` 仅命中 `cache\srt_crosscheck.py` L95 的一处 `result['pass']` 字样（**是字符串 `pass`，与字幕滤镜无关**）。**`drawtext` 真正出现的两处都在抽帧/拼表脚本里**：`cache\extract_all_frames.ps1` L32 与 `cache\make_route_frames.ps1` L60 —— 两者用 `drawtext=…text='%{pts\:hms}'` 给**取证用 JPG 抽帧**打时间码标签（黄色字幕框 + `fontfile`），属**分析证据图**，**不产出任何 MP4**，与预览渲染链无调用关系 | `...\cache\extract_all_frames.ps1` L32；`...\cache\make_route_frames.ps1` L60；`...\cache\srt_crosscheck.py` L95；`...\cache\render_preview.py` | PASS |
| 与 C5 交叉印证 | 预览 `-select_streams s` = **0** 条字幕流；`preview\` 下无 burn 变体；全 TASK 字幕文件只在 `captions\` —— **脚本层（无烧录开关/无字幕滤镜）与产物层（零字幕流/零烧录）双向闭合** | 见 C5 | PASS |

---

### D6 本阶段范围 —— PASS

| 检查项 | 我的实测值 | 依据（绝对路径） | 判定 |
|---|---|---|---|
| **只出了 720p 审片预览** | `preview\` 下唯一 v2 产物 = `864-review-v2.mp4`，**1280×720**；全 TASK 35 个 mp4 无一 4K（见 D2）；`deliverables\` 不存在 | `...\preview\864-review-v2.mp4` | PASS |
| **没有出 4K 成片** | `E:\Cujian导出\` 下 `864*` 命中 **0**（现有 21 个，最新为 859）；`TASK\` 内无 `*master*`/`*3840*`/`*final*`/`*cujian*` 命名产物；`TASK\deliverables\` 不存在 | `E:\Cujian导出\`；全 TASK 文件名扫描 | PASS |
| **预览只有 1 条视频 + 1 条音频** | `ffprobe` 流清单 = `0 h264 video`、`1 aac audio`；`nb_streams=2`、**`nb_programs=0`**（无章节）、**`nb_stream_groups=0`**（无流组）、无 `data`/`attachment` 流 | `...\preview\864-review-v2.mp4` | PASS |
| **无背景音乐轨** | 唯一音频流 = 源音轨直通（脚本只有 `-map 0:a:0` 一个音频输入，见 D5），`aac LC 48 kHz stereo`；无第二条音频流 → **结构上不可能存在 BGM 轨** | 同上 + `...\cache\render_preview.py` L106/L112 | PASS |
| **无章节轨 / 无数据轨** | `nb_programs = 0`、`nb_stream_groups = 0`、流数 = 2（video+audio），无 `mov_text`/`bin_data`/`chapter` 迹象 | 同上 | PASS |
| **无装饰特效** | 滤镜链仅 `scale=lanczos,fps`；无 `drawtext`/`overlay`/`gltransition`/`xfade`/`zoompan`/`fade`/`gblur`/`eq`/`vignette`；docstring 明文「no decorative effects」 | `...\cache\render_preview.py` L8–L9、L107 | PASS |
| **`audio\audio_16k.wav` 未被拼进预览** | 实测 `pcm_s16le / 16,000 Hz / 1ch mono / 1,152.234688 s / 36,871,588 B`。预览音频 = `aac LC / 48,000 Hz / 2ch stereo / 587.348667 s`。**采样率 16k≠48k、声道 1≠2、时长 1152.23≠587.35** → 三项全不同，**不可能被拼入** | `...\audio\audio_16k.wav`（`ffprobe`）；`...\preview\864-review-v2.mp4`（`ffprobe`） | PASS |
| **`cache\proxy_360p30.mp4` 未被拼进预览** | 实测 `h264 / 640×360 / avg_frame_rate 30/1 / 1,152.233008 s / 89,403,741 B`。预览 = `1280×720 / 60/1 / 587.354333 s`。**分辨率、帧率、时长三项全不同** → 未被拼入 | `...\cache\proxy_360p30.mp4`（`ffprobe`）；`...\preview\864-review-v2.mp4` | PASS |
| **脚本参数反证** | `render_preview.py` 的**唯一** `-i` 是 `--source`（本次传入 `E:\PR导出\864永劫无间 2026-09-30 02-57-13.mp4`，即 4K 原片），既未引用 `audio_16k.wav` 也未引用 `proxy_360p30.mp4`；两个文件都是分析期产物，只被 `cache\transcribe.py` / `split_routes.ps1` 一类脚本消费 | `...\cache\render_preview.py` L104–L105；`...\cache\proxy_360p30.mp4` 建于 12:58:28、`...\audio\audio_16k.wav` 建于 12:54:41 | PASS |

---

## 结论

**角色 C（预览与字幕）**：C1 存在性+体积 **PASS** ／ C2 解码 **PASS** ／ C3 时长对照 **PASS** ／ C4 字幕条数+断裂 **PASS** ／ C5 零字幕流+零烧录 **PASS**。
附带 1 条 **WARN**：`reports\preview_probe_v2.json` 是重渲前的过期快照（`size 781,114,172`、`avg_frame_rate 270643200/4510843`），不得引作交付证据，建议重渲后覆写。

**角色 D（合规）**：D1 源片未动 **PASS** ／ D2 无 4K 偷跑 **PASS** ／ D3 目录合规 **PASS**（含 2 条越界登记 + 2 条乱码判据，均只登记不处置） ／ D4 命名规范 **WARN**（四项后缀差异已声明；`selfaudit_864_v2.md` 与 `reverify_*864_v2` 未落盘） ／ D5 无烧录/无内嵌 **PASS** ／ D6 本阶段范围 **PASS**。

**须提请人处置（我未删、未改）**：
1. `C:\Project\姘稿姭鏃犻棿\` —— 乱码目录树，含本任务编号 21 的乱码孪生目录 `...\123\21.864姘稿姭鏃犻棿 2026-09-30 02-57-13\shots\adv2r2\sel_r2_residue`（mtime **17:38:19**，落在本次验收窗口内）。这是 `check_video_environment.ps1` 的 `[BLOCKER] stray dirs beside project`，会阻断新任务开工。**删目录属破坏性动作，须人确认后跑 `scripts\sanitize_stray_dirs.ps1 -Remove`。**
2. `C:\Project\永劫无间\123\19.861永隙无间_x.txt`（78,884 B）—— 并发会话的 `.txt` 副本，只登记。

**同时登记（非缺陷，供流程知悉）**：本任务目录 `shots\` 子树在本次验收期间仍被对抗审并发写入（最新 `shots\adv2r2\sel_r2_cut167\sheets\r2_cut167_01.jpg` = **17:39:33**）。已逐一复核**全部 v2 冻结件在验收窗口内 mtime 全部未变**（`preview\864-review-v2.mp4` 17:18:47 / `program_map_v2.json` 17:18:47 / `combat_episodes_v2.json` 17:00:53 / `864-review-v2.srt` 17:20:12 / `864-review-v2.stats.json` 17:20:12 / `srt_crosscheck_v2.json` 17:20:12 / `v2_validate.json` 17:10:44 / `qa_v2.json` 17:24:02 / `864-review-v2.decode.log` 17:22:36 / `preview_media_filters_v2.log` 17:23:56 / `cache\v2segs\vseg016.mp4` 17:18:42）→ **冻结完整性成立**。

---

STATUS_C: PASS
STATUS_D: PASS
