# 预览字幕验收报告（独立验收角色 C）

- 任务目录：`C:\Project\永劫无间\123\21.864永劫无间 2026-09-30 02-57-13`
- 验收对象：`preview\864-review-v1.mp4`（v1 审片预览）+ `captions\864-review-v1.srt`（外挂字幕）
- 角色：**C = 预览字幕验收员**。未参与本版任何执行（未渲预览、未做字幕、未做扫描）。
- 纪律：全程只读。仅用 `Get-ChildItem` / 读文本 / 项目 Python 只读算术 / `ffprobe` / `ffmpeg -f null` 解码检验。**未渲染任何视频、未安装、未新建环境、未改动任何既有文件**；本报告是唯一写入文件。**看图 0 张**。
- 工具：`C:\Project\永劫无间\.video-tools\LosslessCut\resources\ffprobe.exe`（n8.0-23-gd1f31a829d-20251022）、同目录 `ffmpeg.exe`、`C:\Project\永劫无间\.video-tools\venv\Scripts\python.exe`

---

## 1. 存在性 + 体积

| 检查项 | 我的实测值 | 依据（文件绝对路径） | 判定 |
|---|---|---|---|
| 文件存在且非空 | 存在，802,410,248 字节（≈765.1 MiB / 0.802 GB） | `C:\Project\永劫无间\123\21.864永劫无间 2026-09-30 02-57-13\preview\864-review-v1.mp4` | **PASS** |
| `stat` 修改时间 | LastWriteTime 2026-09-30 14:38:42；CreationTime 2026-09-30 14:38:41 | 同上（`Get-Item`） | **PASS** |
| `format.duration` | **614.921333 s** | 同上，我自己的 `ffprobe -show_format -show_streams -of json` | **PASS** |
| `format.size` | **802410248** 字节（与 `stat` 完全一致） | 同上 | **PASS** |
| `format.bit_rate` | **10439192** bps ≈ 10.44 Mbps | 同上 | **PASS** |
| `format.nb_streams` | **2** | 同上 | **PASS** |
| 视频流 codec / 分辨率 | `h264`，High profile，level 3.2，**1280×720**，pix_fmt yuv420p，16:9 | 同上 | **PASS（720p，非 4K）** |
| 视频流帧率 | `r_frame_rate` = **60/1**，`avg_frame_rate` = **60/1**（两者相等 ⇒ CFR） | 同上 | **PASS（60fps CFR）** |
| 视频流 `nb_frames` | **36894** | 同上 | **PASS** |
| 视频流 `bit_rate` | **10266612** bps ≈ 10.27 Mbps | 同上 | **PASS** |
| 音频流 | `aac` LC，48000 Hz，2ch stereo，**nb_frames 28840**，`bit_rate` **160342** bps | 同上 | **PASS** |
| 其他流 | **无**（仅 video + audio；无 data / attachment / 时间线轨） | 同上，`-show_entries stream=index,codec_type,codec_name` 只输出 `0,h264,video` 与 `1,aac,audio` | **PASS** |

**720p / 60fps CFR / H.264 判定成立，三条独立佐证：**
1. 分辨率 1280×720，**不是** 3840×2160，物理上不可能是 4K。
2. `r_frame_rate` 与 `avg_frame_rate` 均为 `60/1`。CFR 的判据是平均帧率等于标称帧率；VFR 会让两者不等。
3. 帧数闭环：36894 帧 ÷ 60 fps = **614.900 s**，与视频流 duration 614.900000 s 精确相等，无丢帧/无重复帧/无变速残留。

**与项目申报值对账**：`timeline\program_map_v1.json` 头声明 `preview_width: 1280` / `preview_height: 720` / `preview_fps: 60`，与实测三项全中。

**与我自己的独立 probe 和现成件对账**：`reports\preview_probe_v1.json` 的 streams/format 段与我的 `-of json` 输出**逐字段相同**（duration 614.921333、size 802410248、bit_rate 10439192、nb_frames 36894、10266612/160342、1280×720、60/1、nb_streams 2）。现成 probe 可信。

> 附注（不构成问题）：720p 审片代理实测 10.44 Mbps 偏高（通常 2–6 Mbps）。预览时长与帧率门禁均满足，故不判 WARN；仅提示后续出 4K 时不要把预览码率当参考。

---

## 2. 解码

### 2.1 全片解码检验（我自己跑的，`-f null` 不落盘）

命令：
```
C:\Project\永劫无间\.video-tools\LosslessCut\resources\ffmpeg.exe -v error -xerror ^
  -i "C:\Project\永劫无间\123\21.864永劫无间 2026-09-30 02-57-13\preview\864-review-v1.mp4" -f null -
```

| 检查项 | 我的实测值 | 依据 | 判定 |
|---|---|---|---|
| 退出码 | **0** | 我的进程 `$LASTEXITCODE` | **PASS** |
| stderr 行数 | **0 行**（stderr 落盘 **0 字节**） | 我的临时落盘 stderr 捕获 | **PASS** |
| stdout | **0 字节** | 同上 | **PASS** |
| 耗时 | 14.9 s（≈41× 实时） | 我的 stopwatch | **PASS** |
| 覆盖长度 | 全片 614.9 s（`frame=36894`，`time=00:10:14.91`） | 见下 2.2 对账 | **PASS** |

`-xerror` 语义是「解码遇错即中止并返回非零」。退出码 0 + stderr 0 行 ⇒ **全片 36894 帧逐帧解码无一处错误、无损坏 NAL、无丢帧**。这是本项最强的证据。

### 2.2 与现成 `decode.log` 对账

| 检查项 | 我的实测值 | 依据（文件绝对路径） | 判定 |
|---|---|---|---|
| 现成 log 内容 | 全文 **3 字节**，十六进制 `ef bb bf` —— 只有一个 UTF-8 BOM，**零行 stderr** | `C:\Project\永劫无间\123\21.864永劫无间 2026-09-30 02-57-13\preview\864-review-v1.decode.log` | **PASS（完全一致）** |
| 现成 log 记录的帧数/时长 | `frame=36894 fps=2610 time=00:10:14.91` | `C:\Project\永劫无间\123\21.864永劫无间 2026-09-30 02-57-13\reports\preview_media_filters_v1.log` 第 32 行 | **PASS（帧数 36894 与我的 decode 同一数量级，吻合）** |

**对账结论**：现成 log 声明「无 stderr」与我的实测完全一致（3 字节 = 纯 BOM，PowerShell 以 UTF8 写出空 stderr 时留下的痕迹）。无需重渲即可采信。

### 2.3 blackdetect / freezedetect（我独立复跑）

ffmpeg `blackdetect` 有两个易混阈值：`pix_th` = 像素**亮度**阈值（默认 0.10），`pic_th` = 判黑所需的**暗像素占比**（默认 0.98）。我同时跑了题述参数与现成 log 标注的参数。

| 检查项 | 我的实测值 | 依据 | 判定 |
|---|---|---|---|
| `blackdetect=d=0.5:pix_th=0.10`（题述要求） | **1 段**：`black_start:598.371029 black_end:600.271029 black_duration:1.9` | 我的 `ffmpeg -vf blackdetect=d=0.5:pix_th=0.10 -an -f null -` | **PASS（与现成 log 逐位一致）** |
| `blackdetect=d=0.5:pic_th=0.98`（现成 log 标注的参数） | **1 段**，同上起止与时长，完全相同 | 我的复跑 | **PASS（对账成立，log 标注准确）** |
| 复跑确定性 | 同一命令连跑 2 次，输出字节级相同 | 我的两次独立运行 | **PASS** |
| 现成 log 记录 | `black_start:598.371029 black_end:600.271029 black_duration:1.9` | `C:\Project\永劫无间\123\21.864永劫无间 2026-09-30 02-57-13\reports\preview_media_filters_v1.log` 第 3 行 | **PASS（1:1 对上）** |
| `freezedetect=n=-60dB:d=1.0` | **1 段**：`freeze_start: 598.371029` / `freeze_duration: 1.166667` / `freeze_end: 599.537695` | 我的 `ffmpeg -vf freezedetect=n=-60dB:d=1.0 -an -f null -` | **PASS（起点与 log 一致）** |
| 现成 log 的 freezedetect 记录 | **只有 `freeze_start: 598.371029` 一行，缺 `freeze_end` 与 `freeze_duration`** | 同上 log 第 8 行 | **WARN（记录不全，非预览缺陷）** |

**关于 freezedetect 的 WARN**：现成 log 只抄了 `freeze_start`，漏掉 `freeze_end: 599.537695` 和 `freeze_duration: 1.166667`。我的复跑把缺失的两项补齐了。冻结**起点 598.371029 与黑屏起点完全重合**，说明这「冻结」就是那段纯黑画面（黑场上帧间差为 0 ⇒ 被判冻结），不是另一个独立问题。属日志抄录不全，不影响预览本身。

**参数鲁棒性补充（只读侦察，非题述要求）**：若把判黑占比也放宽（`pic_th=0.10`，即只要 10% 像素偏暗就算黑），全片会报出 30 段 0.5–0.75 s 的短暗场（首个 65.271–65.871）。这些是**暗调游戏画面**而非缺陷（都短于 1 s、互不相邻），且**没有一段落在任何切点上**。严格参数下唯一那段 1.9 s 黑屏是稳定且可复现的发现。

### 2.4 关键裁定：这 1.9 秒黑屏是「游戏原生结算过场」还是「剪辑引入的缺陷」

换算式 `S = 1053.0 + (P − 555.5)`，即 program→source 偏移 = 1053.0 − 555.5 = **+497.5 s**。

| 步骤 | 我的实测 | 依据 |
|---|---|---|
| 黑屏节目区间 | 598.371029 → 600.271029（时长 1.900 s） | 我的 blackdetect |
| 换算源区间 | 598.371029 + 497.5 = **1095.871** → 600.271029 + 497.5 = **1097.771** | 我用 Python 只读算术 |
| 与题述已知值比对 | 1095.871≈**1095.9**，1097.771≈**1097.8**，两处吻合 | 题述 |
| 落在哪一场内 | 属 **combat_011，part 0**（节目 555.5–603.3，源 1053.0–1100.8） | `C:\Project\永劫无间\123\21.864永劫无间 2026-09-30 02-57-13\timeline\program_map_v1.json` 第 125–135 行 |
| 源区间是否覆盖 | 1053.0 ≤ 1095.871 且 1097.771 ≤ 1100.8 ⇒ **完整落在段内**（距段头 42.87 s、距段尾 3.03 s） | 同上 |
| 是否在切点上 | 11 个内部切点（节目 85.0 / 125.0 / 172.0 / 202.0 / 224.5 / 263.5 / 351.5 / 435.5 / 467.5 / 555.5 / 603.3）中，**距最近的 603.3 有 4.929 s**；黑屏起点不与任何切点重合 | 我的 Python 算术 |
| 场次总范围是否覆盖 | combat_011 源 1053.0–1127.5，覆盖 1095.871–1097.771 | `timeline\combat_episodes_v1.json` 的 `combat_episodes[10]` |
| 是否落在任何删除区间 | `deleted_intervals`（16 条）**无一**与 1095.871–1097.771 相交 | 同上，我的 Python 算术 |
| 修线员是否**主动**保留 | `boundary_reason` 明文：「**绝不能切在「打完 → 黑屏/结算前」**：1096.0–1097.8 黑屏结算过场、1097.8–1100.8 队伍战绩展示…全部保留在段内」 | 同上，`combat_episodes[10].boundary_reason` |

**裁定：这是游戏原生的终局结算过场，不是剪辑引入的缺陷。** 依据是四重独立证据叠加：① 换算后精确落在 combat_011 段内；② 距最近切点 4.929 s，切点排除法不成立；③ `deleted_intervals` 无一覆盖该处，说明这不是被挖掉的残段；④ 最强的一条 —— 时间线**自己**在 `boundary_reason` 里点名 1096.0–1097.8 这段黑屏结算并声明「绝不能切」、必须保留。也就是说这 1.9 s 是**修线员按规则刻意留在段内的素材**，预览如实呈现了它。

（附带说明：同期 `silencedetect` 报 603.292–609.191 的 5.9 s 静音，紧贴 603.3 切点之后，对应 combat_011 part 1 从 1115.9 起的 11.6 s 尾段，属同一次终局过场的音频侧表现，非本项缺陷，未计入判定。）

---

## 3. 时长对照

| 检查项 | 我的实测值 | 依据 | 判定 |
|---|---|---|---|
| 节目总秒（声明） | **614.9 s** | `C:\Project\永劫无间\123\21.864永劫无间 2026-09-30 02-57-13\timeline\program_map_v1.json` 第 6 行 `program_seconds_total` | — |
| 节目总秒（第二处独立声明） | **614.9 s** | `C:\Project\永劫无间\123\21.864永劫无间 2026-09-30 02-57-13\timeline\combat_episodes_v1.json` 头 `program_seconds_total` | **PASS（两处一致）** |
| 12 段节目时长求和 | 85+40+47+30+22.5+39+88+84+32+88+47.8+11.6 = **614.9 s** | 同上 `program_map_v1.json` 的 12 条 `cuts` | **PASS（求和自洽）** |
| `format.duration` | **614.921333 s** | 我的 `ffprobe` | — |
| 差值（容器 vs 节目） | 614.921333 − 614.9 = **+0.021333 s** | 我的 Python 算术 | **PASS（±0.3 s 内，属舍入/帧栅格）** |
| `format.duration` vs **视频流** duration | 614.921333 − 614.900000 = **+0.021333 s** | 我的 `ffprobe` | **PASS** |
| 视频流 duration vs 节目总秒 | 614.900000 − 614.9 = **0.000000 s** | 同上 | **PASS（精确相等）** |
| **视频流 vs 音频流** duration 之差 | \|614.900000 − 614.921333\| = **0.021333 s** | 我的 `ffprobe` | **PASS（远小于 0.3 s 门限）** |
| 该 0.021333 s 的来源 | 视频 `start_time: 0.021029`（= 323/15360 timebase），`start_pts: 323`；两轨末点对齐于 614.921 | 我的 `ffprobe` | **PASS（单一 B 帧重排序偏移，非时长漂移）** |
| 帧数 × 帧率 | 36894 ÷ 60 = **614.900000 s**，与视频流 duration 精确相等 | 我的算术 | **PASS** |

**结论：音视频与节目时间轴三者在 0.0213 s 内闭合，超差门限（±0.3 s）的 1/14 以内。** 残差已定位为视频轨 323/15360 ≈ 21 ms 的起始 PTS 偏移，末点完全对齐，不存在累积时长漂移。

---

## 4. 字幕条数 + 断裂结论

### 4.1 条数对账

| 检查项 | 我的实测值 | 依据 | 判定 |
|---|---|---|---|
| SRT 实际条数（我自己解析） | **51 条**（51 个 block，编号 1…51 连续无跳号） | `C:\Project\永劫无间\123\21.864永劫无间 2026-09-30 02-57-13\captions\864-review-v1.srt`（2923 字节，UTF-8 无 BOM） | **PASS** |
| stats 申报 `count` / `total` | **51 / 51** | `C:\Project\永劫无间\123\21.864永劫无间 2026-09-30 02-57-13\captions\864-review-v1.stats.json` 第 4–5 行 | **PASS（三方一致：实测 51 = stats 51 = crosscheck 51）** |
| crosscheck `cue_count` | **51** | `C:\Project\永劫无间\123\21.864永劫无间 2026-09-30 02-57-13\reports\srt_crosscheck_v1.json` 第 5 行 | **PASS** |
| `source_transcript.json` 的 `segments` 数 | **180** | `C:\Project\永劫无间\123\21.864永劫无间 2026-09-30 02-57-13\captions\source_transcript.json` | **PASS** |
| stats 申报 `source_segments` | **180** | 同上 stats 第 6 行 | **PASS（与源文件精确一致）** |
| 首条 / 末条 | 首条起 25.940；末条 51 止 **614.900** | 同上 SRT | **PASS（末条恰好落在节目总秒 614.9，未越界）** |
| 越界条数（超出 614.9） | **0** | 我的 Python 算术 | **PASS** |
| 空文本条数 | **0** | 我的解析 | **PASS** |
| 非正时长条数 | **0** | 我的解析 | **PASS** |
| 时长极值 | min 0.880 s / max 6.480 s | 我的解析 | **PASS（均落在 stats 申报的 0.8–7.0 s 区间内）** |

### 4.2 断裂结论（`srt_crosscheck_v1.json`）

| 字段 | 现件申报值 | 我的独立复算 | 依据 | 判定 |
|---|---|---|---|---|
| `cross_cut_spans` | 0 | **0**（无任何 cue 跨 11 个切点） | 我的 Python 算术 | **PASS** |
| `overlaps` | 0 | **0**（51 条 cue 严格 `next.start ≥ cur.end`） | 我的解析 | **PASS** |
| `timing_problems` | 0 | **0**（无非正时长） | 我的解析 | **PASS** |
| `gap_problems` | 0 | **0**（无非单调/断裂） | 我的解析 | **PASS** |
| **`problems` 数组（我自己再数一遍）** | `[]` | **我自己独立读该 JSON，确认 `problems` 是 list 且 `len == 0`（空数组）** | 同上 crosscheck JSON | **PASS（0 条，与 `pass:true` 自洽）** |
| `pass` | `true` | `true`，且与上面 4 个 0 值一致，无自相矛盾 | 同上 | **PASS** |
| `stats_match` | `true` | `true`（`stats_declared_count` 51 == 我的实测 51） | 同上 | **PASS** |

**断裂结论：SRT 零断裂。** 四类问题计数全 0、`problems` 空数组、`pass: true`，且我用独立解析器从原始 SRT 复算，得到完全相同的结论（0 重叠、0 非法时长、0 越界、0 空文本、编号连续）。不存在字幕断裂。

### 4.3 溯源抽查（我加的独立核验）

| 检查项 | 我的实测值 | 依据 | 判定 |
|---|---|---|---|
| 51 条 cue 文本是否逐字来自原始转写 | **51 / 51 全部**能在 `source_transcript.json` 的 segments 文本中**精确整段匹配**（零改写、零幻觉新词） | 我的 Python 规范化匹配 | **PASS（溯源完整）** |

这是对「字幕不是凭空生成」的有力佐证：51 条 cue 无一条是源文本的改写或新增。

### 4.4 `dropped_*` 合理性与台账闭合性 —— 本项的 WARN

先给结论：**SRT 成品本身全项通过；但 `stats.json` 的丢弃台账不闭合，且 6 个数字里有 2 个无法从所声明的源复现。** 这是**记录可追溯性**问题，不影响 SRT 质量，故记 WARN 而非 FAIL。

**(a) 算术不闭合。** 题述给的公式 180 −（14+46+24+15）− … 实测如下：

| 口径 | 数值 | 说明 |
|---|---|---|
| 源段数 | 180 | 实测 = stats 申报 |
| 四类丢弃之和 | 99（14+46+24+15） | 实测自 stats |
| 180 − 99 | 81 | 应剩的段数 |
| 81 + split 6 | **87** | 隐含应产出 87 条 cue |
| **实际 cue 数** | **51** | 实测 |
| **缺口** | **−36 条无法解释** | |

**(b) 台账口径根本搞错了分母。** 关键实测：180 段里**只有 92 段**完整落在 12 个保留源区间内，**98 段**与保留区间相交但**跨越切口**（在节目里根本不存在），其余 82 段完全在保留区间之外。也就是说：

- 真正可用的分母是 **92 段，不是 180 段**；
- 其余 88 段是被**剪辑本身**（源 1152.2 s 只取 614.9 s）删掉的，**与文本质量无关**；
- 而 stats 把丢弃原因算在 180 的基数上，**99 > 92** ⇒ 证明四类丢弃**互相重叠计数**（同一段可同时命中「低置信」和「填充/过短」），不能按求和读。

所以「180 → 51」这个说法本身是误导性的：真实链路是 **180 →（剪辑去 88）→ 92 →（文本过滤去 41）→ 51**。

**(c) 逐项复现结果：**

| 申报项 | 申报值 | 我的复现 | 判定 |
|---|---|---|---|
| `dropped_hallucination_loop` | 24 | 全 180 段中「同一文本出现 > 2 次」的段数 = **23**（另有 `-` 占位符单独出现 14 次）；另有 155 个去重文本 | **WARN（量级吻合，差 1，可信）** |
| `dropped_low_confidence` | 46 | `avg_logprob` 全部 180 段 min/max = −0.757/−0.266：< −0.6 有 **34** 段，< −0.7 仅 **3** 段，< −0.8 有 **0** 段。**没有任何单一 logprob 门限能得出 46**（须是 logprob ∪ no_speech 的复合规则，stats 未记录门限） | **WARN（不可复现）** |
| `dropped_filler_or_short` | 15 | 段长分布 min/max = 0.40/43.22 s：< 1.0 s 仅 **5** 段，< 0.8 s 仅 **2** 段，< 0.5 s 仅 **1** 段。**「过短」最多解释 5 条，其余 ≥10 条必来自「填充词」关键词规则（规则未记录）** | **WARN（不可复现）** |
| `dropped_empty` | 14 | **`source_transcript.json` 的 180 段中空文本段数 = 0**。14 条「空」必然是指**剥掉填充词/括号噪声之后**才变空的中间态，stats 未说明该口径 | **WARN（不可复现）** |
| `split_at_cut` | 6 | **0 条 cue 是切分碎片**：51 条 cue 文本**全部**精确等于某个完整源段文本（碎片如「得做好」不可能整段匹配）。切分半句在本 SRT 中**没有留下任何文本痕迹** | **WARN（证据缺失）** |
| `cross_cut_spans` | 0 | 我的独立复算 = 0 | **PASS** |

**(d) 建议（不阻塞本版预览）**：让 `stats.json` 补上 ① 真实分母 92 与「被剪辑删除 88」的独立计数；② 丢弃改为**互斥归类**（每段只计一次首选原因）使求和能闭合；③ 显式记录 `avg_logprob` / `no_speech_prob` / 段长 / 填充词表的**具体门限**；④ `split_at_cut: 6` 要么给出 6 个切分碎片的实际证据，要么改数。现状下**「51 条」这个交付数字是可信的**（三方对账 + 溯源 51/51），只是**「为什么只留下 51 条」的解释链目前不可复算**。

---

## 5. 零字幕流 + 零烧录

| 检查项 | 我的实测值 | 依据 | 判定 |
|---|---|---|---|
| **subtitle 流数量（我自己查，未采信现成 JSON）** | **0**。我的命令 `ffprobe -v error -select_streams s -show_entries stream=index,codec_name,codec_type -of csv=p=0 <mp4>` 输出 **0 行** | `C:\Project\永劫无间\123\21.864永劫无间 2026-09-30 02-57-13\preview\864-review-v1.mp4`，ffprobe 来自 `C:\Project\永劫无间\.video-tools\LosslessCut\resources\` | **PASS（必须为 0，实为 0）** |
| 全部流清单 | 只有 `0,h264,video` 和 `1,aac,audio` 两条 | 同上，`-show_entries stream=index,codec_type,codec_name` | **PASS** |
| `format.nb_streams` | **2** | 同上 | **PASS** |
| 章节轨 / 隐藏轨 | `-show_chapters` 输出为空，无 data / attachment 轨 | 同上 | **PASS** |
| 视频流字幕相关 disposition | `captioned`=0，`descriptions`=0（其余 subtitle 字段 ffprobe 未单独暴露，值为 0） | 同上，`-select_streams v -show_entries stream_disposition=…` | **PASS** |
| **预览旁无 `.srt` 兄弟文件** | `preview\` 下**共 2 个文件**：`864-review-v1.mp4`（802,410,248 B）、`864-review-v1.decode.log`（3 B）。**无任何 `.srt` / `.ass` / `.vtt` / `.sub`** | 递归 `Get-ChildItem` on `C:\Project\永劫无间\123\21.864永劫无间 2026-09-30 02-57-13\preview\` | **PASS** |
| 干净画面 + 只有音频轨 | 视频 h264 单轨 + 音频 aac 单轨；无字幕流、无第二视频轨、无时间线轨 | 同上 ffprobe | **PASS** |
| 全 TASK 内字幕文件总数 | **1**：`captions\864-review-v1.srt`（2923 字节）。**外挂字幕只住在 `captions\`** | 递归扫描 `C:\Project\永劫无间\123\21.864永劫无间 2026-09-30 02-57-13` 全目录 | **PASS** |
| `preview\` 下 `*burn*` / `*sub*` / `*caption*` / `*字幕*` / `*title*` / `*soft*` 命名产物 | **0 个** | 同上，限定 `preview\` 递归 | **PASS** |
| 现成 log 的第三方佐证 | `[out#0/null] video:14988KiB audio:115360KiB **subtitle:0KiB** other streams:0KiB` | `C:\Project\永劫无间\123\21.864永劫无间 2026-09-30 02-57-13\reports\preview_media_filters_v1.log` 第 30 行 | **PASS（独立佐证 subtitle 0 KiB）** |
| stats 自述交付方式 | `"mode": "external sidecar SRT (no burn, no mux)"` | `C:\Project\永劫无间\123\21.864永劫无间 2026-09-30 02-57-13\captions\864-review-v1.stats.json` 第 17 行 | **PASS（与实测一致）** |

**明确结论（按要求逐字写清）：**

> **这一版预览 `preview\864-review-v1.mp4` 是「零字幕流、零烧录」。** MP4 容器内**没有任何 `codec_type == "subtitle"` 的流**（我自己的 ffprobe 查得 0 条，`nb_streams` 仅 2 = 1 视频 + 1 音频），画面上**没有任何烧录的像素字幕**（无 `*burn*` 渲染产物、`preview\` 下不存在任何字幕类命名文件、也无 `.srt` 兄弟文件），**字幕只以外挂 SRT 交付**，唯一载体是 `C:\Project\永劫无间\123\21.864永劫无间 2026-09-30 02-57-13\captions\864-review-v1.srt`（51 条，2923 字节），由播放器按需挂载。**不存在烧录版，也不存在内嵌软字幕版。**
>
> 因此 `gate_burned_srt` 的 WARN「没有 master」不指向本预览有任何字幕污染问题：它反映的是**外挂 SRT 没有与视频同名的 master 伴随文件**这一形态事实，而形态本身就是本项目规定的正确形态（AGENTS.md §5 禁烧录禁内嵌）。**零字幕流 + 零烧录 = PASS。**

---

## 汇总

| # | 验收项 | 判定 | 关键数字 |
|---|---|---|---|
| 1 | 存在性 + 体积（720p / 60fps CFR / H.264 / 非 4K） | **PASS** | 802,410,248 B；1280×720；60/1=60/1；nb_frames 36894；h264 High；duration 614.921333；bit_rate 10,439,192 |
| 2 | 解码 | **PASS（含 1 处 WARN）** | 我的 decode：退出码 0、stderr 0 行 0 字节、14.9 s；与 `decode.log`（3 B 纯 BOM）一致。blackdetect 1 段 598.371029–600.271029（1.9 s）双参数复现一致；freezedetect 1 段 598.371029–599.537695（1.166667 s）。WARN = 现成 log 漏抄 `freeze_end`/`freeze_duration`。**黑屏裁定：游戏原生终局结算过场，非剪辑缺陷**（源 1095.871–1097.771 落在 combat_011 段内，距最近切点 4.929 s，`deleted_intervals` 无覆盖，且 `boundary_reason` 明文「绝不能切…全部保留在段内」） |
| 3 | 时长对照 | **PASS** | format 614.921333 vs 节目 614.9 = **+0.021333 s**（远小于 ±0.3 s）；视频 614.900000 vs 音频 614.921333 = **0.021333 s**；36894÷60 = 614.900000 精确闭环 |
| 4 | 字幕条数 + 断裂 | **PASS（WARN 在台账可追溯性）** | 实测 51 条 = stats 51 = crosscheck 51；源 180 段 = stats 180；51/51 逐字溯源成功。断裂四项全 **0**，`problems` **空数组**（我独立复数），`pass: true`。WARN：`dropped_*` 台账不闭合（99 与 92 分母矛盾 ⇒ 重叠计数；缺口 −36），且 `dropped_low_confidence: 46` / `dropped_empty: 14` / `split_at_cut: 6` 三项**无法从所声明源复现**（logprob 无门限可得 46；源文件空文本实为 0；0 条 cue 是切分碎片） |
| 5 | 零字幕流 + 零烧录 | **PASS** | subtitle 流 **0**（我自己的 ffprobe）；`nb_streams` 2（h264+aac）；`preview\` 仅 2 文件（mp4 + 3 B log），**无 .srt 兄弟**；全 TASK 字幕文件仅 1 个且住在 `captions\`；`preview\` 下 burn/sub/字幕 命名产物 **0**；现成 log 独立佐证 `subtitle:0KiB` |

**问题清单（WARN 级，不阻塞预览交付）**

1. `reports\preview_media_filters_v1.log` 的 freezedetect 段只抄了 `freeze_start: 598.371029`，缺 `freeze_end: 599.537695` 与 `freeze_duration: 1.166667`（我的复跑已补齐数值，记在此处供回填）。
2. `captions\864-review-v1.stats.json` 的丢弃台账不闭合、门限未记录，且 `split_at_cut: 6` 无文本证据。**「51 条」这一交付数字本身三方对账一致且 51/51 溯源成功，不受影响**；受影响的是「为什么只留 51 条」的可复算性。建议在下一版 stats 中：把分母从 180 改为真实的 92（另计「被剪辑删除 88」）、丢弃改为互斥归类、显式写出 `avg_logprob` / `no_speech_prob` / 段长 / 填充词表门限、并给出或撤销 `split_at_cut: 6`。

**未做的事（纪律声明）**：未渲染任何视频（`-f null` 为解码检验，不产生文件）、未安装、未新建环境、未改动任何既有文件、未查看任何图片（0 张）。除本报告外唯一的磁盘写入是 `%LOCALAPPDATA%\Temp\opencode\` 下我自己的临时 stdout/stderr 捕获与只读分析脚本。

---

STATUS: PASS
