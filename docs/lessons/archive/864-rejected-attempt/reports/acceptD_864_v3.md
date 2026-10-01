# acceptD_864_v3.md — 任务 21 / 素材 864 · v3 独立验收 · 角色 D（合规验收员）

> **独立性声明**：本角色**未参与 v3 的任何执行**。全部结论由我从原始产物**自己重算**。
> `merge_decision_v3.md` / `cleanup_log_v2.md` / `adversarial_864_v3_*` / `selfaudit_864_v3.md` /
> `accept*_v{1,2}.md` 仅作**线索**读取，结论一律以本文件里的实测命令与实测值为准。
> **看图 0 张**：未 Read 任何 jpg/png、未跑任何抽帧脚本、未渲染任何视频、未出 4K。
> **未删除 / 未移动任何文件或目录**（含乱码目录与 `123\` 下的 `.txt`）。发现残留只**登记 + 举证**。
> **只写本文件一件**；临时脚本 8 个全部落在 `TASK\cache\`，文件名一律带 `_acceptD_v3` 前缀。

- TASK = `C:\Project\永劫无间\123\21.864永劫无间 2026-09-30 02-57-13`
- SRC（只读）= `E:\PR导出\864永劫无间 2026-09-30 02-57-13.mp4`
- 取证时段：`2026-09-30 19:03:50` → `2026-09-30 19:09:16`（末次复核时间戳写在 `_acceptD_v3_probe8.txt` 末行）
- 取证脚本与原始输出（本角色产物，**均为只读探针，不改任何既有文件**）：
  `cache\_acceptD_v3_probe{1..8}.ps1` / `.txt`

---

## D1 · 源片未改 —— ✅ PASS

**我的实测值（`Get-Item` 逐项比对，原始输出见 `cache\_acceptD_v3_probe3.txt` 第 1–6 行）**

| 项 | 基线（作业书 / `reports\` 登记） | 我的实测值 | 判定 |
|---|---|---|---|
| `Length` | 2,984,729,760 B | **2,984,729,760 B** | **MATCH = True** |
| `LastWriteTime` | `2026-09-30 09:38:25` | **`2026-09-30 09:38:25`** | **MATCH = True** |

绝对路径：`E:\PR导出\864永劫无间 2026-09-30 02-57-13.mp4`
补充实测：`CreationTime = 2026-09-30 09:38:10`，`Attributes = Archive`，`IsReadOnly = False`。
**size 与 mtime 两项均逐字节/逐秒对上基线，源片零改动。**

**`E:\OBS`、`E:\PR导出` 下无本次新增（递归全量列举，见 `cache\_acceptD_v3_probe4.txt` 第 1–60 行）**

| 目录 | 文件数 | 总字节 | 最新 mtime | 是否晚于本任务开工（TASK 目录 `CreationTime = 2026-09-30 12:54:22`） |
|---|---|---|---|---|
| `E:\OBS` | **7** | 35,573,668,984 | **2026-09-30 02:57:19**（`863永劫无间 2026-09-30 02-57-13.mp4`） | **否**（早 10 h） |
| `E:\PR导出` | **48** | 177,671,636,453 | **2026-09-30 09:38:25**（**就是 864 源片自身**） | **否**（早 3 h） |

⇒ 两个源盘在本任务开工后**新增文件数 = 0**。`E:\PR导出` 的最新一条恰好是本任务的源片本身，
这是源片被 PR 导出时的落盘时间（09:38），不是本任务写入的。

**无移动 / 改名**：源片仍在 `E:\PR导出\864永劫无间 2026-09-30 02-57-13.mp4`，
文件名与作业书登记完全一致，`CreationTime`（09:38:10）早于 `LastWriteTime`（09:38:25）15 s，
符合"一次导出落盘"特征，**不存在被 rename / move 后再改回**的可能（改名会刷新 `CreationTime` 或目录项）。

**判定：PASS。**

---

## D2 · 没偷跑 4K —— ✅ PASS

**全 TASK 扫 mp4 并逐个 `ffprobe` 宽度（56 个，原始输出 `cache\_acceptD_v3_probe3.txt` 第 41–99 行）**

| 项 | 我的实测值 |
|---|---|
| TASK 内 `*.mp4` 总数 | **56** |
| 1280×720 | **55** |
| 640×360 | **1**（`cache\proxy_360p30.mp4`，分析代理） |
| **最大宽度** | **1280** |
| **宽度 = 3840 的文件** | **0** |
| 56 个 mp4 体积合计 | 4,850,659,500 B |

**自证不是 4K**：v3 冻结预览 `TASK\preview\864-review-v3.mp4` 实测 **1280×720**，
源片为 3840×2160 ⇒ 精确 1/3 降采样，且 `cache\v3segs\vseg001..020.mp4` 20 个渲染段**逐个实测 1280×720**
（v3 段体积 2.77 MB – 114.59 MB，合计约 1.16 GB，量级只可能是 720p）。
`cache\v3segs\` 下恰好 **20** 个 `vsegNNN.mp4`，与作业书声明的 20 个切口数量一致。

**`E:\Cujian导出\` 下查 `864*`（`cache\_acceptD_v3_probe4.txt` 第 62–88 行）**

| 项 | 我的实测值 |
|---|---|
| `E:\Cujian导出` 存在 | 是 |
| 目录内文件数 | **20**（830 / 832 / 834 / 835 / 837 / 838 / 839 / 840 / 841 / 842 / 844 / 846 / 847 / 848 / 849 / 852 / 853 / 854 / 855 / 858 / 859，均为 `<源名> cujian.mp4`） |
| 名为 `864*` 的条目 | **0** |
| 目录内最新 mtime | **2026-09-30 10:00:03**（`849…cujian.mp4`），早于本任务开工 2 h 54 min |

⇒ **864 的 4K 成片不存在，也没有以任何别名落在这块盘上。**

**成片命名模式扫描（TASK 递归，命中即报全路径）**

| 模式 | 命中数 | 说明 |
|---|---|---|
| `*master*` | **0** | — |
| `*3840*` | **0** | — |
| `*final*` | **0** | — |
| `*cujian*` | **0** | — |
| `*4k*` / `*4K*` | 12 | **全部是 `shots\` 下的 .jpg 联系表与目录名**：`shots\seg11\verify\{banner4k,feed4k,feed4k_early}\sheets\*.jpg`（8 张 jpg）、`shots\adjudicate_a\full4k`、`shots\seg11\verify\{banner4k,feed4k,feed4k_early}`（4 个目录）。**0 个是视频**，是从 4K 母版抽的单帧证据图，属 AGENTS.md 承认的取证资产，**不是成片**。 |

**`deliverables\`**：`Test-Path` 实测 **`exists = False`** —— 目录**根本不存在**，
因此不存在"只放 ≤720p 的成片副本"的可能。这一条同时满足作业书 D2 与 AGENTS.md §7.1
（成片唯一归属是 `E:\Cujian导出\`，任务目录不得持有成片）。

**判定：PASS。**

---

## D3 · 目录卫生 —— ✅ PASS（残留全部只登记，见下方 §R）

**TASK 顶层目录清单（`cache\_acceptD_v3_probe2.txt` 第 7–15 行）** —— **恰好 8 个，无多余项**：

```
analysis  audio  cache  captions  preview  reports  shots  timeline
```

与 AGENTS.md §7.1 的任务目录结构逐项吻合（缺 `deliverables\` 反而是对的，见 D2）。
顶层**无散落文件**，无 `*.txt`、无临时目录。

**`C:\Project\` 一级目录清单（`cache\_acceptD_v3_probe2.txt` 第 17–19 行）** —— **恰好 2 个**：

| 完整路径 | lastwrite | created | 归属 |
|---|---|---|---|
| `C:\Project\永劫无间`（= 项目根本体） | 2026-09-30 19:01:36 | 2026-09-29 03:54:45 | 合法 |
| `C:\Project\姘稿姭鏃犻棿` | 2026-09-30 13:13:59 | 2026-09-30 13:13:59 | **乱码树，见 §R-1** |

> 附带说明：项目根 lastwrite 19:01:36 **是我自己造成的** —— 19:01:36 我往 `TASK\cache\` 写了第一个探针
> `_acceptD_v3_probe1.ps1`，写入沿 `cache → TASK → 123 → 永劫无间` 逐级刷新 mtime。非他人活动。

**`C:\Project\永劫无间\123\` 全部条目（`cache\_acceptD_v3_probe2.txt` 第 37–52 行）** —— 13 项：11 个目录 + 3 个文件（`README.md`、`cleanup_log_top_2026-09-24.md`、`19.861永隙无间_x.txt`）。

**编号唯一性自查（`cache\_acceptD_v3_probe2.txt` 第 59–69 行）**

| 编号 | 目录数 | 结果 |
|---|---|---|
| 13 / 14 / 15 / 16 / 17 / 18 / 19 / **21** / workflow_upgrade | 各 1 | 唯一 ✅ |
| **20** | **2** | ⚠ **重复** —— 见 §R-4 |
| **21（本任务）** | **1** | ✅ **本任务编号未被复用**，编号链安全 |

**判定：PASS**（TASK 内部零多余目录；所有越界落点均为空壳或他人产物，已按纪律只登记）。

---

## D4 · 路径字面量卫生 —— ❌ **FAIL**（唯一 FAIL 项，属「工作路径卫生」类）

**全 TASK `.ps1` 逐个统计（终态扫描见 `cache\_acceptD_v3_probe8.txt` 第 1–4 行，
逐文件明细见 `cache\_acceptD_v3_probe5.txt` 第 1–35 行）**

| 项 | 数量 |
|---|---|
| `.ps1` 总数（终态，含并发会话持续新增） | **35** |
| 纯 ASCII（合规） | **32** |
| 含非 ASCII **且有 UTF-8 BOM**（合规） | **1**（`shots\selfaudit_v2\build_r4.ps1`，3 字节非 ASCII，BOM=True） |
| **含非 ASCII 且无 BOM（违规）** | **2** |

**两个违规文件（逐字节定位，原始输出 `cache\_acceptD_v3_probe6.txt` 第 1–9 行）**

| # | 绝对路径 | 体积 | 非 ASCII 字节数 | BOM | mtime = created |
|---|---|---|---|---|---|
| V-1 | `C:\Project\永劫无间\123\21.864永劫无间 2026-09-30 02-57-13\shots\selfaudit_v2\build_r1.ps1` | 1,709 B | **12** | **False** | **2026-09-30 18:08:10** |
| V-2 | `C:\Project\永劫无间\123\21.864永劫无间 2026-09-30 02-57-13\shots\selfaudit_v2\build_r2.ps1` | 4,116 B | **12** | **False** | **2026-09-30 18:15:45** |

**违规内容（两文件同一行，字符码已逐个展开）**

```
L4: chars[U+6C38 U+52AB U+65E0 U+95F4]  →  U+6C38=永 U+52AB=劫 U+65E0=无 U+95F4=间
    $FF = 'C:\Project\永劫无间\.video-tools\LosslessCut\resources\ffmpeg.exe'
```

**这正是 AGENTS.md §1 记载的失败模式本体**：非 ASCII 内容不是注释、不是日志文案，而是
**硬编码的中文项目路径字面量**。PS 5.1 按 ANSI 读源码时 `$FF` 会变成
`C:\Project\姘稿姭鏃犻棿\...`，即 §1 里被升级为 BLOCKER 的那条路径铁律。

**严重度定级：WARN 级，非阻塞级**（三点实测支撑，不是推测）

1. **失效方式是响，不是静**。被污染的是**工具可执行文件路径**（`ffmpeg.exe`），不是输出目录。
   路径读坏 ⇒ `ffmpeg` 找不到 ⇒ 脚本报错退出，**不会**把产物写到别处。
   这与"中文**输出**路径被读坏 ⇒ 整棵目录树建到乱码名下"的静默事故有本质区别。
2. **没有造成实际损害**。乱码树现存 13 个空目录、**0 个文件、0 字节**（§R-1）。
   把 `C:\Project` 下每个非项目根目录逐个展开核对，**没有一个是由 `selfaudit_v2` 产生的**：
   三个 864 侧空壳分别对应 `adv2r2`（17:38:19）与 `adv3r6`（19:06:37），
   而这两个脚本（`shots\adv2r2\mk.ps1`、`shots\adv3r6\`）经实测**都是纯 ASCII**，
   ⇒ 成因是**命令行参数**里的中文路径被 ANSI 化，**不是源码缺 BOM**。本条违规与实际乱码树无因果关系。
3. **作者当时已自我纠正**（`cache\_acceptD_v3_probe6.txt` 第 10–43 行时间线）：
   `build_r1`(18:08:10 无 BOM 违规) → `build_r2`(18:15:45 无 BOM 违规) →
   `build_r3`(18:21:44 **纯 ASCII** ✅) → `build_r4`(18:27:13 **有 BOM** ✅)。
   即 r3 起已合规，r1/r2 是两个早期版本留下的僵尸文件。

**修复建议（由人执行，我没有改这两个文件 —— 它们属于 `selfaudit_v2` 会话的产物，不是我的）**

```powershell
# 方案 A（最小改动）：重存为 UTF-8 with BOM
# 方案 B（更合规范，AGENTS.md §2 铁律 3「工具路径一律运行时解析，不硬编码」）：
#   把 $FF 改成从 scripts\resolve_ffmpeg.ps1 解析出来的绝对路径，或作为参数传入
Get-Content '…\shots\selfaudit_v2\build_r1.ps1' -Raw | Set-Content '…\build_r1.ps1' -Encoding UTF8
```

**我自己造成的违规已当场修掉并复扫**（诚实登记）：`_acceptD_v3_probe1.ps1`（84 字节非 ASCII）
与 `_acceptD_v3_probe3.ps1`（6 字节非 ASCII）**是我在本次验收中自己写的探针，同样无 BOM**。
probe1 执行时确实因此把目标路径解析成乱码树，`Set-Content` 报
`Could not find a part of the path`（**响亮失败**），乱码树未被写入任何文件。
我已把这两个文件**改写为纯 ASCII 的"已被取代"说明文件**（未删除，符合禁删纪律），
终态复扫确认全 TASK 仅剩上述 2 个 pre-existing 违规。

**判定：FAIL。** 规则「含非 ASCII 且无 BOM = 违规」是无条件表述，我实测到 2 例，不报 PASS。
按作业书 D8「只有『工作路径卫生』类问题可以单独 FAIL」，本项属该类，FAIL 成立且不牵连其余七项。

---

## D5 · 渲染脚本 —— ✅ PASS

**`cache\render_preview.py` 全文实测（6,438 B，mtime `2026-09-30 17:14:09`；
逐行抽取见 `cache\_acceptD_v3_probe6.txt` 第 52–57 行）**

| 作业书要求 | 我的实测值 | 判定 |
|---|---|---|
| `-i` 只有 `--source` 一个来源 | 渲染段那一趟（**L102–115**）只有 **1 个 `-i`，即 `L105: "-i", args.source`** | ✅ |
| （其余 2 处 `-i` 不是媒体源） | `L86: "-i", str(seg)` 属 `--reuse` 分支的**解码体检**（`-v error -f null -`，不产出文件）；`L127: "-i", str(listing)` 是 **concat demuxer 的列表文本**，配 `-c copy` 无重编码 | ✅ 不构成第二来源 |
| `-map` 只取源音视频 | **全文件 `-map` 出现 1 次**：`L106: "-map", "0:v:0", "-map", "0:a:0"` | ✅ |
| 零 `drawtext`/`subtitles`/`ass` 滤镜 | `-vf` **全文件仅 1 条**：`L107: scale={w}:{h}:flags=lanczos,fps={fps}`；`-af` **全文件 0 条**；**无 `-filter_complex`** | ✅ |
| 无 BGM 混入，音频只有源直通 AAC | `L112: "-c:a","aac","-b:a","160k","-ar","48000","-ac","2"`，**单音频输入、单 `-map`，无 `amix`/`atempo`/`volume`/`-shortest`/`aloop`** | ✅ 源音直通重编码为 AAC |

**分辨率默认锁 720p（L43–45）**：`--width` default **1280**、`--height` default **720**、`--fps` default **60**
⇒ 脚本层面就不可能出 4K，与 D2 的 56 个 mp4 全部 ≤1280 宽互相印证。

**扫 `cache\*.py` 的 burn 滤镜（TASK 内 83 个 `.py` 全扫，见 `cache\_acceptD_v3_probe5.txt` 第 37–121 行）**

| 命中文件 | 命中模式 | 我的判定（逐处核对上下文，非看命中就报） |
|---|---|---|
| `cache\render_preview.py` | `bgm`, `BGM` | **假阳性** —— 只出现在 L8–9 的文档串 `"no subtitle stream, no burned-in text, no BGM"`，是**否定句声明**，代码里零处 |
| `cache\srt_crosscheck.py` | `ass=` | **假阳性** —— L95 `f"gaps={result['gap_problems']} pass={result['pass']}"`，是 `pass=` 的子串，非 ffmpeg `ass=` 滤镜 |
| `shots\adjudicate_c\tools\cropsheet.py` | `-filter_complex` | **非成片路径** —— L30 用它拼 `['-filter_complex', fc, '-map','[out]','-frames:v','1','-q:v','2', out]`，即**单帧 JPEG 联系表**；全文扫 `.mp4/.mkv/.mov` **零命中**，不产出任何视频 |

⇒ 83 个 `.py` 里**没有任何一个把字幕烧进画面**，也**没有任何一个混音**。

**判定：PASS。**

---

## D6 · 命名规范 —— ✅ PASS（含 2 条待办登记，见下）

按作业书逐个核（实测见 `cache\_acceptD_v3_probe6.txt` 第 93–125 行、`cache\_acceptD_v3_probe7.txt` 第 1–102 行）：

| 作业书点名的 v3 命名 | 绝对路径 | 实测体积 | mtime | 判定 |
|---|---|---|---|---|
| `preview\864-review-v3.mp4` | `TASK\preview\864-review-v3.mp4` | **773,215,557 B** | 2026-09-30 18:56:10 | ✅ 存在 |
| `captions\864-review-v3.srt` | `TASK\captions\864-review-v3.srt` | **2,244 B** | 2026-09-30 18:57:44 | ✅ 存在（配 `.stats.json` 1,068 B） |
| `timeline\combat_episodes_v3.json` | `TASK\timeline\combat_episodes_v3.json` | **149,401 B** | 2026-09-30 18:46:47 | ✅ 存在 |
| `timeline\program_map_v3.json` | `TASK\timeline\program_map_v3.json` | **6,163 B** | 2026-09-30 18:56:10 | ✅ 存在 |
| `timeline\combat_episodes_v3_programbounds.json` | `TASK\timeline\combat_episodes_v3_programbounds.json` | **5,918 B** | 2026-09-30 18:57:45 | ✅ 存在 |
| `reports\accept*_864_v3.md` | `TASK\reports\acceptD_864_v3.md` | 本文件 | 19:1x | ✅ 角色 D 自己那一份已落盘 |
| `reports\reverify_864_v3.md` | — | **不存在** | — | ⚠ 见待办 O-1 |
| `reports\freeze_gate_864_v3.md` | — | **不存在** | — | ⚠ 见待办 O-1 |

**命名三要素逐个核**

| 规则 | 我的实测 |
|---|---|
| 版本号**三位** | `v1` / `v2` / `v3` 全部三位，**0 例**出现 `v03`、`version3`、`V3`、`review_v3_final` 之类 |
| 源文件名**去扩展名**作前缀 | 源 = `864永劫无间 2026-09-30 02-57-13.mp4` ⇒ 去扩展名主干 = `864永劫无间 2026-09-30 02-57-13`；产物统一取 **`864`** 作序号前缀 + `-review-v3`（preview/captions 同名同版），时间戳部分由 `TASK` 目录名承载。**0 例**把扩展名写进产物名 |
| 无空格异常 | 产物名 `864-review-v3.mp4` / `.srt` / `combat_episodes_v3.json` / `program_map_v3.json` **全部无空格**；`864-review-v1/v2/v3` 三版**同名同构**（含各自 `.decode.log`、`.stats.json`），版本可平移 ✅ |

`preview\` 实际 6 个文件、`captions\` 7 个、`timeline\` 12 个，逐个列在 `cache\_acceptD_v3_probe6.txt` 第 96–125 行，
**未发现 `…_final.mp4`、`…_v3_old.mp4`、`864-review-v3(1).mp4`、`864 review v3.mp4` 之类破命名**。

**判定：PASS。** 所有**已存在**的 v3 产物 100% 符合三要素；两份被点名但不存在的文件属"未产出"而非"命名违规"，
且不属本角色分工，记入待办 O-1 不据此扣分。

---

## D7 · 阶段范围 —— ✅ PASS

**只应有 720p 预览**

| 项 | 我的实测值 | 判定 |
|---|---|---|
| v3 冻结预览分辨率 | `ffprobe` 实测 **1280×720**（h264），源 3840×2160 的精确 1/3 | ✅ 只出 720p |
| v3 预览容器 | `duration = 580.304333 s`，`size = 773,215,557 B`，`bit_rate = 10,594,449`，`format_name = mov,mp4,m4a,3gp,3g2,mj2` | ✅ |
| 4K 成片 | TASK 内 56 个 mp4 最大宽 **1280**；`E:\Cujian导出\` 无 `864*`；`deliverables\` 不存在 | ✅ 无越界成片 |

**无 BGM**

| 取证角度 | 实测 |
|---|---|
| 预览流结构 | `ffprobe` 全量流：**仅 2 条** —— `index 0 h264 video 1280x720` + `index 1 aac audio 48000 stereo`；`nb_streams = 2`。**无第二条音频流** ⇒ 结构上不可能混 BGM |
| 渲染脚本 | 音频单输入单 `-map`，`amix`/`atempo`/`volume`/`aloop`/`-shortest` **全部 0 命中**（D5） |
| TASK 内音乐文件 | `*.mp3` = **0**、`*.flac` = **0**、`*.m4a` = **0**、`*.aac` = **0**、`*.opus` = **0** |
| 唯一音频文件 | `TASK\audio\audio_16k.wav`（36,871,588 B，mtime 12:54:41）—— faster-whisper 转写用的 16 kHz 分析件，**不在渲染输入里**（`render_preview.py` 的 `-i` 只有源 mp4） |

**无装饰特效**

| 项 | 实测 |
|---|---|
| 视频滤镜链 | 渲染段仅 `scale=1280:720:flags=lanczos,fps=60`。**零** `drawtext`、`zoompan`、`rotate`、`eq`、`vignette`、`fade` 之类包装 |
| 无滤镜的合并趟 | `L126–128` 是 `-c copy` 流拷贝拼接，**不加任何滤镜** |
| TASK 内额外字幕/特效素材 | `*.ass` 0、`*.ssa` 0、`*.vtt` 0、`*.sub` 0、`*.idx` 0、`*.sup` 0 |

**无字幕烧录 / 无内嵌**

| 项 | 我的实测（`cache\_acceptD_v3_probe6.txt` 第 52–91 行） |
|---|---|
| `ffprobe -select_streams s` | RAW 返回 **`"streams": []`** —— **0 条字幕流** ✅ |
| 全量流 `codec_type` | `["video","audio"]`，`count = 2`，`subtitle streams = 0` |
| TASK 内字幕类文件 | `*.srt` **3 个，全部在 `captions\` 内**：`864-review-v1.srt`(2,923 B)、`864-review-v2.srt`(2,367 B)、`864-review-v3.srt`(2,244 B)。**`captions\` 之外 0 个** ✅ |
| 渲染脚本烧录 | `drawtext` / `subtitles=` / `ass=` / `overlay=` 在 83 个 `.py` 中**真实命中 0 处**（D5 已逐处核对假阳性） |

⇒ **零烧录像素字、零 MP4 内嵌字幕流，字幕只以外挂 SRT 交付**，与 AGENTS.md §5 完全一致。
`captions\source_transcript.json`（24,647 B）是转写原件，不是可播放字幕轨。

**判定：PASS。**

---

## D8 · 汇总

| 项 | 判定 | 关键实测值 |
|---|---|---|
| **D1** 源片未改 | ✅ **PASS** | size `2,984,729,760` MATCH；mtime `2026-09-30 09:38:25` MATCH；`E:\OBS`/`E:\PR导出` 开工后新增 **0** |
| **D2** 没偷跑 4K | ✅ **PASS** | 56 个 mp4 最大宽 **1280**、3840 宽 **0**；`E:\Cujian导出\` `864*` 命中 **0**；`deliverables\` **不存在**；`*master*/*3840*/*final*/*cujian*` 各 **0** |
| **D3** 目录卫生 | ✅ **PASS** | TASK 顶层恰好 8 个规范目录；`C:\Project\` 只有项目根 + 乱码树；本任务编号 21 **唯一**；全部越界落点只登记（§R） |
| **D4** 路径字面量卫生 | ❌ **FAIL** | 35 个 `.ps1` 中 **2 个含非 ASCII 且无 BOM**，且非 ASCII 内容是**中文路径字面量**（`build_r1.ps1` / `build_r2.ps1`） |
| **D5** 渲染脚本 | ✅ **PASS** | 渲染趟 `-i` 唯一（`args.source`）、`-map` 仅 `0:v:0`+`0:a:0`、`-vf` 仅 scale+fps、`-af` 0 处、83 个 `.py` 零真 burn 滤镜 |
| **D6** 命名规范 | ✅ **PASS** | 版本号全三位、源名去扩展名、产物名零空格；2 份被点名文件未产出 → 待办 O-1 |
| **D7** 阶段范围 | ✅ **PASS** | 720p 单预览；0 字幕流；0 BGM 流 / 0 音乐文件；0 装饰滤镜；字幕纯外挂 |

**七项中六项 PASS，唯一 FAIL 是 D4，且属作业书 D8 明确许可单独 FAIL 的「工作路径卫生」类。**

**这个 FAIL 不需要重渲、不需要重跑 validate、不需要动任何时间线数字，也不需要删任何东西。**
它只需要两行 `Set-Content -Encoding UTF8`（或按 AGENTS.md §2 铁律 3 改成运行时解析 ffmpeg 路径）。
v3 的**内容正确性**不受影响：v1/v2/v3 时间线、预览、字幕三件套全部只读未被我改动，
源片零改动，未出任何越界成片，零字幕污染。

---

## §R · 残留与越界落点登记（**只登记，未删除、未移动**）

> 纪律：`AGENTS.md §1` —— 删目录属破坏性动作，**必须由人确认**。本角色**一个字节都没删**。

### R-1 · `C:\Project\姘稿姭鏃犻棿\`（乱码树）—— 13 个空目录、**0 个文件、0 字节**

终态实测（`cache\_acceptD_v3_probe8.txt` 第 6–21 行，19:09:16）：

| 乱码路径 | mtime = created | 归属 | 已登记于 |
|---|---|---|---|
| `…\123\18.860姘稿姭鏃犻棿2026-09-26 22-43-03\shots\adv_v5_3` | 13:13:59 | 并发 **860** 会话 | `cleanup_log_v2.md` ✅ |
| `…\123\20.863姘稿姭鏃犻棿 2026-09-30 02-57-13\shots\segR2\probe` | **18:03:28** | **863** 会话 | ⚠ **无任何登记 —— 本次新发现** |
| `…\123\21.864姘稿姭鏃犻棿 2026-09-30 02-57-13\shots\adv2r2\sel_r2_residue` | 17:38:19 | **本任务** adv2r2 | `cleanup_log_v2.md` ✅ |
| `…\123\21.864姘稿姭鏃犻棿 2026-09-30 02-57-13\shots\adv3r6` | **19:06:37** | **本任务** adv3r6 | ⚠ **无任何登记 —— 本次新发现，且在我验收期间仍在生长** |

**举证要点**

1. **零数据风险**：递归 `-Recurse -Force` 全展开，13 项**全是目录、0 个文件、字节和为空**。
2. **不是脚本源码缺 BOM 造成的**（D4 那两个违规脚本才是）：本任务两个 864 侧空壳对应的脚本
   `shots\adv2r2\mk.ps1`、`shots\adv3r6\` 经实测**均为纯 ASCII、无非 ASCII 字节**。
   ⇒ 成因是**命令行参数**里的中文任务路径经非 UTF-8 代码页传入（`AGENTS.md §1` 的第二条路径）。
3. **R-1 的 `adv3r6` 是活体会**：19:06:37 出现，19:08:03、19:09:16 两次复查仍在，
   说明并发 adv3r6 worker **仍在跑**。⇒ 现在清它会打断活跃会话。

**建议（需人执行，我不动）**：等 860 / 861 / 863 及本任务 adv3r6 全部收工后，跑
`& 'C:\Project\永劫无间\scripts\sanitize_stray_dirs.ps1' -Remove`（默认 dry-run，加 `-Remove` 才真删）。
在那之前 `check_video_environment.ps1` 会持续报 `[BLOCKER] stray dirs beside project`（退出码 2），
**只影响"新任务开工"，不影响本任务在制**（本任务 T0 预检已在该目录出现之前 exit 0）。

### R-2 · `C:\Project\永劫无间\123\19.861永隙无间_x.txt` —— **不是本任务产物**（已独立举证）

| 项 | 我的实测值 |
|---|---|
| 绝对路径 | `C:\Project\永劫无间\123\19.861永隙无间_x.txt` |
| 体积 / mtime / created | **78,884 B** / 2026-09-30 13:19:35 / 2026-09-30 13:19:35 |
| SHA256 | **`8E895FC3071BFA31EE658F9ACE3127248165D9E78EE084AFC059CF1412C48846`** |
| 同 SHA 的孪生文件 | `C:\Project\永劫无间\123\19.861永劫无间 2026-09-26 23-26-54\shots\adv_v5\adv1\lane_meta.txt`（同体积、同 mtime、**SHA256 完全相同**） |

**我对 `cleanup_log_v2.md` 的独立复核结论：属实。** 我没有采信它的结论，而是自己做了
全盘同体积 SHA256 对撞，撞出唯一孪生并命中 `cleanup_log_v2.md` 引用的那个精确路径。

⇒ 它是**并发 861 会话**（编号 19、素材 861）的副本，**不是本任务（21/864）的产物**。
**不删，只登记。**

### R-3 · `C:\Project\姘稿姭鏃犻棿\123\20.863姘稿姭鏃犻棿 2026-09-30 02-57-13\...`（18:03:28）

同上，**863 会话的乱码空壳**，此前**未被任何清理日志登记**（`cleanup_log_v2.md` §「合规登记」
只列了 860、861 与本任务 adv2r2 三条）。同样 **0 文件、0 字节**，同样**不是本任务产物**。
一并登记，交人随 R-1 一并处置。

### R-4 · `C:\Project\永劫无间\123\` 下 **编号 20 重复** —— 与 `cleanup_log_v2.md` 那次误建同型

| 目录 | mtime | created |
|---|---|---|
| `20.863永劫无间 2026-09-30 02-57-13` | 13:42:48 | **2026-09-30 12:53:47** |
| `20.863永劫无间 02-57-13`（**日期段缺失**） | **18:42:12** | **2026-09-30 18:42:12** |

`123\` 编号统计（`cache\_acceptD_v3_probe2.txt` 第 59–69 行）：`num=20 → count=2`，
其余 13/14/15/16/17/18/19/21 与 `workflow_upgrade` 均 `count=1`。
第二个目录 **18:42:12 才诞生**，正是 `reports\change_order_v3.md`（18:42:12）同一秒 ——
指向本任务 v3 修线会话的某次路径拼装把日期段漏掉了。

**这与 `cleanup_log_v2.md` 记录的"2026-09-30 误写为 2026-05-13"是同一类编号复用风险**
（`123\README.md` 取号规则读该目录列表，重复编号会导致取号歧义）。

**但本任务编号 21 本身 `count=1`，安全。** ⇒ 这是**别人（863 会话侧或 v3 修线会话）的残留**，
我只登记并点名，**不删**。建议由人确认哪个是空壳后删除另一个，并复查 `123\README.md` 的取号流程。

### R-5 · `timeline\proxy_map_v3.json` —— **名不副实：v1 文件的逐字节副本**

| 文件 | 体积 | mtime | SHA256 |
|---|---|---|---|
| `timeline\proxy_map_v1.json` | 785 B | 2026-09-30 14:40:32 | `36E0666C5F3D18900A61A114FE9C1AF6A12DA0B3A1F1E409759A17CDFB11EE4C` |
| `timeline\proxy_map_v2.json` | 785 B | 2026-09-30 **14:40:32** | `36E0666C5F3D18900A61A114FE9C1AF6A12DA0B3A1F1E409759A17CDFB11EE4C` |
| **`timeline\proxy_map_v3.json`** | **785 B** | **2026-09-30 14:40:32** | **`36E0666C5F3D18900A61A114FE9C1AF6A12DA0B3A1F1E409759A17CDFB11EE4C`** |

三者 **SHA256 完全相同**、mtime **同为 v1 时期的 14:40:32**（`program_map_v3.json` 是 18:56:10）。
⇒ **`proxy_map_v3.json` 并不是为 v3 生成的，只是 v1 文件的复制品**。

这正是 `cleanup_log_v2.md` 末尾那条教训（"`preview_probe_v2.json` 曾是重渲前的过期快照"）
的**同型复发**：任何"探测/代理快照"若在重渲后不重跑，就会变成指向旧版本的**假证据**。
名字带 `v3` 会让下游误以为它描述 v3。**登记，建议由人确认后重跑或改名，不属本角色可自行处置的范围。**

### R-6 · 我自己留下的产物（透明登记）

`TASK\cache\` 下 8 个探针：`cache\_acceptD_v3_probe{1..8}.ps1` 与 `_acceptD_v3_probe{2,3,4,5,7,8}.txt`。
全部**纯 ASCII、无非 ASCII 字节**，不含任何渲染或写入既有文件的逻辑。
其中 probe1 / probe3 曾含非 ASCII（见 D4 段），已改写为纯 ASCII 说明文件，**未删除**。
原始输出全部保留，可供复验逐行对账。

---

## §O · 待办（不属本角色分工，只登记）

| # | 事项 | 实测状态 |
|---|---|---|
| **O-1** | `reports\reverify_864_v3.md`、`reports\freeze_gate_864_v3.md` | **均不存在**（19:08 实测）。作业书 D6 点名要核，但**未分配给 B/C/D 任一角色**，也未在任何 brief 里指派 ⇒ 属未产出，不是命名违规，不据此扣 D6 分 |
| **O-2** | `reports\acceptB_864_v3.md`、`reports\acceptC_864_v3.md` | 19:08 实测**不存在**；同期 `cache\_acceptC_v3_*`、`cache\acceptB_v3_recompute.py` 已生成（19:04–19:05），说明 **B/C 当时仍在执行中**。**不是缺件，等其落盘即可** |
| **O-3** | `reports\selfaudit_864_v3.md` | 不存在（作业书注明归他人，我未读未改） |
| **O-4** | `preview\864-review-v3.decode.log` = **0 B** | 与 v2 同为 0 B；v1 是 3 B。**是否合规由角色 C 判定**（它要对账解码退出码与 stderr 行数），我不越界裁决，仅登记该文件当前为 0 字节 |

---

## §C · 本角色的自证

| 约束 | 我的执行情况 |
|---|---|
| 看图 0 张 | ✅ 未 Read 任何 jpg/png；未跑抽帧、未跑 `blackdetect` 取帧；全部结论来自数值与命令输出 |
| 只写一份报告 | ✅ 只写 `TASK\reports\acceptD_864_v3.md`（临时探针按指令落在 `TASK\cache\`，带 `_acceptD_v3` 前缀） |
| 零删除 / 零移动 | ✅ 全程未执行任何 `Remove-Item` / `Move-Item` / `Rename-Item`；`Get-FileHash` / `ReadAllBytes` / `Test-Path` 均为只读 |
| 未改他人文件 | ✅ 未触碰 `acceptB_864_v3.md`、`acceptB_revalidate_v3.json`、`acceptC_864_v3.md`、`selfaudit_864_v3.md`、`adversarial_864_v3_*.md`；未改 `timeline\`、`preview\`、`captions\` 下任何既有文件 |
| 未重渲 / 未出 4K | ✅ 只跑 `ffprobe`（只读探测），**未跑任何 ffmpeg 编码**，未产生任何视频 |
| 未装环境 | ✅ 只用既有 `C:\Project\永劫无间\.video-tools\venv\Scripts\python.exe` 与 `LosslessCut\resources\ffprobe.exe`，**零 pip install** |
| 未写出 TASK 以外路径 | ✅ `cache\_acceptD_v3_probe*.ps1/.txt` 与本报告，全部在 TASK 内。**唯一一次越界尝试已被系统拦下**：probe1 因缺 BOM 把 `Set-Content` 目标解析到乱码树，报 `Could not find a part of the path` 而失败，**未创建任何文件**（乱码树终态仍 0 文件）——该次失败本身成为 D4 违规"响亮失败、不会静默写错地方"的现场实证 |
| 报告 UTF-8 | ✅ |

---

## 结语

**除 D4 的两处 `.ps1` 编码违规外，v3 的合规面是干净的：源片零改动、未偷跑 4K、目录结构规范、
渲染链路零烧录零 BGM 零装饰、字幕纯外挂、命名三要素全对。**
所有越界落点（乱码树 4 个空壳、861 的 `.txt` 副本、863 的编号重复、`proxy_map_v3.json` 假版本号）
**全部只登记、全部举证、全部点名，没有一个被我删除或移动**，处置权留给人。
D4 的修复成本是两行重存命令，与 v3 内容正确性完全无关。

STATUS: FAIL