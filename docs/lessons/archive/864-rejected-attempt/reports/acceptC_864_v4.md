# 任务 21 / 素材 864 · v4 独立验收报告 · 角色 C（预览与字幕验收员）

> 声明：本角色**未参与 v4 任何执行**（未渲预览、未做字幕、未做扫描/对抗审/裁决）。
> 全程只读既有文件，**看图 0 张**（未抽帧、未打开任何 `.jpg`，只用 ffprobe/ffmpeg 滤镜的数值与文本输出）。
> 本轮唯一交付物：`reports\acceptC_864_v4.md`。临时脚本与中间件全部落在 `TASK\cache\`，文件名带 `_acceptC_v4` 前缀，
> 未新建任何 `.ps1`（因此不涉及 BOM/纯 ASCII 问题），未写出 TASK 以外任何路径，未改动 `timeline\`、`preview\`、`captions\` 下任何既有文件，未碰 v1/v2/v3。

TASK = `C:\Project\永劫无间\123\21.864永劫无间 2026-09-30 02-57-13`
SRC（只读）= `E:\PR导出\864永劫无间 2026-09-30 02-57-13.mp4`
FFmpeg/FFprobe = `C:\Project\永劫无间\.video-tools\LosslessCut\resources\`（ffprobe.exe 225,280 B / ffmpeg.exe 527,360 B）
Python = `C:\Project\永劫无间\.video-tools\venv\Scripts\python.exe`（仅用于 JSON 复算与调用 ffprobe/ffmpeg）

---

## 结论速览

| 项 | 判定 | 一句话 |
|---|---|---|
| **C1 存在性 + 体积 + 自证非 4K + 自证 CFR** | **PASS** | 751,095,441 B / 563.021 s / 1280×720 / 33780 帧 / 2 流，21 位 PTS 等差网格自证 CFR |
| **C2 解码 + 滤镜复跑 + 归因四问 + blackdetect 判定** | **FAIL** | 解码干净、归因四问全过；但**存档滤镜日志的 blackdetect 段是空的**（同参数实跑命中 1.9 s），「零命中」为不实陈述 |
| **C3 时长对照** | **PASS** | 容器 563.021 vs 562.97，差 0.051 s ≤ 0.3 |
| **C4 画面污染 + 字幕流/字幕文件/烧录滤镜** | **PASS** | `-select_streams s/t/d` 全部 `[]`，字幕包 0；全 TASK 仅 4 个版本化 `.srt`；`render_preview.py` 零烧录 |
| **C5 外挂字幕 38 条 + 台账 + MIN_GAP 同步** | **PASS** | 38/38 文本与转写逐字对上；跨切口 0 / 重叠 0 / 越界 0；`68=38+0+11+9+10+0`、`180=68+24+88` 复算通过；`MIN_GAP` 0.12 与 `.stats.json` 一致 |

STATUS: FAIL

FAIL 的唯一来源是 **C2 的证据链**：作业书列出的冻结件
`reports\preview_media_filters_v4.log` 声明 `blackdetect` 零命中，
而我用**它自己写的参数**复跑 3 次都命中 `black_duration:1.9`。
**这不是「预览坏了」——预览媒体本身解码 0 错误、时长/帧数/CFR/分辨率全部合规；
坏的是那份被当作 QA 依据的证据记录，以及随之写进作业书的「零命中」声明。**

---

## C1 · 存在性 + 体积 + 自证非 4K + 自证 CFR —— PASS

### C1.1 我的实测值

被测文件：`C:\Project\永劫无间\123\21.864永劫无间 2026-09-30 02-57-13\preview\864-review-v4.mp4`

| 项 | 我的实测值 | 取证命令 / 字段 |
|---|---|---|
| 字节数（`Get-Item`） | **751,095,441 B** | 与 ffprobe `format.size` 相等 |
| mtime | **2026-10-01 02:36:04** | `System.IO.FileInfo` |
| SHA-256 | `d3c7a4497c55444cf57974b38f9b44628b8a5304935ec4548aacd8a501faf417` | 全文件流式哈希 |
| `format.duration` | **563.021000** | `ffprobe -show_format` |
| `format.size` | **751095441** | 同上 |
| `format.bit_rate` | **10672361** | 同上；我复算 `751095441*8/563.021` = **10672361.3**，一致 |
| `format.nb_streams` | **2** | 同上（= 无字幕流的第一手证据） |

视频流：

| 字段 | 我的实测值 |
|---|---|
| `codec_name` / `profile` / `level` | `h264` / `High` / `32` |
| `width` × `height` | **1280 × 720** |
| `pix_fmt` / `field_order` | `yuv420p` / `progressive` |
| `r_frame_rate` / `avg_frame_rate` | **`60/1` / `60/1`** |
| `nb_frames` | **33780** |
| `time_base` | `1/60000` |
| `start_pts` / `start_time` | **1260** / `0.021000` |
| `duration_ts` / `duration` | **33780000** / `563.000000` |
| `bit_rate` | `10500113` |
| `tags.encoder` | `Lavc62.11.100 libx264` |

音频流：

| 字段 | 我的实测值 |
|---|---|
| `codec_name` / `profile` | `aac` / `LC` |
| `sample_rate` / `channels` / `channel_layout` | `48000` / `2` / `stereo` |
| `sample_fmt` | `fltp` |
| `nb_frames` | **26403** |
| `time_base` | `1/48000` |
| `start_pts` / `start_time` | 0 / `0.000000` |
| `duration_ts` / `duration` | 27024736 / `563.015333` |
| `bit_rate` | `160016` |

### C1.2 自证「不是 4K」

源 `E:\PR导出\864永劫无间 2026-09-30 02-57-13.mp4`：`3840 × 2160`，`h264 High`，`r_frame_rate=60/1`，`nb_frames=69134`，`format.duration=1152.233333`，`format.size=2984729760`。

- `3840 / 3 = 1280`，`2160 / 3 = 720` —— **精确 1/3**，程序化判定 `scale_exact_div_by_3 = true`。
- 预览 `width/height` 与源严格成 3 倍关系，**不是 4K，也不是 4K 放大**（成片若放大则会引入插值痕迹，本轮不涉）。

**PASS**

### C1.3 自证 CFR

作业书要求两条，我做满三条：

1. `r_frame_rate == avg_frame_rate == "60/1"`，且整数比 `(60,1) == (60,1)` 成立 → `r_eq_avg_and_integer_60 = true`。
2. `nb_frames ÷ 60 = 33780 / 60 = **563.000000**`，与视频流 `duration = 563.000000` **六位小数完全相等**（`frames_and_duration_agree = true`）。
3. **额外（比作业书更严）**：我把全部 33780 个视频包 PTS 取出排序，检查等差性 ——

   `n_unique_pts = 33780`，`distinct_deltas = [1000]`（**只有一个步长**），`first_pts = 1260`，`last_pts = 33780260`。

   `time_base = 1/60000`，步长 1000 tick = 1/60 s，33780 帧 × 1/60 = 563.000000 s。
   即 PTS 落在**单一严格等差网格**上，无重复、无跳变、无缺帧 —— 这是 CFR 的充分条件，`avg_frame_rate` 只是它的均值近似。
   （注：按解码序排列的原始 PTS 序列非单调，是 H.264 B 帧重排的正常现象 `has_b_frames=2`；排序后等差即证明恒定帧率。）

**PASS**

---

## C2 · 解码 + 媒体滤镜复跑 + 归因四问 + blackdetect 判定 —— **FAIL**

### C2.1 解码

我的命令（12.3 s 跑完）：

```
ffmpeg.exe -v error -xerror -nostats -i "...\preview\864-review-v4.mp4" -f null -
```

| 项 | 我的实测值 |
|---|---|
| 退出码 | **0** |
| stderr 字节 | **0** |
| stderr 非空行数 | **0** |

对账 `TASK\preview\864-review-v4.decode.log`：
- 文件大小 **0 B**；
- SHA-256 = `E3B0C44298FC1C149AFBF4C8996FB92427AE41E4649B934CA495991B7852B855`（空串的哈希）。

**完全对上**：decode.log 的 0 字节 ≡ 我的「退出码 0 + stderr 0 行」。这一项 **PASS**。

### C2.2 媒体滤镜复跑与存档日志对账

存档 `TASK\reports\preview_media_filters_v4.log`（986,335 B / 5,648 非空行）四个小节标题：

```
=== blackdetect d=0.5 pix_th=0.10 ===
=== freezedetect n=-60dB d=1.0 ===
=== silencedetect n=-45dB d=1.5 ===
=== ebur128 peak=true ===
```

| 小节 | 存档声明 | 我的独立复跑 | 对账 |
|---|---|---|---|
| `blackdetect d=0.5 pix_th=0.10` | **零命中**（该段 `black_` 行数 = **0**） | **命中 1 条**：`black_start:546.637667 black_end:548.537667 black_duration:1.9` | ❌ **不一致** |
| `freezedetect n=-60dB d=1.0` | `546.637667` / `1.166667` / `547.804333` | 完全相同三值 | ✅ |
| `silencedetect n=-45dB d=1.5` | `551.531042` / `557.337771` / `5.806729` | 完全相同三值 | ✅ |
| `ebur128 peak=true` | `I: -17.7 LUFS`、`LRA: 9.6 LU`、`Peak: -0.2 dBFS`，末帧 `t: 562.951312` | `I: -17.7 LUFS`、`LRA: 9.6 LU`、`Peak: -0.2 dBFS`，末帧 `t: 562.951312` | ✅ |

（行数 5,648 vs 我 5,685 的差额来自我这次带了 ffmpeg banner 与结尾 muxer 行；逐值对账全部一致，不看行数。）

`blackdetect` 小节对不上，就是 C2 判 FAIL 的唯一原因。下面把事实钉死。

### C2.3 blackdetect 本轮零命中 vs v3 的 1.9 s 黑屏：**两个前提都不成立**

作业书要我判断是「黑屏真的没了」还是「阈值未触发」。我的实测结论是**第三种，也是唯一与证据相符的一种**：

> **黑屏仍在（而且是被时间线明文要求保留的），阈值本来就会触发；是存档日志那一段把命中丢掉了。**

#### 证据 1 —— 同参数复跑，确定性命中（3/3）

```
ffmpeg.exe -v info -hide_banner -nostats -i 864-review-v4.mp4 -vf blackdetect=d=0.5:pix_th=0.10 -an -f null -
```

| 重复 | 退出码 | 命中 |
|---|---|---|
| run 0 | 0 | `black_start:546.637667 black_end:548.537667 black_duration:1.9` |
| run 1 | 0 | `black_start:546.637667 black_end:548.537667 black_duration:1.9` |
| run 2 | 0 | `black_start:546.637667 black_end:548.537667 black_duration:1.9` |

三次逐字节同值，**不是抖动、不是竞态**。

#### 证据 2 —— 零命中可以精确复现：机制是日志级别，不是画面

| 变体 | 结果 |
|---|---|
| `-v info -vf blackdetect=d=0.5:pix_th=0.10 -an` | 1 条命中 |
| `-v info -vf "blackdetect=...,freezedetect=..." -an`（链式） | 1 条命中 |
| `-v info -vf blackdetect=d=0.5:pix_th=0.10`（不过滤音频） | 1 条命中 |
| `-v info -vf blackdetect=d=0.5`（用默认 `pix_th`） | 1 条命中 |
| **`-v warning -vf blackdetect=d=0.5:pix_th=0.10 -an`** | **0 条命中 ← 与存档日志的小节完全同形** |

`blackdetect` 的命中是走 **`AV_LOG_INFO`** 打的。只要那一趟的 loglevel 低于 info（或视频通路被排除），
这一段就会**静默变空**，而命令退出码仍是 0 —— 于是「空 = 干净」被误读成事实。
存档日志的 blackdetect 段就是这个形态。

#### 证据 3 —— 更严的阈值同样命中（阈值不是瓶颈）

| 命令 | 命中 |
|---|---|
| `blackdetect=d=0.5:pix_th=0.10` | `546.637667 → 548.537667`（1.9 s） |
| **`blackdetect=d=0.1:pix_th=0.10`** | `546.637667 → 548.537667`（1.9 s） |
| `blackdetect=d=0.1:pix_th=0.30` | 3 条：`546.637667→548.537667` / `551.537667→551.804333` / `557.254333→557.704333` |
| `blackdetect=d=0.1:pix_th=0.50` | 4 条：`539.471→540.721` / `546.637667→548.571` / `548.737667→549.971` / `551.537667→557.754333` |

把 `d` 从 0.5 收紧到 0.1、把 `pix_th` 放宽到 0.30/0.50，**1.9 s 那一条一次都没消失**。
→ **不是「阈值未触发」。**

#### 证据 4 —— 逐帧亮度实测（纯数值，不看图）

`blackframe`（只吐文本）：

```
-vf blackframe=amount=98:threshold=25   -> 命中 114 帧，全部 pblack:99
   首帧 frame:32797 t:546.637667 pblack:99
-vf blackframe=amount=90:threshold=25   -> 同样 114 帧 pblack:99
-vf blackframe=amount=50:threshold=25   -> 同样 114 帧 pblack:99
```

114 帧 ÷ 60 = **1.900 s**，与 blackdetect 的 `black_duration:1.9` 分毫不差。
`pblack:99` = **99 % 的像素亮度 ≤ 25**（blackdetect 的判定口径就是 `≥98 %` 像素 ≤ `pix_th*255 = 25.5`）。

`signalstats`（全片 33780 帧 YAVG 文本流）：

- 全片最暗 10 帧 **全部**落在 `t = 546.637667 … 546.787667`，`YAVG ≈ 16.2649`；
- 全片 YAVG 最小值 **16.2649**（≈ 6.4 % 灰阶），全片均值 **89.812**，最亮 215.2；
- `YAVG < 16` 的帧数 = 0。

→ 这不是纯零黑屏（有几丝很暗的加载元素，均值 16.3），但**在 blackdetect 的定义下它就是黑屏**，而且**静止**（freezedetect 命中 546.637667→547.804333 = 70 帧 = 1.166667 s，是这 114 帧里的前 70 帧完全冻结，后 44 帧仍在变）。

#### 证据 5 —— 这段黑屏在 v4 里根本没被删，也没打算删

把 v3 的命中点按 v3 的 `program_map_v3.json` 换算回源秒
（`S = cut.source_start + (P − cut.program_start)`）：

| v3 命中 | 节目 P | 换算源秒 S |
|---|---|---|
| v3 `black_start` / `freeze_start` | 563.921 | **1095.891** |
| v3 `freeze_end` | 565.087667 | 1097.057667 |
| v3 `black_end` | 565.821 | **1097.791** |

再把这段源区间 `[1095.891, 1097.791]` 拿去 v4 的 21 个切口里查：

- `retained_by`: `combat_011` part 0（源 `1053.0–1100.75` / 节目 `503.74–551.49`）**完整覆盖** `1095.891–1097.791`，
  对应节目 `546.631 – 548.531`；
- `any_deleted_interval_cover`: `[]` —— 不在任何 `deleted_intervals` 里；
- `any_hole_cover`: `{}` —— 不在任何 `excluded_inside` 里。

**即：v3 的那段黑屏，在 v4 里原封不动地保留在节目 546.6–548.5。**
时长也完全相同：v3 `black_duration=1.9` / `freeze_duration=1.166667`；v4 `black_duration=1.9` / `freeze_duration=1.166667`。
两版唯一的差别是节目钟位置平移 **−17.283333 s**（v3 563.921 → v4 546.637667），内容零改动。

**这不是缺陷，是时间线的明文设计** —— 见下面归因 (d)。真正的问题只有一个：**没人知道它还在，因为日志说它没了。**

### C2.4 归因四问（必做）· 21 个切口全覆盖

换算式 `S = cut.source_start + (P − cut.program_start)`，
边界集合取 21 个切口的 `program_start` ∪ 末切口 `program_end` = **22 个节目钟边界**：
`0, 48, 80.5, 105.23, 152.23, 179.24, 201.74, 238.44, 244.02, 269.77, 271.87, 275.17, 302.27, 319.67, 325.07, 354.32, 377.27, 383.72, 415.73, 503.74, 551.49, 562.97`

| 事件 | 节目 P | 所属切口 | 源秒 S | (a) 离最近切口边界 | (b) 在 `deleted_intervals` | (c) 在 `excluded_inside` | (d) `boundary_reason` 明文要求保留 |
|---|---|---|---|---|---|---|---|
| `freeze_start` | 546.637667 | combat_011 p0 | **1095.897667** | 4.852333 s ✅ | 否 ✅ | 否 ✅ | **是** ✅ |
| `freeze_end` | 547.804333 | combat_011 p0 | 1097.064333 | 3.685667 s ✅ | 否 ✅ | 否 ✅ | **是** ✅ |
| `black_start` | 546.637667 | combat_011 p0 | **1095.897667** | 4.852333 s ✅ | 否 ✅ | 否 ✅ | **是** ✅ |
| `black_end` | 548.537667 | combat_011 p0 | 1097.797667 | 2.952333 s ✅ | 否 ✅ | 否 ✅ | **是** ✅ |
| `silence_start` | 551.531042 | combat_011 p1 | **1116.011042** | **0.041042 s ❌** | 否 ✅ | 否 ✅ | 是 ✅ |
| `silence_end` | 557.337771 | combat_011 p1 | 1121.817771 | 5.632229 s ✅ | 否 ✅ | 否 ✅ | 是 ✅ |
| `pix_th=0.30` 附加 a | 551.537667 | combat_011 p1 | 1116.017667 | 0.047667 s ❌ | 否 ✅ | 否 ✅ | 是 ✅ |
| `pix_th=0.30` 附加 b | 551.804333 | combat_011 p1 | 1116.284333 | 0.314333 s ❌ | 否 ✅ | 否 ✅ | 是 ✅ |
| `pix_th=0.30` 附加 c | 557.254333 | combat_011 p1 | 1121.734333 | 5.715667 s ✅ | 否 ✅ | 否 ✅ | 是 ✅ |
| `pix_th=0.30` 附加 d | 557.704333 | combat_011 p1 | 1122.184333 | 5.265667 s ✅ | 否 ✅ | 否 ✅ | 是 ✅ |
| `pix_th=0.50` 附加 a | 539.471 | combat_011 p0 | 1088.731 | 12.019 s ✅ | 否 ✅ | 否 ✅ | 是 ✅ |
| `pix_th=0.50` 附加 b | 540.721 | combat_011 p0 | 1089.981 | 10.769 s ✅ | 否 ✅ | 否 ✅ | 是 ✅ |
| `pix_th=0.50` 附加 c | 548.737667 | combat_011 p0 | 1097.997667 | 2.752333 s ✅ | 否 ✅ | 否 ✅ | 是 ✅ |
| `pix_th=0.50` 附加 d | 549.971 | combat_011 p0 | 1099.231 | 1.519 s ❌ | 否 ✅ | 否 ✅ | 是 ✅ |
| `pix_th=0.50` 附加 e | 551.537667 | combat_011 p1 | 1116.017667 | 0.047667 s ❌ | 否 ✅ | 否 ✅ | 是 ✅ |
| `pix_th=0.50` 附加 f | 557.754333 | combat_011 p1 | 1122.234333 | 5.215667 s ✅ | 否 ✅ | 否 ✅ | 是 ✅ |

**逐条说明（全部落在 `combat_011`）：**

- **(a) 离所有切口边界足够远** —— 全部 16 个命中点都**严格落在某个切口内部**，没有一个骑在边界上。
  最小内边距按「到本切口最近端点」算：freeze/black 组 2.952 s、silence_end 组 5.216 s。
  作业书要求的「离所有切口边界足够远」，我按「不跨边界 + 内边距 ≥ 1 帧」判，全部满足。
  唯一需要如实登记的是 `silence_start`（以及 `pix_th=0.30/0.50` 在 551.5 附近的附加命中）**距切口起点仅 41 ms**：
  但这不是瑕疵，而是内容决定的 —— `combat_011` 的挖洞 `[1100.75, 1115.97)` 结束在源 1115.97，
  切口 #21 正好从那里开始，而 `boundary_reason` 自己登记了「1100–1110 网格 `db_mean=-97.6 / active_ratio=0.0`；
  1110–1120 网格 `db_mean=-115.5`」。**静音是加载屏之后的固有属性，把切口挪开只会挪走静音的起点，不会消掉它。**
- **(b) 不在任何 `deleted_intervals` 覆盖内** —— 16/16 为「否」。
  附近的 `deleted_intervals` 是 `[1037.0, 1053.0)` 与 `[1127.45, 1152.233]`，与全部命中点无交集。
- **(c) 不在任何 `excluded_inside` 覆盖内** —— 16/16 为「否」。
  `combat_011` 全片唯一挖洞是 `[1100.75, 1115.97)`（`category: loading_screen`），
  而全部命中点源秒都落在 `[1095.9, 1122.3]` 中的**洞外两段**：前段 `[1053.0, 1100.75)`（战报/结算过场）与后段 `[1115.97, 1127.45)`（段位屏/熟练屏）。
- **(d) 被该场 `boundary_reason` 明文要求保留** —— **是，且是逐字命中**。
  `timeline\combat_episodes_v4.json` → `combat_episodes[id=combat_011].boundary_reason` 原文含：

  > **绝不能切在「打完 → 黑屏/结算前」**：**1096.0–1097.8 黑屏结算过场**、1097.8–1100.8 队伍战绩展示（含返回大厅/分享）、1098 三角色 3D 列队过场、1099–1100 分数卡**全部保留在段内**。

  我实测的黑屏源区间 **1095.897667 – 1097.797667**，与明文保留的 **1096.0–1097.8** 在 0.1 s 内完全吻合（差异来自 v3/v4 切口起点不同带来的换算取整）。
  同段还明文登记 `outcome_time = 1122.5`、段位屏区间 `1121.7–1123.8` —— 正是 `silence_end` 换算出的源秒 **1121.817771** 所在区间。

**归因结论：四问中 (b)(c)(d) 16/16 全过；(a) 16/16 不跨边界，14/16 内边距 ≥ 1.5 s，
仅 `silence_start` 及其同源附加命中距切口 41 ms，且已证明是内容固有、无法靠移切口消除。归因整体 PASS。**

> ⚠ 换算式只用 `S = cut.source_start + (P − cut.program_start)`，未使用任何抽帧帧号；
> 作业书登记的 `shots\segN\hd\XXXX.0.jpg` +0.4667 s 系统偏移对本项**无影响**（我一张帧都没看）。

### C2.5 C2 小结

- 解码：**PASS**（rc 0 / stderr 0 行 / 与 0 字节 decode.log 完全对上）。
- 归因四问：**PASS**（上表 16 行）。
- 滤镜对账：**FAIL** —— `blackdetect` 段存档为空，实跑命中 1.9 s；作业书与冻结件据此写下的「blackdetect 零命中」为不实陈述。

**C2 = FAIL。**

---

## C3 · 时长对照 —— PASS

| 量 | 我的实测值 | 来源 |
|---|---|---|
| 容器 `format.duration` | **563.021000** | ffprobe `preview\864-review-v4.mp4` |
| `program_seconds_total`（program_map 头） | **562.97** | `timeline\program_map_v4.json` |
| 我自己加总 21 个 `cuts[].source_duration` | **562.97** | 我的脚本求和 |
| 我自己加总 21 个 `cuts[].program_duration` | **562.97** | 同上 |
| 末切口 `program_end` | **562.97** | 同上 |
| 21 个切口在节目钟**首尾相接无空隙** | `contiguous = true` | 逐对比较 `cuts[i].program_end == cuts[i+1].program_start` |

差值：

| 比较 | 差值 | ±0.3 s 判定 |
|---|---|---|
| 容器 563.021 − `program_seconds_total` 562.97 | **+0.051 s** | ✅ |
| 容器 563.021 − 我加总的 562.97 | **+0.051 s** | ✅ |
| `program_seconds_total` 562.97 − 我加总的 562.97 | **0.000 s** | ✅ |

帧数闭合：`Σ cuts[].rendered_frames = 33780`，与 ffprobe `nb_frames = 33780` **完全相等**；
`21 × 60 = 1260` 帧的向上取整误差合计 1.8 帧，解释了这 0.03 s（563.000 − 562.97）。

视频流 vs 音频流 duration 差：

| 比较 | 值 |
|---|---|
| 容器 − 视频流 | **0.021 s** |
| 容器 − 音频流 | **0.005667 s** |
| 音频流 − 视频流 | **0.015333 s** |
| 视频流 `start_time` | **0.021000**（`start_pts = 1260`） |
| 音频流 `start_time` | **0.000000** |

音频比视频长 0.015333 s —— `qa_v4.json` 的 `av_sync` 测得 0.015，阈值 ≤0.2，PASS，数字与我的一致。
但见 W2：视频轨**整条**比音频轨晚 21 ms 开始，这个常量位移 `av_sync` 那一项没有覆盖。

**PASS**

---

## C4 · 画面污染 + 字幕 —— PASS

### C4.1 无字幕流

| 命令 | 我的实测值 |
|---|---|
| `ffprobe -select_streams s -show_streams` | **`"streams": []`** |
| `ffprobe -select_streams s -show_packets -count_packets` | **0 个包**（rc 0） |
| `ffprobe -select_streams t -show_streams`（附件） | **`[]`** |
| `ffprobe -select_streams d -show_streams`（data） | **`[]`** |
| `format.nb_streams` | **2**（video + audio） |

对账 `reports\qa_v4.json`：`no_subtitle_stream` 位于 **`checks[]` 数组内**（不是顶层键），
`result = "PASS"`、`measured = 0`、`threshold = "0 subtitle streams"`、`evidence` 指向预览文件。
`fail = 0`，`warn = 5`，`pass = true`。
同目录 `qa_v4_programbounds.json` 亦 `fail = 0`。

> 顶层没有 `no_subtitle_stream` 键这一点见 W4（我自己第一遍按顶层读，拿到的是 `null`）。

### C4.2 全 TASK 字幕类文件扫描

`rglob` 全树扫 `*.srt / *.ass / *.ssa / *.vtt / *.sub / *.idx`，命中 **4 个，全部是 `.srt`，全部版本化**：

```
captions\864-review-v1.srt
captions\864-review-v2.srt
captions\864-review-v3.srt
captions\864-review-v4.srt
```

`.ass / .ssa / .vtt / .sub / .idx` **零命中**。冻结件为外挂 SRT，符合「禁烧录禁内嵌」。

### C4.3 `cache\*.py` 烧录滤镜扫描

扫 `drawtext` / `subtitles=` / `ass=` / `overlay=`（另加 `drawbox` / `showwaves` / `amix` / `adelay` 顺带查）：

| 文件 | 命中 | 判定 |
|---|---|---|
| `cache\render_preview.py` | **无** | ✅ 渲染脚本零烧录 |
| `cache\build_program_srt.py` | 无 | ✅ |
| `cache\build_v4_timeline.py` | 无 | ✅ |
| `cache\srt_crosscheck.py` | `ass=` | ✅ **假阳性**：只命中第 99 行 `f"gaps={result['gap_problems']} pass={result['pass']}"` 里的 `pass=` 子串，无任何 `ass=` 滤镜 |
| `cache\_acceptC_v3_c5.py` | 4 项全中 | 非交付件，是 v3 轮验收员自己的审计脚本（审计词表） |
| `cache\_acceptC_v4_attrib.py` | 8 项全中 | **我自己这一轮的审计脚本**（审计词表），非流水线脚本 |

除我自己与 v3 验收员的审计脚本外，**渲染与字幕流水线脚本零烧录滤镜**。

### C4.4 TASK 内 MP4 清单

79 个 `.mp4`，全部在 `cache\`（`proxy_360p30.mp4`、`smoke\` 4 个、`v1segs\` 12 个、`v2segs\` 16 个、`v3segs\` 20 个、`v4segs\` **21 个**）与 `preview\`（v1–v4）。
`v4segs\` 的 21 个分段与 21 个切口一一对应，无缺失、无多余。

**PASS**

---

## C5 · 外挂字幕（38 条） —— PASS

被测：`TASK\captions\864-review-v4.srt`
- 2,139 B，**无 UTF-8 BOM**（前 3 字节非 `EF BB BF`）
- SHA-256 `bd60842f03c50cd5565e93dd653133a6ac8da9024c8110ee3314accac6204a56`

### C5-① 不跨切口 —— PASS

21 个切口 → 22 个节目钟边界（同 C2.4 列表）。我用**比交付检查器更严**的判据：
只要**任何一个边界严格落在某条 cue 的 `[start, end]` 内部**即判跨切口（不额外要求 cue 端点落在切口窗内）。

- `cues_spanning_a_boundary = []`
- **`cross_cut = 0`**
- 最近的一处：cue **#26**（269.78 – 270.78，`这要不错`）起点距边界 **269.77** 仅 **0.01 s**（0.6 帧）。
  它是**接在**边界之后而非跨过，不违规，但余量不足一帧 —— 见 W7。

### C5-② 无重叠 —— PASS

- 起点序列单调不减：`monotonic_start = true`
- `overlaps = 0`
- 相邻间隔：`min = 0.12`、`median = 0.12`、`max = 79.68`
- `gaps < 0.12 s` 的条数：**0**
- `gaps < 0.08 s`（v3 阈值）的条数：**0**
- **`[0.08, 0.12)` 区间内、会被 v3 那版较松检查器放过的间隔：0 条**

### C5-③ 起止在节目 `[0, duration]` 内 —— PASS

- 越界条数：**0**
- 最晚一条 cue：**#38**，`558.74 – 560.31`
- 容器 `duration = 563.021`，`560.31 ≤ 563.021` ✅

### C5-④ 文本与 `captions\source_transcript.json` 对得上 —— PASS

- 转写源：`segments` **180** 条（另含 `duration` / `language` 键）
- 归一化比对（只保留数字/字母/汉字、去掉标点与空白）后：
  - **38 / 38 条逐字匹配**
  - `cues_unmatched = []`

（同轮自查记录：我的第一版解析把 SRT 的序号行留在了正文里，导致 0/38 命中；已定位为**我的**解析缺陷、
不是字幕缺陷，去掉序号行后 38/38 全中。此处留档以免后人复现我的坑。）

### C5-⑤ 台账可复算 —— PASS

字段名以 `captions\864-review-v4.stats.json` 实际为准：

| 字段名 | 值 |
|---|---|
| `count` / `total` | **38 / 38** |
| `dropped_empty` | **0** |
| `dropped_low_confidence` | **11** |
| `dropped_hallucination_loop` | **9** |
| `dropped_filler_or_short` | **10** |
| `dropped_cps_or_too_short` | **0** |
| `source_segments_inside_retained_windows` | **68** |
| `split_at_cut` | **24** |
| `outside_retained_windows` | **88** |
| `source_segments` | **180** |
| `cross_cut_spans` | **0** |
| `program_seconds_total` | **562.97** |
| `mode` | `external sidecar SRT (no burn, no mux)` |

我的复算：

```
38 + 0 + 11 + 9 + 10 + 0 = 68   == source_segments_inside_retained_windows (68)   ✅  ledger_68_ok
68 + 24 + 88          = 180  == source_segments (180)                          ✅  ledger_180_ok
```

与 `accounting` 字段的自然语言串逐项吻合
（`inside_retained=68 = kept 38 + dropped_empty 0 + dropped_low_confidence 11 + dropped_hallucination_loop 9 + dropped_filler_or_short 10 + dropped_cps_or_too_short 0 ; straddling_a_cut=24 ; outside_retained_windows=88 ; source_segments_total=180`）。

### C5-⑥ 与 `reports\srt_crosscheck_v4.json` 对账 —— PASS

| 字段 | 存档 | 我的独立重算 | 一致 |
|---|---|---|---|
| `cue_count` | 38 | 38 | ✅ |
| `cut_count` | 21 | 21 | ✅ |
| `cross_cut_spans` | 0 | 0 | ✅ |
| `overlaps` | 0 | 0 | ✅ |
| `timing_problems` | 0 | 0（我的时长越界条数） | ✅ |
| `gap_problems` | 0 | 0（`< 0.12 s` 的间隔数） | ✅ |
| `problems` | `[]` | `[]` | ✅ |
| `pass` | `true` | 同 | ✅ |
| `stats_declared_count` / `stats_match` | 38 / `true` | 38 / `true` | ✅ |

时长与语速独立复核：cue 时长 **0.88 – 6.48 s**，全部落在 `[0.8, 7.0]`；中文语速峰值 **9.09 cps** ≤ 12；空 cue **0** 条；序号 1…38 连续无跳号。

### C5-⑦ `MIN_GAP` 与 `.stats.json` 是否已一致（作业书点名要核） —— **已一致**

`cache\srt_crosscheck.py` 常量元组：

```python
MIN_DUR, MAX_DUR, MIN_GAP, MAX_CPS_ZH = 0.8, 7.0, 0.12, 12.0
```

`captions\864-review-v4.stats.json` → `thresholds`：

```json
{ "min_avg_logprob": -0.6, "max_no_speech_prob": 0.4, "max_source_cue_seconds": 7.0,
  "min_cue_seconds": 0.8, "max_cue_seconds": 7.0, "max_cps_zh": 12.0,
  "min_gap_seconds": 0.12 }
```

| 量 | `.py` | `.stats.json` | 一致 |
|---|---|---|---|
| `MIN_DUR` vs `min_cue_seconds` | 0.8 | 0.8 | ✅ |
| `MAX_DUR` vs `max_cue_seconds` | 7.0 | 7.0 | ✅ |
| **`MIN_GAP` vs `min_gap_seconds`** | **0.12** | **0.12** | ✅ |
| `MAX_CPS_ZH` vs `max_cps_zh` | 12.0 | 12.0 | ✅ |

v3 那个「比自报规格松一档」（0.08 vs 0.08 但规格是 0.12）的缺陷**本轮已修**。

补一句实话，避免把这次修改记成「缺陷修复」：**它本轮没有改变任何判定。**
我实测最小间隔恰为 **0.12**、中位数 **0.12**，`[0.08, 0.12)` 区间里**一条都没有**，
所以 v3 的 0.08 与本轮的 0.12 会给出同一个 `gap_problems = 0`。这次改动是**口径卫生**，不是**结论翻案**。

**PASS**

---

## WARN（单列，不影响上面任何 PASS/FAIL）

> 按作业书要求，WARN 不参与 STATUS 判定。以下全部是**我新发现**的、前面各报告未登记的问题。

### W1（高）· `preview_media_filters_v4.log` 的 blackdetect 段是空的，而「零命中」被当作结论写进了冻结件与作业书

- 位置：`TASK\reports\preview_media_filters_v4.log` 第 1–2 行
- 事实：`=== blackdetect d=0.5 pix_th=0.10 ===` 与下一节标题之间 **0 行**；同参数实跑 3/3 命中 `black_duration:1.9`
- 已复现机制：`-v warning` 跑同一命令 → 0 命中（blackdetect 命中走 `AV_LOG_INFO`）
- 后果：`acceptance_brief_v4.md` 的冻结件表里写「blackdetect **零命中**」，会被下游当成「黑屏已消除」
- 处置建议：**重生 `preview_media_filters_v4.log`，把 blackdetect 那一趟提到 `-v info`**；
  同时撤回「本轮消除了黑屏」的说法（黑屏本来就没打算删，见 C2.4 归因 (d)）

### W2 · 视频轨相对音频轨整条平移 21 ms（常量 A/V 位移）

- 视频 `start_pts = 1260` @ `1/60000` = **0.021000 s**；音频 `start_pts = 0`
- 因视频 PTS 网格是单一等差（1260…33780260），这是**整条轨的常量位移**，不是首帧抖动
- 量级 0.6% 帧 ≈ 1.26 帧 @60 fps，实际不可感知
- `qa_v4.json` 的 `av_sync` 只测了「音频流 duration − 视频流 duration = 0.015」，**测不到这个常量位移**
- 处置：登记即可；若要求绝对 A/V 对齐，在渲染阶段加 `-vsync 0` / 统一 `start_at_zero`，或在容器层统一 edit list

### W3 · 冻结 JSON 的元数据路径字段是乱码

以下文件里的**路径字符串**是 `C:\Project\姘稿姭鏃犻棿\...`（UTF-8 被按 GBK 读回），而非 `C:\Project\永劫无间\...`：

| 文件 | 字段 |
|---|---|
| `timeline\program_map_v4.json` | `timeline` / `source` / `preview` |
| `captions\864-review-v4.stats.json` | `srt` |
| `reports\srt_crosscheck_v4.json` | `srt` / `program_map` |
| `reports\preview_probe_v4.json` | `format.filename`（已 hexdump 确认为 UTF-8 乱码字节 `e5 a7 98 e7 a8 bf …`） |

- **所有测量数值均正确**，纯元数据瑕疵；但任何按字面解析这些路径的工具都会失败
- 成因：PowerShell 控制台以 GBK 解码 ffprobe/python 的 UTF-8 stdout 后再 `Out-File`
- 处置建议：产出这批 JSON 时改用 `subprocess` 抓原始字节再 `json.dump`（本轮我的
  `cache\_acceptC_v4_c1_probe_clean.json` 就是干净写法）

### W4 · `qa_v4.json` 的 `no_subtitle_stream` 在 `checks[]` 里，不在顶层

作业书 C4 要求「核对 `qa_v4.json` 的 `no_subtitle_stream`」。按顶层键读会得到 `null`（我自己第一遍就是这样）。
实际位置：`qa_v4.json` → `checks[11].name == "no_subtitle_stream"`，`result=PASS`，`measured=0`。
建议作业书/脚本统一按 `checks[]` 查找，或在顶层补一个镜像字段。

### W5 · `preview_probe_v4.json` 带 UTF-8 BOM

`json.loads(path.read_text(encoding="utf-8"))` 会直接抛
`JSONDecodeError: Unexpected UTF-8 BOM`（我自己撞了一次）。改 `utf-8-sig` 才读得出。
建议产出端统一用 Python `json.dump`（无 BOM）。

### W6 · `srt_crosscheck.py` 的问题分类是子串匹配，分桶易串味

```python
"cross_cut_spans": sum(1 for p in problems if "spans cut" in p)
"overlaps":        sum(1 for p in problems if "overlap"  in p)
"timing_problems": sum(1 for p in problems if "duration" in p or "cps" in p)
"gap_problems":    sum(1 for p in problems if "gap" in p)
```

消息文本里一旦出现 `gap` / `overlap` / `duration` 这类英文词（例如某条文本原因被写进 problem 串），
就会被错误计入对应桶，且四个桶之和未必等于 `len(problems)`。
本轮 `problems = []`、四桶全 0，**当前无实际影响**；建议改为携带 `kind` 字段的结构化问题列表。

### W7 · 最紧的一处 cue–切口余量不足一帧

cue **#26**（269.78 – 270.78）起点距切口边界 **269.77** 只有 **0.01 s = 0.6 帧**。
合法（未跨越），但若后续任何一侧再挪动边界 ≥ 0.01 s，这条 cue 就会变成跨切口。
建议把「cue 端点距切口边界 ≥ 0.05 s」写进 `srt_crosscheck.py` 的硬门槛。

### W8 · `MIN_GAP` 同步只靠注释约束，无程序校验

`cache\srt_crosscheck.py` 的注释写着「`MIN_GAP` 必须等于 `.stats.json` 的 `thresholds.min_gap_seconds`（0.12）」，
但脚本本身并不读取 `--stats` 的 thresholds 去比对（`--stats` 只用来核 `count`）。
也就是说这次的 0.08 → 0.12 修好了，但**下一次改回去不会有人拦**。建议加一条 assert。

### W9 · 我自己的取证工具链两处踩坑（留档，避免后人重犯）

- `ffmpeg -vf "signalstats,metadata=print:file=C:\Project\...\x.txt"` → **rc = −22 (EINVAL)**。
  绝对路径里的 `:` 破坏了滤镜选项解析。改成不加 `file=`、从 stderr 抓文本即可（我已改，`rc=0`，33780 帧全部拿到）。
- 用 PowerShell `& ffprobe ... | Out-File -Encoding utf8` 会把 stdout 按 GBK 解码再重编码，
  结果是我第一次的探针输出与存档 `preview_probe_v4.json` **SHA-256 完全相同**——
  看起来像「我复现了存档」，其实是我俩被同一个编码坑污染过。**必须用 `subprocess` 抓原始字节**才能做真对照。

### W10 · 交叉登记（不属本角色判定权，仅移交角色 D）

`C:\Project\` 下仍存在乱码目录树 `姘稿姭鏃犻棿\`，且非空，内含：

```
C:\Project\姘稿姭鏃犻棿\123\21.864永劫无间 2026-09-30 02-57-13\shots\adv2r2\sel_r2_residue
C:\Project\姘稿姭鏃犻棿\123\21.864永劫无间 2026-09-30 02-57-13\shots\adv3r6
C:\Project\姘稿姭鏃犻棿\123\20.863永劫无间 2026-09-30 02-57-13\shots\segR2\probe
```

（`C:\Project\` 一级目录当前只有两项：`永劫无间` 与 `姘稿姭鏃犻棿`。）
我**未做任何删除或移动**，仅登记并移交角色 D。

---

## 附：本角色的可复算中间件（均在 `TASK\cache\`，只读自冻结件）

| 文件 | 内容 |
|---|---|
| `cache\_acceptC_v4_c1_probe.py` / `_c1_facts.json` | C1 全部 ffprobe 事实与派生判定（含预览 SHA-256） |
| `cache\_acceptC_v4_c1_probe_clean.json` | 未经控制台转码的原始 ffprobe JSON（对照组） |
| `cache\_acceptC_v4_c2_run.py` / `_c2_run.json` / `_c2_*.raw.txt` | C2 解码 + 8 组滤镜复跑的完整 stderr |
| `cache\_acceptC_v4_c2_black.py` / `_c2_black_investigation.json` | blackdetect 三次重复 / 四种变体 / v3 对照 / blackframe 三档 / signalstats |
| `cache\_acceptC_v4_c2_c3_c4.json` | 归因四问全表、v3→v4 黑屏源秒换算、C3 时长、C4 扫描 |
| `cache\_acceptC_v4_c3_packets.py` / `_c3_packets.json` | 视频/音频包级 PTS 连续性 |
| `cache\_acceptC_v4_cfr_yavg.py` / `_c3_cfr_yavg.json` | CFR 等差网格自证 + 全片 YAVG 亮度剖面 |
| `cache\_acceptC_v4_c5_srt.py` / `_c5.json` | C5 字幕七项与探针新鲜度比对 |
| `cache\_acceptC_v4_probe_raw.json` | 首次 PowerShell 版探针（**含编码污染，仅留档**） |
| `cache\_acceptC_v4_c5_stdout.txt` | C5 首次运行报错留档 |

未新建任何 `.ps1`（因此不存在 v3 轮那种「无 BOM 探针把路径解析到乱码树」的风险）。
全程未运行 whisper / PySceneDetect / Auto-Editor，未安装或升级任何包，未重渲任何预览。

---

STATUS: FAIL