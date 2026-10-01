# 任务 21 / 素材 864 · v3 独立验收报告 · 角色 C（预览与字幕验收员）

- 作业书：`C:\Project\永劫无间\123\21.864永劫无间 2026-09-30 02-57-13\reports\acceptance_brief_v3.md`
- 本报告：`C:\Project\永劫无间\123\21.864永劫无间 2026-09-30 02-57-13\reports\acceptC_864_v3.md`
- 独立性声明：本人**未参与 v3 任何执行**（未渲预览、未做字幕、未做扫描、未做对抗审）。全程只读既有产物，**看图 0 张**（未抽帧、未读帧、未开联系表）。全部数字由本人当场重算，未采信任何他人报告结论。
- 工具：FFmpeg/FFprobe `n8.0-23-gd1f31a829d-20251022`（`C:\Project\永劫无间\.video-tools\LosslessCut\resources\`）；Python `C:\Project\永劫无间\.video-tools\venv\Scripts\python.exe`。未安装/升级任何包。
- 写入范围：仅本报告 + `TASK\cache\_acceptC_v3*` 临时件。**未改** `timeline\`、`preview\`、`captions\`、`reports\` 下任何既有文件；未动 B/D 的产物；未重渲；未跑 4K；未写出 TASK 以外任何路径。
- 自算凭据落盘位置（供复验）：`TASK\cache\_acceptC_v3_probe.json`（我的 ffprobe）、`_acceptC_v3_srcprobe.json`（源 ffprobe）、`_acceptC_v3_substreams.json`（`-select_streams s`）、`_acceptC_v3_decode.err.txt` / `_acceptC_v3_decode.code.txt`（我的解码）、`_acceptC_v3_filt_pass1/2.err.txt` + `_acceptC_v3_filt_pass3.raw.txt`（我的三遍媒体滤镜）、`_acceptC_v3_srcregion.err.txt`（源侧归因实测）、`_acceptC_v3_c5.py` + `_acceptC_v3_result.json`（字幕/台账复算）、`_acceptC_v3_attrib.py` + `_acceptC_v3_attrib.json`（滤镜日志逐字符对账 + 归因）。

---

## C1 · 存在性 + 体积 / 自证非 4K / 自证 CFR —— **PASS**

我的实测值来源：本人现跑 `ffprobe -v error -show_streams -show_format -print_format json -i <preview>`，落盘 `TASK\cache\_acceptC_v3_probe.json`，绝对路径 `C:\Project\永劫无间\123\21.864永劫无间 2026-09-30 02-57-13\cache\_acceptC_v3_probe.json`。

| 对象 | 字段 | 我的实测值 |
|---|---|---|
| 容器 | `format.duration` | **580.304333** |
| 容器 | `format.size` | **773,215,557** B |
| 容器 | `format.bit_rate` | **10,659,449** |
| 容器 | `format.nb_streams` | **2** |
| 视频 | `codec_name` / `profile` | **h264 / High** |
| 视频 | `width`×`height` | **1280×720** |
| 视频 | `pix_fmt` | **yuv420p** |
| 视频 | `r_frame_rate` / `avg_frame_rate` | **60/1 / 60/1** |
| 视频 | `time_base` / `duration_ts` | **1/60000 / 34,817,000** |
| 视频 | `nb_frames` | **34,817** |
| 视频 | `duration` | **580.283333** |
| 视频 | `bit_rate` | **10,487,068** |
| 音频 | `codec_name` / `profile` | **aac / LC** |
| 音频 | `sample_rate` / `channels` / `channel_layout` | **48000 / 2 / stereo** |
| 音频 | `nb_frames` / `duration` / `bit_rate` | **27,212 / 580.298667 / 160,138** |

**自证不是 4K（精确 1/3）**：本人另跑 `ffprobe` 于只读源，落盘 `TASK\cache\_acceptC_v3_srcprobe.json` —— 源 `E:\PR导出\864永劫无间 2026-09-30 02-57-13.mp4` 视频流 `width`×`height` = **3840×2160**，`format.duration` = 1152.233333，`size` = 2,984,729,760。
`3840 ÷ 1280 = 3.0`、`2160 ÷ 720 = 3.0`，**两侧均为精确整除的 3**，即预览相对源是精确 1/3 线性缩放，不存在上采样或裁切伪装。→ PASS

**自证 CFR**：
1. `r_frame_rate == avg_frame_rate == "60/1"`（整数相等，非 `120000/2000` 之类约数）→ PASS
2. `nb_frames ÷ 60 = 34817 / 60 = 580.2833333…`；视频流 `duration = 580.283333` —— **六位小数完全相等** → PASS
3. 独立旁证：`program_map_v3.json` 的 20 个 `cuts[].rendered_frames` 求和 = **34,817**，与 `ffprobe nb_frames` **完全相等**（逐段 `-frames:v` 取整后无累计漂移）→ PASS
4. `duration_ts ÷ time_base = 34,817,000 / 60,000 = 580.283333…`，与 `duration` 自洽 → PASS

**判定：PASS**

---

## C2 · 解码 + 媒体滤镜复跑 + 黑屏/冻结/静音全归因 —— **PASS**

### 2.1 解码

本人现跑：
```
C:\Project\永劫无间\.video-tools\LosslessCut\resources\ffmpeg.exe -v error -xerror ^
  -i "C:\Project\永劫无间\123\21.864永劫无间 2026-09-30 02-57-13\preview\864-review-v3.mp4" -f null -
```

| 项 | 我的实测值 | 归档件 | 一致 |
|---|---|---|---|
| 退出码 | **0** | — | — |
| stderr 字节数 | **0** | — | — |
| stderr 行数 | **0** | — | — |
| `preview\864-review-v3.decode.log` | — | **0 字节 / 0 行** | ✔ |

`-xerror` 开启且退出码 0、stderr 全空 ⇒ **零解码错误、零告警**。归档 decode.log 与我的实测**完全一致**。→ PASS

### 2.2 三个滤镜 + ebur128 逐字符对账

本人按 `reports\preview_media_filters_v3.log` 头部声明的参数原样复跑（脚本见 `TASK\cache\_acceptC_v3_attrib.py`，命令参数：`-vf blackdetect=d=0.5:pix_th=0.10`、`-af silencedetect=n=-45dB:d=1.5`、`-vf freezedetect=n=-60dB:d=1.0`、`-filter_complex ebur128=peak=true`，四遍退出码均 **0**）。

| 滤镜 | 归档行数 | 我的行数 | 逐字符一致 |
|---|---|---|---|
| `blackdetect` | 1 | 1 | **是** |
| `freezedetect` | 3 | 3 | **是** |
| `silencedetect` | 2 | 2 | **是** |
| `ebur128` 逐帧 `TARGET:-23 LUFS` 行 | 3 | 5805（归档取末 3） | **归档 3 行 == 我末 3 行，是** |
| `ebur128` Summary 8 个数值 | 8 | 8 | **是** |

对账口径（**必须声明，否则"逐字符"不成立**）：ffmpeg 每行前缀 `[<滤镜名> @ 0x…]` 里那个十六进制堆指针**每次运行都不同**，是设计上非确定的。我只把 `@ <hex>` 这一个 token 归一为 `@ @`，**其余每一个字符（含所有数字、空格、竖线、冒号）逐字符比对，全部命中**。归档 `ebur128` 段的 3 行逐帧数据与我末 3 行在归一后**逐字符相等**；Summary 8 个数值 `I: -17.7 LUFS` / `Threshold: -28.3 LUFS` / `LRA: 9.6 LU` / `Threshold: -38.3 LUFS` / `LRA low: -24.2 LUFS` / `LRA high: -14.5 LUFS` / `True peak:` / `Peak: -0.2 dBFS` 全部相同。归档文件另省略了 ffmpeg 的两个小节标题行与 `out#0` 尾行（见 W6，格式化裁剪，非数据差异）。

归档日志**零遗漏**：`freezedetect` 的 `start/duration/end` 三行齐全，**没有**"检测到冻结但无 end"的截断行（该截断行正是我在源侧 `-t 15` 短窗里见到的，见下方阳性对照）。→ PASS

### 2.3 黑屏 / 冻结 / 静音归因（**全量四条判据逐条证明**）

换算公式按作业书：`S = cut.source_start + (P − cut.program_start)`，切口表取 `TASK\timeline\program_map_v3.json`（20 个切口）。三处命中全部落在 **`combat_011`**。

#### 命中 A —— `black 563.921 → 565.821`（节目秒）

| 判据 | 我的实测值 | 结论 |
|---|---|---|
| 所属切口 | `combat_011#0` / `vseg019.mp4`；节目窗 [521.03, 568.78]；源窗 [1053.0, 1100.75] | — |
| 换算回源 | **S = 1095.891 → 1097.791** | — |
| **(a) 离所有切口边界足够远** | 距本切口源尾 1100.75 = **2.959 s（≈177 帧 @60fps）**；距下一切口 `vseg020` 源头 1115.97 = 18.179 s；距程序时钟最近切口边界 = **2.959 s**；距本切口源头 = 42.891 s | ✔ 足够远 |
| **(b) 不在任何 `deleted_intervals` 内** | 程序化枚举 11 条删除段，与 [1095.891, 1097.791] 求交 = **[]**（最近的是 [1037.0,1053.0) 与 [1127.45,1152.233)） | ✔ |
| **(c) 不在任何 `excluded_inside` 内** | 枚举 10 处洞，与该区间求交 = **[]**（`combat_011` 唯一洞 [1100.75,1115.97) loading_screen 不覆盖） | ✔ |
| **(d) 被该场 `boundary_reason` 明文要求保留** | `combat_episodes_v3.json` → `combat_episodes[10].boundary_reason` 原文：**"绝不能切在「打完 → 黑屏/结算前」：1096.0–1097.8 黑屏结算过场、1097.8–1100.8 队伍战绩展示（含返回大厅/分享）、1098 三角色 3D 列队过场、1099–1100 分数卡全部保留在段内。"** —— 声明区间 1096.0–1097.8 与实测 1095.891–1097.791 相互覆盖；关键字命中 `黑屏`✔ `结算`✔ `全部保留`✔。`notes` 另记 "1097 等待黑屏" | ✔ **明文要求保留** |

**决定性独立佐证（本人现跑，只读源）**：
`ffmpeg -ss 1090 -t 15 -i <SRC> -vf blackdetect=d=0.5:pix_th=0.10 -an -f null -` → `black_start:5.85 black_end:7.75 black_duration:1.9`
换算源绝对秒 = **1095.85 → 1097.75**，与我经节目坐标反推的 **1095.891 → 1097.791** 相比 **起点差 0.041 s、终点差 0.041 s**（0.041 s ≈ 2.5 帧 @60fps，属 720p 重编码取整与检测器量化容差）。
⇒ **该黑屏在源片里本就存在于同一位置，不是渲染/切口造出来的**。

#### 命中 B —— `freeze 563.921 → 565.087667`（节目秒）

| 判据 | 我的实测值 | 结论 |
|---|---|---|
| 所属切口 | `combat_011#0` / `vseg019.mp4`（同 A） | — |
| 换算回源 | **S = 1095.891 → 1097.057667** | — |
| **(a)** | 距本切口源尾 = **3.692333 s（≈222 帧）**；程序时钟最近切口边界 = 3.692333 s；距源头 = 42.891 s | ✔ 足够远 |
| **(b)** | 与 11 条 `deleted_intervals` 求交 = **[]** | ✔ |
| **(c)** | 与 10 处 `excluded_inside` 求交 = **[]** | ✔ |
| **(d)** | 同 A：`boundary_reason` 明文 **"1096.0–1097.8 黑屏结算过场 … 全部保留在段内"** | ✔ **明文要求保留** |

**独立佐证**：`ffmpeg -ss 1090 -t 15 -i <SRC> -vf freezedetect=n=-60dB:d=1.0 -an -f null -` → `freeze_start:5.85 freeze_duration:1.7 freeze_end:7.55` ⇒ 源绝对秒 **1095.85 → 1097.55**，起点差 **0.041 s**。⇒ 源片同一位置本就冻结；预览测得的 1.166667 s 略短于源的 1.7 s，是 720p 重编码引入的细微噪声使冻结提前结束，**方向上更保守、不构成新问题**。

#### 命中 C —— `silence 568.814375 → 574.621104`（节目秒）

| 判据 | 我的实测值 | 结论 |
|---|---|---|
| 所属切口 | `combat_011#1` / `vseg020.mp4`；节目窗 [568.78, 580.26]；源窗 [1115.97, 1127.45] | — |
| 换算回源 | **S = 1116.004375 → 1121.811104** | — |
| **(a) 离所有切口边界足够远** | 距本切口源头 1115.97 = **0.034375 s（≈2.06 帧 @60fps）** ← **本项最弱，单独登记为 W2**；距本切口源尾 1127.45 = 5.638896 s；距上一切口源尾 1100.75 = 15.254375 s | ⚠ **边缘（见 W2 判定：非缺陷）** |
| **(b) 不在任何 `deleted_intervals` 内** | 与 11 条求交 = **[]** | ✔ |
| **(c) 不在任何 `excluded_inside` 内** | 与 10 处洞求交 = **[]**。`combat_011` 唯一洞 [1100.75, **1115.97**) 的右端**恰在命中起点前 0.034 s 收口**，命中整体落在洞**外** | ✔（余量小但确在洞外） |
| **(d) 被该场 `boundary_reason` 明文要求保留** | `boundary_reason` 原文含 **"结算三屏完整保留在后"**、**"战报名次屏（第 3/8 名，1115.97–1121.7）"**、**"段位加分屏（1121.7–1123.8，破境 4 段 + 2967）"**、**"熟练屏（1123.8–1127.4，171 级）"**；关键字命中 `战报`✔ `结算`✔ `1115.97`✔ `1121.7`✔ `加载`✔。另 `excluded_inside[0].reason` 自记 "1110–1120 网格 db_mean=-115.5" | ✔ **明文要求保留** |

**决定性独立佐证（本人现跑，只读源）**：
`ffmpeg -ss 1110 -t 22 -i <SRC> -vn -af silencedetect=n=-45dB:d=1.5 -f null -` → `silence_start: 0` / `silence_end: 11.769792 | silence_duration: 11.769792`
即 **源片自 ≤1110.0 起就是一段连续静音，直到源 1121.769792 才结束**。换算我经节目坐标反推的静音终点 1121.811104 与之**只差 0.041312 s**。
⇒ **整个被保留的尾窗 `vseg020` 源区间 [1115.97, 1121.77) 在源录音里本来就是静音**（战报名次屏是静态结算画面，无人声）。0.034375 s 这个"贴边"数字是**拼接点上音频帧的量化粒度**（`silencedetect` 在被剪掉 15.22 s 静音洞后于新流首帧重新起算），**不是静音成因靠近切口**。静音的**成因**完全在源侧，与切口位置无关。

#### 阳性对照（证明挖洞真的生效了，反向验证归因方法可靠）

同一次源侧跑批还量到：
- 源 `blackdetect` 第二段 `black_start:10.75 black_end:14.983333` ⇒ 源绝对 **1100.75 → 1104.983333**
- 源 `freezedetect` 第二段 `freeze_start:11.616667` ⇒ 源绝对 **1101.616667**（后续被 `-t 15` 截断）

这两处**都落在 `combat_011` 的 `excluded_inside` 洞 [1100.75, 1115.97) 内**（加载屏黑场）。而**预览里黑屏只有 1 处、冻结只有 1 处**（见 2.2 表），**这两处源黑/源冻结在成片中完全没有出现**。
⇒ 洞 `[1100.75, 1115.97)` 确实把加载屏黑闪/冻结吃干净了；而剩下的那 1 处黑/1 处冻结/1 处静音**全部来自被 `boundary_reason` 明文要求保留的保留段**。归因闭合，无遗留未解释命中。

**判定：PASS**（命中 C 的 (a) 项以 W2 形式单独登记，理由与直接源侧实测见上）

---

## C3 · 时长对照 —— **PASS**

| 对照 | 我的实测值 | 差值 | 门槛 | 结论 |
|---|---|---|---|---|
| 容器 `format.duration` | **580.304333** | — | — | — |
| `program_map_v3.json` → `program_seconds_total` | **580.26** | **+0.044333 s** | ±0.3 s | ✔ |
| `combat_episodes_v3.json` → `program_seconds_total` | **580.26** | +0.044333 s | ±0.3 s | ✔ |
| `864-review-v3.stats.json` → `program_seconds_total` | **580.26** | +0.044333 s | ±0.3 s | ✔ |
| **本人自加总 20 个 `cuts[].source_duration`** | **580.26**（精确相等） | 0 | — | ✔ |
| 本人自加总 20 个 `cuts[].program_duration` | **580.26** | 0 | — | ✔ |
| 末切口 `program_end` | **580.26** | 0 | — | ✔ |
| 视频流 `duration` = **580.283333** | vs 音频流 `duration` = **580.298667** | **0.015334 s** | — | ✔（1.5 万分之一帧级，远低于 0.2 s 音画同步门槛；与 `qa_v3.json` 的 `av_sync measured 0.015` 相符） |

**附：坐标系自洽的独立重建（超出 C3 但支撑 C3/C5）**
本人不依赖 `program_map_v3.json`，直接从 `combat_episodes_v3.json` 的 `source_start/source_end/excluded_inside` 逐场**自行切出保留窗**并累加节目游标，得 **20 个窗口**；再 `import episode_geometry` 独立跑 `episode_segments()` 得另一组 20 个窗口。两者 **20/20 逐字段（`episode_id`/`source_start`/`source_end`/`program_start`/`program_end`）完全相等**；再与 `program_map_v3.json` 的 20 个 `cuts[]` 比对，**20/20 完全相等**。⇒ 节目时钟与源时钟的换算在我这一路是零误差的，上表 580.26 的三方一致性因此可信。

**判定：PASS**

---

## C4 · 画面污染 + 字幕流 —— **PASS**

| 子项 | 我的实测值 | 绝对路径 / 字段 | 结论 |
|---|---|---|---|
| 字幕流（本人现跑 `ffprobe -select_streams s -show_streams -print_format json`） | **`"streams": []`（空数组，0 个字幕流）** | 证据 `TASK\cache\_acceptC_v3_substreams.json`；被测 `preview\864-review-v3.mp4` | ✔ |
| 全部流类型 | `format.nb_streams = 2`，仅 `h264`（video）+ `aac`（audio） | `TASK\cache\_acceptC_v3_probe.json` | ✔ 无 `subtitle`/`data`/`attachment` |
| 附带独立证据 | 我 `ebur128` 复跑的 `out#0` 尾行含 **`subtitle:0KiB other streams:0KiB`** | `TASK\cache\_acceptC_v3_filt_pass3.raw.txt` | ✔ |
| 全 TASK 程序化扫 `.srt/.ass/.ssa/.vtt/.sub/.idx` | 命中 **3 个文件，全部是 `.srt`，全部在 `captions\`**（`864-review-v1.srt` / `-v2.srt` / `-v3.srt`）；**`.ass`=0、`.ssa`=0、`.vtt`=0、`.sub`=0、`.idx`=0**；`captions\` 之外 **0 个** | 扫描根 `C:\Project\永劫无间\123\21.864永劫无间 2026-09-30 02-57-13\`（`rglob`），见 `TASK\cache\_acceptC_v3_c5.py` | ✔ |
| 门禁字段核对 | `reports\qa_v3.json` → `checks[].name = "no_subtitle_stream"`：`result="PASS"`, `measured=0`, `threshold="0 subtitle streams"`；节目坐标视图 `qa_v3_programbounds.json` 同项亦 `PASS / 0` | — | ✔ 与我的实测一致 |
| 渲染脚本零 burn 滤镜（扫 `TASK\cache\*.py`） | 扫 **11 个** `cache\*.py`，正则 `drawtext\|subtitles=\|overlay=\|(?<![A-Za-z0-9_])ass=\|=-s:s` → **命中 0** | — | ✔ |
| 追加扫全 TASK `.py`（`cache\` 之外） | **命中 0** | — | ✔ |
| 渲染脚本滤镜图实读 | `cache\render_preview.py` 全文里 **唯一** 的视频滤镜是第 107 行 `"-vf", f"scale={args.width}:{args.height}:flags=lanczos,fps={args.fps}"`；**无 `-af`**、无 `filter_complex` 视频链、无 `drawtext/subtitles/ass/overlay`。输入只有第 105 行 `"-i", args.source`（单一来源 = `--source`）；第 106 行 `"-map", "0:v:0", "-map", "0:a:0"`（只取源音视频）；第 112–113 行 `-c:a aac -b:a 160k -ar 48000 -ac 2`（源音频直通，**无 BGM 混入**）；拼接遍第 126–128 行 `-f concat -i concat.txt -c copy`（**流拷贝，不再上滤镜**） | `C:\Project\永劫无间\123\21.864永劫无间 2026-09-30 02-57-13\cache\render_preview.py` | ✔ |
| 烧录变体 | `TASK` 内不存在任何 `master`/`3840`/`final`/`cujian` 命名的 mp4（成片阶段未启动，字幕只能外挂） | — | ✔ |

**判定：PASS**

---

## C5 · 外挂字幕（40 条）—— **PASS**

被验件：`C:\Project\永劫无间\123\21.864永劫无间 2026-09-30 02-57-13\captions\864-review-v3.srt`
本人复算脚本 `TASK\cache\_acceptC_v3_c5.py`，结果落盘 `TASK\cache\_acceptC_v3_result.json`。解析得 **40 条**，编号 1…40 连续、起点严格单调、全部 `end > start`。

**① 不跨切口 —— 0 例**
判据：把每条 cue 的 `[start, end]` 定位进 20 个 `cuts[]` 的节目窗，归属窗口数必须恰为 1，且不得有任何切口边界 `program_start/program_end` 严格落在 cue 内部。
我的实测：**40/40 条各自完整落在单一 `cuts[]` 窗内；跨切口 0 条；内部含切口边界 0 条**。
最靠近切口的两条（仍完全在窗内）：cue 8 `P 120.76–124.59` 距 `vseg004.program_start=120.5` **0.26 s**（源 357.26）；cue 17 `P 167.58–170.61` 距 `vseg005.program_start=167.5` **0.08 s**（源 417.07）。→ ✔

**② 无重叠 —— 0 例**
39 个相邻间隙逐个枚举：**重叠 0 例**。最小观测间隙 = **0.12 s**，恰等于 `864-review-v3.stats.json.thresholds.min_gap_seconds = 0.12`；按 0.12 门槛（而非交叉核对脚本里写死的 0.08，见 W3）**违规 0 例**。→ ✔

**③ 起止在节目 `[0, duration]` 内 —— 0 例越界**
最早起点 **25.94 s**，最晚终点 **577.60 s**。容器 `format.duration = 580.304333`；`program_map_v3.json` 末切口 `program_end = 580.26`。越界 0 条，超出节目总长 0 条。→ ✔

**④ 文本与 `source_transcript.json` 对得上 —— 40/40 精确相符**
做法：把每条 cue 的节目区间用**本次自建的 20 窗口**反算回源区间 `S0/S1`，在 `captions\source_transcript.json`（180 segments，zh，duration 1152.2346875）中取与 `[S0,S1]` 有重叠的 segment，文本去空白后逐字比对。
我的实测：**40/40 条 cue 文本与某个源 segment 文本逐字完全一致**；**文本不符 0 条**；**找不到对应源 segment 的 0 条**。
附带门槛复核：cue 时长全部落在 `[min_cue_seconds 0.8, max_cue_seconds 7.0]` 内（**违规 0**）；中文字幕 cps 全部 ≤ `max_cps_zh 12.0`（**违规 0**）。→ ✔

**⑤ 统计台账可复算 —— 8 个数字全部独立复现**
本人**不看 `.stats.json` 的结论**，只取它公开的门槛值（`min_avg_logprob=-0.6`、`max_no_speech_prob=0.4`、`max_source_cue_seconds=7.0`），拿 `source_transcript.json` 的 180 条 + 自建的 20 个保留窗**从头重跑分类**：

| 分类 | 我的实测 | `.stats.json` 声明 | 相等 |
|---|---|---|---|
| kept | **40** | `count` = 40 | ✔ |
| dropped_empty | **0** | 0 | ✔ |
| dropped_low_confidence | **12** | 12 | ✔ |
| dropped_hallucination_loop | **10** | 10 | ✔ |
| dropped_filler_or_short | **10** | 10 | ✔ |
| dropped_cps_or_too_short | **0** | 0 | ✔ |
| **72 = 40+0+12+10+10+0** | **72** ✔ 闭合 | `source_segments_inside_retained_windows` = 72 | ✔ |
| split_at_cut | **22** | `split_at_cut` = 22 | ✔ |
| outside_retained_windows | **86** | 86 | ✔ |
| **180 = 72+22+86** | **180** ✔ 闭合 | `source_segments` = 180 | ✔ |
| source_segments_total | **180** | 180 | ✔ |

**与 `reports\srt_crosscheck_v3.json` 对账（5 项全中）**：

| 字段 | 归档值 | 我的实测 | 一致 |
|---|---|---|---|
| `cue_count` | 40 | 40 | ✔ |
| `cut_count` | 20 | 20 | ✔ |
| `cross_cut_spans` | 0 | 0 | ✔ |
| `overlaps` | 0 | 0 | ✔ |
| `timing_problems` | 0 | 0（时长 0 + cps 0） | ✔ |
| `gap_problems` | 0 | 0（按 0.12 严格门槛） | ✔ |
| `problems` | `[]` | `[]` | ✔ |
| `pass` | true | true | ✔ |
| `stats_declared_count` / `stats_match` | 40 / true | 40 / true | ✔ |

**与门禁对账**：`reports\qa_v3_programbounds.json`（节目坐标视图，配 `--srt` 跑出）→ `subtitle_span` **PASS / measured="40 cues"**、`subtitle_stats` **PASS / measured=40**、`no_subtitle_stream` **PASS / 0**。与我的 40 条零跨切口零重叠结论完全一致。`reports\qa_v3.json`（源坐标、`--no-srt`）同两项为 WARN，属作业书第 30 行预先登记的 `qa_gate.subtitle_span` 单位错配，**不计为 v3 缺陷**（见 W4）。

**判定：PASS**

---

## `reports\preview_probe_v3.json` 是否过期快照 —— **不是过期**（v2 时的老问题在 v3 未复现，单独结论）

| 判据 | 我的实测值 | 结论 |
|---|---|---|
| 文件 mtime 先后 | 预览 `preview\864-review-v3.mp4` = **2026-09-30 10:56:10 UTC**；`preview_probe_v3.json` = **10:56:11 UTC**（晚 1 秒） | 快照在预览之后生成 ✔ |
| 内容复现 | 本人**当场重跑 ffprobe**，与归档件做**叶字段级递归比对：共 117 个叶字段，116 个逐字节相同** | ✔ |
| 唯一差异 | `format.filename` 一项。**成因是我这一侧的采集假象**（PowerShell 5.1 按 OEM 代码页解码 ffprobe 原生 stdout，把中文路径读成 GBK 乱码），**不是归档件的错** —— 逐码点验证：归档件 `C:\Project\` 之后是 `0x6C38 0x52AB 0x65E0 0x95F4`（永劫无间，正确）；我的采集件是 `0x7A3F 0x59ED 0x93C3 0x72BB 0x68FF`（乱码） | ✔ |
| 结论 | **v3 的 `preview_probe_v3.json` 不是过期快照，无需登记 WARN。** | — |

（作为对照：`reports\preview_probe_v2.json` 我未打开比对，因为 C 角色的职责只覆盖 v3 冻结件；作业书提到的"v2 时它曾过期"是历史线索，按纪律不作结论依据。）

---

## WARN 清单（**均不影响 PASS/FAIL 判定**）

**W1 · 角色 C 的唯一采集假象，非产物缺陷（已自证）**
`ffprobe` 输出经 PowerShell 5.1 管道回传时中文路径被按 OEM 代码页解码成乱码（`姘稿姭鏃犻棿`）。本人所有落盘文本证据均用 `[IO.File]::WriteAllText(..., UTF8Encoding($false))` 写出，但**源字符串本身已被污染**。已逐码点举证归档 `preview_probe_v3.json` 的路径是**正确的**，差异只存在于我的临时采集件 `cache\_acceptC_v3_probe.json`。凡本报告引用的**数字**字段均不受影响（ffprobe 数字输出为纯 ASCII）。

**W2 · `silence 568.814375` 距本切口边界仅 0.034375 s（≈2 帧）—— 登记为边缘，但**判定为非缺陷****
这是 C2 判据 (a) 上最弱的一处，按作业书要求单列。**判非缺陷的直接依据**：本人现跑源侧 `silencedetect -ss 1110 -t 22` 得 `silence_start:0 → silence_end:11.769792`，即**源片自 1110 之前直到 1121.7698 就是一段连续静音**；被保留的 `vseg020` 源窗 [1115.97, 1127.45) 的前 5.80 s（1115.97–1121.77）**在源录音里本来就全是静音**（战报名次屏是静态结算画面）。0.034375 s 是拼接点上音频帧量化粒度（洞挖掉 15.22 s 静音后 `silencedetect` 在新流首帧重新起算），**静音成因与切口位置无关**。且 `boundary_reason` 明文要求保留"战报名次屏（第 3/8 名，1115.97–1121.7）"。若日后要求静音成因也远离切口，唯一手段是把尾窗起点后移，那会牺牲 `boundary_reason` 明文指定的结算三屏起点，属取舍而非缺陷。

**W3 ·【新发现，工具侧潜在漏洞，不影响 v3 判定】`cache\srt_crosscheck.py` 的间隙门槛与字幕台账声明不一致**
`C:\Project\永劫无间\123\21.864永劫无间 2026-09-30 02-57-13\cache\srt_crosscheck.py` 第 21 行**写死** `MIN_DUR, MAX_DUR, MIN_GAP, MAX_CPS_ZH = 0.8, 7.0, **0.08**, 12.0`，而 `captions\864-review-v3.stats.json` 的 `thresholds.min_gap_seconds = **0.12**`，且 `cache\build_program_srt.py` 第 25 行 `GAP = 0.12` 才是真正执行的门槛。
后果：`srt_crosscheck_v3.json` 的 `gap_problems` 会**放行 [0.08, 0.12) 区间的间隙**，即它比字幕自己的规格宽松一档。**本次未掩盖任何东西** —— 本人按 0.12 独立重算，违规 0 例、最小观测间隙恰为 0.12。
建议：把 `srt_crosscheck.py` 的 `MIN_GAP` 改为从 `.stats.json` 的 `thresholds.min_gap_seconds` 读取（与它已经读取 `stats_declared_count` 的做法一致），消除双份门槛来源。

**W4 · `qa_v3.json`（源坐标）`subtitle_span`/`subtitle_stats` 为 WARN "no srt"**
作业书第 30 行已预先登记为 `qa_gate.subtitle_span` 的单位错配（拿节目时钟字幕比源时钟区间）。节目坐标视图 `qa_v3_programbounds.json` 两项均 PASS。**按作业书要求不计为 v3 缺陷。**

**W5 · `qa_v3.json` / `qa_v3_programbounds.json` 的 `no_burned_variant` = WARN "no master"、`media_filters` = WARN**
前者是"无成片可比对"的占位 WARN（本阶段只出 720p 审片预览，无 master）；后者指向 C2 已完整归因的三处命中。均为本阶段预期状态。

**W6 · `preview_media_filters_v3.log` 的 ebur128 段是裁剪摘录**
归档件只保留 5805 条逐帧 `TARGET:-23 LUFS` 行中的**末 3 条**，并省略 ffmpeg 的两个小节标题行（`Integrated loudness:` / `Loudness range:`）与 `out#0` 尾行。**所有保留下来的内容与我复跑的逐字符相同**（W6 属格式化裁剪，非数据差异）。同时必须声明：`blackdetect`/`freezedetect`/`silencedetect`/`ebur128` 的每行都带 `@ 0x…` 非确定堆指针，**"逐字符对账"在本作业书口径下必须先归一该单一 token**，否则任何两次运行都不可能字节相等 —— 此为 ffmpeg 输出格式的固有限制，非日志质量问题。

---

## 新发现的问题（汇总）

1. **W3（唯一有实质影响的新发现）**：`cache\srt_crosscheck.py` 第 21 行 `MIN_GAP = 0.08` 与 `864-review-v3.stats.json` 的 `thresholds.min_gap_seconds = 0.12` / `build_program_srt.py` 的 `GAP = 0.12` 不一致 ⇒ 交叉核对门禁比字幕自身规格**宽松一档**，会放行 [0.08, 0.12) 的间隙。本次**未造成任何实际漏放**（0.12 严格门槛下违规 0 例）。
2. **W2（新观察，已判非缺陷）**：`silence 568.814375` 距 `vseg020.program_start = 568.78` 仅 0.034375 s，是 C2 判据 (a) 上唯一不宽裕的一处；已用源侧 `silencedetect` 直接实测证明静音成因在源片本身（源 1110–1121.77 连续静音），非切口造出。
3. **W1**：我方采集管道的代码页假象（已自证并排除，产物无问题）。
4. **W4/W5/W6**：预登记工具缺陷 / 本阶段预期 WARN / 日志格式化裁剪，均非 v3 缺陷。

**无 FAIL 项。**

---

STATUS: PASS
