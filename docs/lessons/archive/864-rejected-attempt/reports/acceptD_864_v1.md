# acceptD_864_v1.md — 合规验收报告（独立验收角色 D）

- **任务目录（TASK）**：`C:\Project\永劫无间\123\21.864永劫无间 2026-09-30 02-57-13`
- **源素材（SRC，只读）**：`E:\PR导出\864永劫无间 2026-09-30 02-57-13.mp4`
- **验收人**：角色 D（未参与本版任何执行，只读验收；本次会话 0 张图片、0 次渲染、0 次安装、0 次环境新建）
- **验收时间窗**：2026-09-30，本任务活动区间 12:50:00 – 14:46:20（TASK `CreationTime` 12:54:22 起，最新派生文件 14:46:20）
- **工具**：`Get-Item` / `Get-ChildItem` / `Get-FileHash` / `Get-Content -Encoding UTF8` / `ffprobe`
  - ffprobe（运行时解析，未硬编码）：`C:\Project\永劫无间\.video-tools\LosslessCut\resources\ffprobe.exe`
  - 解析来源：`C:\Project\永劫无间\scripts\resolve_ffmpeg.ps1 -Emit`
- **TASK 规模**：1.99 GB；4,862 × `.jpg`（339.43 MB）、18 × `.mp4`（1,661.44 MB）、1 × `.wav`（35.16 MB）、24 × `.md`、16 × `.json`、16 × `.py`、10 × `.ps1`

---

## 1. 源片未动

| 检查项 | 我的实测值 | 依据（绝对路径） | 判定 |
|---|---|---|---|
| SRC 字节数 | **2,984,729,760** | `Get-Item E:\PR导出\864永劫无间 2026-09-30 02-57-13.mp4` → `Length` | — |
| 探测时记录的字节数 | **2,984,729,760**（JSON 字符串 `"2984729760"`） | `TASK\analysis\source_probe_raw.json` → `format.size` | — |
| 两者对账 | **完全一致，差 0 字节** | 上两行 | **PASS** |
| SRC `CreationTime` | 2026-09-30 **09:38:10** | 同上 | — |
| SRC `LastWriteTime` | 2026-09-30 **09:38:25** | 同上 | — |
| 与本任务时间窗的关系 | 写入时间比任务起点（~12:50）**早 3 小时 12 分**，任务期内**零次写入** | 时间戳比对 | **PASS** |
| `E:\PR导出\` 全量 `86*.mp4` 清单 | 见下表；**8 个文件中 `LastWriteTime` 最新者为 864 的 09:38:25，无一 ≥ 12:50** | `Get-ChildItem E:\PR导出 -Filter '86*.mp4'` | **PASS** |
| 改名/覆盖迹象 | **无**。文件名仍为 `864永劫无间 2026-09-30 02-57-13.mp4`，`CreationTime` 与 `LastWriteTime` 相差 15 秒（OBS 落盘特征），两者都早于任务窗口 | 同上 | **PASS** |

`E:\PR导出\` 下全部 `86*.mp4`（名称 / 字节 / 修改时间）：

| 文件名 | Length | CreationTime | LastWriteTime |
|---|---|---|---|
| `860永劫无间2026-09-26 22-43-03.mp4` | 6,191,704,638 | 2026-09-29 09:12:34 | 2026-09-29 09:13:20 |
| `861永劫无间 2026-09-26 23-26-54.mp4` | 6,226,961,899 | 2026-09-29 09:30:45 | 2026-09-29 09:31:05 |
| `862.1永劫无间 2026-09-29 22-50-22.mp4` | 9,072,741,151 | 2026-09-30 06:59:32 | 2026-09-30 07:00:03 |
| `862.2永劫无间 2026-09-29 22-50-22.mp4` | 8,922,892,704 | 2026-09-30 07:22:47 | 2026-09-30 07:23:13 |
| `862.3永劫无间 2026-09-29 22-50-22.mp4` | 3,735,036,246 | 2026-09-30 07:33:34 | 2026-09-30 07:33:54 |
| `862永劫无间 2026-09-29 22-50-22.mp4` | 21,730,420,482 | 2026-09-30 08:26:35 | 2026-09-30 08:27:20 |
| `863永劫无间 2026-09-30 02-57-13.mp4` | 2,894,848,189 | 2026-09-30 08:34:23 | 2026-09-30 08:34:31 |
| **`864永劫无间 2026-09-30 02-57-13.mp4`** | **2,984,729,760** | 2026-09-30 09:38:10 | **2026-09-30 09:38:25** |

> **结论（第 1 项）**：源片字节数与 `source_probe_raw.json` 探测时完全一致（2,984,729,760 字节，差 0），`LastWriteTime` 停留在 09:38:25，**未被写入、未被覆盖、未被改名**。

---

## 2. 无 4K 偷跑

全盘递归 `TASK\`，`*.mp4` 共 **18 个**，逐个 `ffprobe` 实测分辨率：

| # | 相对路径 | 字节 | ffprobe 分辨率 | 时长 | 码率 |
|---|---|---|---|---|---|
| 1 | `cache\proxy_360p30.mp4` | 89,403,741 | **640×360** | 1152.233008 s | 620,733 bps |
| 2 | `cache\smoke\segs\vseg001.mp4` | 13,472,477 | 1280×720 | 12.000 s | 8,981,651 bps |
| 3 | `cache\smoke\segs\vseg002.mp4` | 5,937,275 | 1280×720 | 5.000 s | 9,499,640 bps |
| 4 | `cache\smoke\segs\vseg003.mp4` | 4,556,286 | 1280×720 | 4.000 s | 9,112,572 bps |
| 5 | `cache\smoke\smoke.mp4` | 23,964,171 | 1280×720 | 21.021 s | 9,119,943 bps |
| 6 | `cache\v1segs\vseg001.mp4` | 115,252,530 | **1280×720** | 85.000 s | 10,847,296 bps |
| 7 | `cache\v1segs\vseg002.mp4` | 52,874,884 | **1280×720** | 40.000 s | 10,574,976 bps |
| 8 | `cache\v1segs\vseg003.mp4` | 69,960,169 | **1280×720** | 47.000 s | 11,908,113 bps |
| 9 | `cache\v1segs\vseg004.mp4` | 37,588,017 | **1280×720** | 30.000 s | 10,023,471 bps |
| 10 | `cache\v1segs\vseg005.mp4` | 32,896,896 | **1280×720** | 22.500 s | 11,696,674 bps |
| 11 | `cache\v1segs\vseg006.mp4` | 59,624,743 | **1280×720** | 39.000 s | 12,230,716 bps |
| 12 | `cache\v1segs\vseg007.mp4` | 120,880,419 | **1280×720** | 88.000 s | 10,989,129 bps |
| 13 | `cache\v1segs\vseg008.mp4` | 100,419,830 | **1280×720** | 84.000 s | 9,563,793 bps |
| 14 | `cache\v1segs\vseg009.mp4` | 44,814,299 | **1280×720** | 32.000 s | 11,203,574 bps |
| 15 | `cache\v1segs\vseg010.mp4` | 114,583,117 | **1280×720** | 88.000 s | 10,416,647 bps |
| 16 | `cache\v1segs\vseg011.mp4` | 50,524,971 | **1280×720** | 47.800 s | 8,456,062 bps |
| 17 | `cache\v1segs\vseg012.mp4` | 2,979,884 | **1280×720** | 11.600 s | 2,055,092 bps |
| 18 | **`preview\864-review-v1.mp4`**（唯一成品） | 802,410,248 | **1280×720** | 614.921333 s | 10,439,192 bps |

| 检查项 | 我的实测值 | 依据（绝对路径） | 判定 |
|---|---|---|---|
| 是否存在 3840×2160 或任何 4K **视频**产物 | **0 个**。18 个 MP4 全为 1280×720（17 个）或 640×360（1 个） | 上表，ffprobe 逐个 `stream=width,height` | **PASS** |
| `cache\v1segs\` 的 12 个分段 | 全部 **1280×720** | 上表第 6–17 行 | **PASS** |
| 唯一成品 | `TASK\preview\864-review-v1.mp4`，**1280×720** | `ffprobe preview\864-review-v1.mp4` | **PASS** |
| 其他容器格式（`.mov/.mkv/.ts/.webm/.m4v/.avi`） | **0 个** | `Get-ChildItem TASK -Recurse` 扩展名过滤 | **PASS** |
| `*master*` 命名 | **0 命中** | 全 TASK 文件名正则 `master` | **PASS** |
| `*3840*` 命名 | **0 命中** | 同上，正则 `3840` | **PASS** |
| `*final*` 命名 | **0 命中** | 同上，正则 `final` | **PASS** |
| `*cujian*` 命名 | **0 命中** | 同上，正则 `cujian` | **PASS** |
| `*burn*` 命名 | **0 命中** | 同上，正则 `burn` | **PASS** |
| `*4k*` 命名 | **8 命中，全部是 `.jpg` 静帧联系表，不是视频**（见下方说明） | `TASK\shots\seg11\verify\{banner4k,feed4k,feed4k_early}\sheets\*.jpg` | **PASS**（附注） |
| `E:\Cujian导出\` 中的 864 成片 | **不存在**（`Get-ChildItem -Filter '864*'` 返回空）。该目录现存 20 个 `cujian.mp4`，编号到 859，**无 864** | `E:\Cujian导出\` | **PASS** |
| `TASK\deliverables\` | **不存在**（`Test-Path` → `False`） | `TASK\deliverables\` | **PASS**（粗剪阶段应为不存在，符合） |

> **关于 8 个 `*4k*.jpg` 的映射声明（不记为违规）**：文件名形如
> `b4k_01.jpg` / `f4k_01.jpg` / `e4k_01.jpg`，位于
> `TASK\shots\seg11\verify\{banner4k,feed4k,feed4k_early}\sheets\`。
> ffprobe 实测其尺寸为 **1500×2070 / 1500×1840 / 940×1680 / 940×1260 / 1880×960 / 1880×640 / 1880×960**，
> 明显是多帧 4K 裁切纵向堆叠出的**联系表静帧**（用来读 HUD 横幅/击杀播报的小字），不是 4K 视频产物。
> 命名中的 "4k" 语义为"**取自 4K 源分辨率的取证帧**"，与"4K 成片"无关，不构成 4K 偷跑。
>
> **结论（第 2 项）**：TASK 内不存在任何 3840×2160 或其他 4K 视频产物；唯一成品是 720p 审片预览
> `preview\864-review-v1.mp4`；`cache\v1segs\` 12 个分段全为 720p；`deliverables\` 不存在；
> `E:\Cujian导出\` 无 864 成片。

---

## 3. 目录合规（工作路径铁律）

### 3.1 TASK 根级文件 / 子目录

| 检查项 | 我的实测值 | 依据（绝对路径） | 判定 |
|---|---|---|---|
| TASK **根级文件** | **0 个**（`Get-ChildItem -File` 返回空）。根级**只有目录**，无任何散落文件 | `TASK\`（`Get-ChildItem -File -Force`） | **PASS** |
| TASK 子目录（8 个，全部合法） | `analysis`、`audio`、`cache`、`captions`、`preview`、`reports`、`shots`、`timeline` | `TASK\` | **PASS** |
| `deliverables\` 是否存在于 TASK | 否 | `Test-Path TASK\deliverables` → False | **PASS** |
| `cache\adv8_src_thumb.raw` = **0 字节**（14:45:56） | 空残留文件，**仍落在 TASK 内**，不违反路径铁律，仅列为卫生观察项 | `TASK\cache\adv8_src_thumb.raw` | PASS（附注） |

### 3.2 项目根与上一级

| 检查项 | 我的实测值 | 依据（绝对路径） | 判定 |
|---|---|---|---|
| `C:\Project\永劫无间\` 根级 `f_*.jpg` | **0 个** | `Get-ChildItem C:\Project\永劫无间 -File` | PASS |
| `C:\Project\永劫无间\` 根级 `thumb_*.jpg` | **0 个** | 同上 | PASS |
| `C:\Project\永劫无间\` 根级 `*.mp4` | **0 个** | 同上 | PASS |
| `C:\Project\永劫无间\` 根级 `*.srt` | **0 个** | 同上 | PASS |
| `C:\Project\永劫无间\` 根级全部文件 | 仅 5 个：`.gitattributes`(1578)、`.gitignore`(3504)、`AGENTS.md`(17090)、`IMAGE_LIMIT.md`(2505)、`README.md`(8750) | 同上 | **PASS** |
| `C:\Project\` **目录** | **2 个**：`永劫无间`（正确）+ **`姘稿姭鏃犻棿`（野目录）** | `[System.IO.Directory]::GetDirectories('C:\Project')` | **FAIL** |
| 野目录名逐字符核验 | `姘稿姭鏃犻棿` = **U+59D8 U+7A3F U+59ED U+93C3 U+72BB U+68FF**。对照正确名 `永劫无间` = U+6C38 U+52AB U+65E0 U+95F4。**是"永劫无间"被按 GBK 误解码产生的真实乱码目录名**（不是我的控制台显示问题——同一条命令里正确目录名正常显示） | 码点比对 | **FAIL** |
| 野目录内容 | `123\18.860姘稿姭鏃犻棿2026-09-26 22-43-03\shots\adv_v5_3\` —— **4 个目录项、0 个文件、0 字节**（全空壳） | `Get-ChildItem C:\Project\姘稿姭鏃犻棿 -Recurse` | **FAIL** |
| 野目录创建时间 | **2026-09-30 13:13:59** —— **落在本任务活动窗口（12:50 起）之内**（本任务 `reports\scanner_brief_common.md` 写于 13:13:43，相隔 16 秒） | 同上 | **FAIL** |
| 是否含 864 相关内容 | **不含**。乱码树里只有 `18.860` 一条路径，**没有任何 864 的派生物写进去** | 同上 | 附注 |
| 项目预检脚本判级 | **BLOCKER**：`"stray dirs beside project :: STOP: something wrote outside the sandbox. Directories that sit next to the project root and are not the project: C:\Project\姘稿姭鏃犻棿 (4 items, 0 B)"`；`"pass":7,"warn":0,"blocker":1,"ready":false` | `C:\Project\永劫无间\scripts\check_video_environment.ps1 -Json`，**退出码 2** | **FAIL** |
| `C:\Project\` **文件** | **0 个** | `[System.IO.Directory]::GetFiles('C:\Project')` | **PASS** |

### 3.3 编号唯一性与 14:42 笔误残留

| 检查项 | 我的实测值 | 依据（绝对路径） | 判定 |
|---|---|---|---|
| `C:\Project\永劫无间\123\` 全部目录 | 9 个 + 1 归档：`13.849…`、`14.854…`、`15.855…`、`16.858…`、`17.859…`、`18.860…`、`19.861…`、`20.863…`、**`21.864永劫无间 2026-09-30 02-57-13`**、`workflow_upgrade` | `Get-ChildItem C:\Project\永劫无间\123 -Directory` | — |
| 编号重复检查 | **无重复**。`21.` 前缀目录**有且仅有一个**，即 `21.864永劫无间 2026-09-30 02-57-13`（CreationTime 12:54:22） | 同上 + `-Filter '21.*'` | **PASS** |
| 14:42 笔误目录 `21.864永劫无间 2026-05-13` 是否残留 | **无残留**。对整个 `C:\Project\` 递归搜 `*2026-05*` 目录，**0 命中**；`*2026-05-13*` 亦 0 命中 | `Get-ChildItem C:\Project -Recurse -Directory -Filter '*2026-05*'` | **PASS** |

### 3.4 新发现的第二个野落点

| 检查项 | 我的实测值 | 依据（绝对路径） | 判定 |
|---|---|---|---|
| `C:\Project\永劫无间\123\` **根级**文件 | **3 个**，其中 1 个是派生物落错位置 | `Get-ChildItem C:\Project\永劫无间\123 -File` | **FAIL** |
| ① `123\README.md` | 4,268 B，mtime 2026-09-29 05:24:39 | 同上 | 合法（编号依据文档） |
| ② `123\cleanup_log_top_2026-09-24.md` | 2,449 B，mtime 2026-09-25 03:30:49 | 同上 | 合法（历史清理日志） |
| ③ **`123\19.861永隙无间_x.txt`** | **78,884 B**，`CreationTime` **= `LastWriteTime` = 2026-09-30 13:19:35**（**落在本任务窗口内**） | `C:\Project\永劫无间\123\19.861永隙无间_x.txt` | **FAIL** |
| ③ 的内容归属 | 是 **19.861** 的时间线转储（首行 `source = E:\PR导出\861永劫无间 2026-09-26 23-26-54.mp4`，`episode_count = 14`，187 行），**不含 864 内容** | 同上，`Get-Content -Encoding UTF8` | — |
| ③ 与正本的哈希关系 | SHA256 **完全相同**：`8E895FC3071BFA31EE658F9ACE3127248165D9E78EE084AFC059CF1412C48846`，与 `C:\Project\永劫无间\123\19.861永劫无间 2026-09-26 23-26-54\shots\adv_v5\adv1\lane_meta.txt` 逐字节一致（两者 `CreationTime` 均为 13:19:35，说明是同一次写入的两个落点） | `Get-FileHash -Algorithm SHA256` | — |
| ③ 的文件名是否乱码 | `19.861永隙无间_x.txt` 码点 = `1 9 . 8 6 1 U+6C38 U+9699 U+65E0 U+95F4 _ x . t x t`；`无`（U+65E0）被写成了 `隙`（U+9699）——**又一处路径字面量被误解码** | 码点比对 | **FAIL** |
| ③ 是否由 TASK 内的脚本写出 | **否**。在 `TASK\` 内全文搜 `lane_meta\|19\.861\|_x\.txt\|永隙无间` → **0 命中**；TASK 内 10 个 `.ps1` 全部为纯 ASCII 且**均未内嵌项目路径字面量**（`embeds_project_path=False`），故不构成 AGENTS.md 所述"`.ps1` 无 BOM + 路径字面量"的经典成因。写出方在本任务目录之外，无法从只读证据进一步归因 | ripgrep 全 TASK 扫 `*.{py,ps1,md,json,txt}` | 附注（不判 FAIL） |
| TASK 自身派生物是否外泄 | **否**。除本 TASK 外，全项目搜 `*864*` 文件，命中项全部是**其他任务目录里恰好编号为 864 的帧序号**（如 `…\18.860…\shots\f1\t_000864.jpg`、`…\19.861…\shots\selfaudit_…`），**均为 864 之前既存的文件，非本任务产物** | `Get-ChildItem C:\Project\永劫无间 -Recurse -Filter '*864*'`（排除本 TASK 与 `.video-tools`） | **PASS** |
| 12:40 之后项目根（排除 `123\` 与 `.video-tools`）的新增文件 | 仅 `.git\` 内部对象、`docs\TROUBLESHOOTING.md`(12:40:17)、`skills\naraka-highlight-studio\scripts\validate_com…`(12:40:29) 及其 `__pycache__` —— 均为仓库/技能维护活动，**无任何 f_/thumb_/mp4 派生物落在项目根** | `Get-ChildItem C:\Project\永劫无间 -Recurse -File \| Where LastWriteTime -ge 2026-09-30 12:40`（排除两目录） | **PASS** |

> **结论（第 3 项）**：**FAIL**。本任务自身的派生物（4,862 抽帧、18 个 MP4、字幕、时间线、报告）**全部落在 `TASK` 内**，项目根 `C:\Project\永劫无间\` 干净、无 `f_*`/`thumb_*`/散落 MP4，编号唯一、14:42 笔误目录已确认无残留。**但在本任务活动窗口（12:50–14:46）内，项目外部新增了 2 处越界落点**：
> 1. `C:\Project\姘稿姭鏃犻棿\`（真实乱码目录名，4 项空壳，0 字节，13:13:59 创建）—— 直接导致 `check_video_environment.ps1` 判 **BLOCKER / 退出码 2 / ready:false**；
> 2. `C:\Project\永劫无间\123\19.861永隙无间_x.txt`（78,884 B，13:19:35 创建，为 19.861 `lane_meta.txt` 的逐字节副本，文件名含乱码字符）。
>
> 二者内容都与 864 无关（均为 18.860 / 19.861 的空壳或副本），**没有 864 的派生物写出去**，但均违反"全部派生文件只许落 `TASK` 内"与 AGENTS.md 的"上一级只允许存在项目本身"两条铁律。
> **按纪律我没有删除任何东西**（删目录属破坏性动作，须人确认）。建议交人处置：确认无用后跑
> `& 'C:\Project\永劫无间\scripts\sanitize_stray_dirs.ps1' -Remove`，并单独移走/删除
> `C:\Project\永劫无间\123\19.861永隙无间_x.txt`。

### 3.5 一处已排除的误报（留档以免后人重查）

用 PowerShell 5.1 默认编码读 TASK 内的 JSON/MD 时，中文路径会显示成
`C:\\Project\\姘稿姭鏃犻棿\\...`。这是**我的读取端按 GBK 解码 UTF-8 造成的显示假象**，
**不是文件内容问题**。以 `Get-Content -Encoding UTF8` 复核确认：
- `TASK\timeline\program_map_v1.json` → `"timeline": "C:\\Project\\永劫无间\\123\\21.864永劫无间 2026-09-30 02-57-13\\timeline\\combat_episodes_v1.json"` ✅
- `TASK\reports\v1_validate.json` → 同样为正确中文路径 ✅
- `TASK\captions\864-review-v1.stats.json` → `"srt": "C:\\Project\\永劫无间\\123\\21.864永劫无间 2026-09-30 02-57-13\\captions\\864-review-v1.srt"` ✅
- `TASK\reports\qa_v1.json`、`TASK\reports\srt_crosscheck_v1.json`、`TASK\reports\acceptB_revalidate_v1.json` 同上 ✅

另：`TASK\cache\render_preview.py` 含 8 个非 ASCII 字符，全部是第 21、25 行两个路径字面量里的
`永劫无间`（各 4 字），文件**无 BOM**。Python 3 源码默认按 UTF-8 读，故当前无害；
但若日后被 PowerShell 以 ANSI 读入，将复现 3.2 / 3.4 的乱码落点。列为风险观察项，**不计 FAIL**。

---

## 4. 命名规范

| 检查项 | 我的实测值 | 依据（绝对路径） | 判定 |
|---|---|---|---|
| 预览 `preview\<序号>-review-v<N>.mp4` | `864-review-v1.mp4` —— 序号 864 = 素材编号，v1 = 时间线版本号 | `TASK\preview\864-review-v1.mp4` | **PASS（符合）** |
| 时间线 `timeline\combat_episodes_v<N>.json` | `combat_episodes_v1.json`（70,578 B） | `TASK\timeline\combat_episodes_v1.json` | **PASS（符合）** |
| 时间线 `timeline\program_map_v<N>.json` | `program_map_v1.json`（3,552 B） | `TASK\timeline\program_map_v1.json` | **PASS（符合）** |
| 校验 `reports\v<N>_validate.json` | `v1_validate.json`（7,869 B，`schema: naraka-combat-roughcut-qa/v1`，`episode_count: 11`） | `TASK\reports\v1_validate.json` | **PASS（符合）** |
| 字幕 `captions\<序号>-review-v<N>.srt` | `864-review-v1.srt`（2,923 B，51 条） | `TASK\captions\864-review-v1.srt` | **PASS（符合）** |
| 字幕 `.stats.json` | `864-review-v1.stats.json`（542 B，`"mode": "external sidecar SRT (no burn, no mux)"`，`"count": 51`） | `TASK\captions\864-review-v1.stats.json` | **PASS（符合）** |
| 报告三分立 `reports\selfaudit_864_v1.md` | **该 `.md` 尚未落盘**。现存的是取证帧目录 `TASK\shots\selfaudit_v1\`（`CreationTime` 14:45:27，含 `p1c0_0/ p1c85_0/ p1c125_0/ p1c172_0/ p1c202_0/ p1c224_5/ p1c263_5/` 七个取证点及 `sheets\`） | `TASK\shots\selfaudit_v1\`；`TASK\reports\` 全量列举 | 附注（**不判 FAIL**） |
| 报告三分立 `reports\accept*_864_v1.md` | 本报告即 `reports\acceptD_864_v1.md`（角色 D）。另已有 `reports\acceptB_revalidate_v1.json`（7,869 B，**与 `v1_validate.json` 同字节数**、同 `schema`，是角色 B 的复验 JSON） | `TASK\reports\` | 附注（**不判 FAIL**） |

**后缀差异映射声明（按要求声明，不记为缺失）**：

| 实际文件名 | 规范名 | 映射说明 |
|---|---|---|
| `timeline\combat_episodes_v1_programbounds.json` | `combat_episodes_v<N>.json` | 同一 v1 时间线的**节目坐标边界视图**（3,699 B，`qa_v1_programbounds.json` 的配套物），vN 仍为 1，未产生版本分叉 |
| `timeline\proxy_map_v1.json` | `program_map_v<N>.json` | 分析代理（360p）的**源↔代理区间映射**（785 B），是 `program_map_v1.json` 的辅助件，非成片映射 |
| `reports\qa_v1.json` / `qa_v1_programbounds.json` | `reports\v<N>_validate.json` | 命名族前缀不同（`qa_` vs `v1_`），但同为 v1 的机读门禁产物 |
| `reports\acceptB_revalidate_v1.json` | `reports\accept*_864_v1.md` | 缺 864 素材号前缀、扩展名为 `.json`。它记录的是**机器复验结果**（与 `v1_validate.json` 同源同尺寸），不是人工验收叙述；若要与三分立规范对齐，建议后续版本补 864 前缀 |
| `reports\srt_crosscheck_v1.json`、`reports\preview_probe_v1.json`、`reports\preview_media_filters_v1.log` | — | 附加机读证据件，v1 编号一致，不与三分立命名冲突 |
| `reports\seg1..seg14_scan_report.md`、`merge_decision_v1.md`、`adversarial_brief.md` 等 | — | 分段扫描报告与决策记录，v1/无版本号均可接受 |

> **结论（第 4 项）**：**PASS**。核心三件套（`preview` / `timeline` / `captions`）与校验件
> `v1_validate.json` 命名**全部符合**规范，序号 864 与 vN 语义正确。
> 存在 2 处**后缀/前缀级差异与 1 处未落盘**（selfaudit 的 `.md`），已在上表逐条声明映射关系，
> 均**不计为缺失、不判 FAIL**；其中 `acceptB_revalidate_v1.json` 与 `selfaudit_864_v1.md`
> 建议在下一版（v2）补齐以完全对齐三分立规范。

---

## 5. 无烧录 / 无内嵌

| 检查项 | 我的实测值 | 依据（绝对路径） | 判定 |
|---|---|---|---|
| 渲染脚本的视频滤镜 | 第 98 行 `-vf` **只有** `scale={w}:{h}:flags=lanczos,fps={fps}`。**无** `subtitles=`、**无** `ass=`、**无** `drawtext`、**无** `filter_complex`、**无** `overlay=` | `TASK\cache\render_preview.py:98` | **PASS** |
| 渲染脚本的流映射 | 第 97 行 `-map 0:v:0 -map 0:a:0` —— **恰好 2 条流，无 `-map 0:s:0`，无 `-c:s`，无 `mov_text`** | `TASK\cache\render_preview.py:97` | **PASS** |
| 渲染脚本的合成方式 | 第 115–116 行 concat 阶段 `-f concat -safe 0 -i <listing> -c copy` —— **流拷贝，不再挂任何滤镜**，故不可能在中途烧字 | `TASK\cache\render_preview.py:115-116` | **PASS** |
| 烧录开关（全局扫描） | 在 TASK 内全文搜 `subtitles=\|drawtext\|filter_complex\|amix\|acrossfade\|overlay=\|-burn\|burnin\|ass=\|setpts=` → **10 命中，全部落在抽帧/拼表脚本**：`cache\make_route_frames.ps1:32`、`cache\extract_all_frames.ps1:32`、`cache\split_routes.ps1:73`、`cache\make_sheets.ps1:51`、`shots\adv3\extract_adv3.ps1:38`、`shots\seg14\verify\extract_dense.ps1:26`、`shots\seg14\verify\extract_labelled.ps1:27`、`shots\seg8\verify\grab.ps1:13,42` —— **这些脚本的输出全是 `shots\` 下的 `.jpg` 静帧**，`drawtext` 用来在取证帧上打时间码标签；`filter_complex` 用来把多帧拼成联系表。**没有一条进入 `preview\864-review-v1.mp4` 的渲染链** | ripgrep（`TASK\`，`*.{py,ps1,txt,sh,bat,json}`） | **PASS** |
| `preview\` 目录内容 | **只有 2 个文件**：`864-review-v1.mp4`（802,410,248 B）、`864-review-v1.decode.log`（3 B，内容 `???`，即空 stderr）。**无 `.srt` 兄弟文件、无 `-burn` 后缀产物、无 `.ass`/`.vtt`** | `TASK\preview\` | **PASS** |
| 预览内嵌字幕流 | `ffprobe -show_streams` → **`nb_streams=2`**：index 0 = `codec_type=video` h264 1280×720；index 1 = `codec_type=audio` aac 48 kHz 立体声。**`codec_type=subtitle` 计数 = 0** | `ffprobe T:\preview\864-review-v1.mp4`（TASK 绝对路径同左） | **PASS** |
| 独立第二路证据 | 解码日志原文含 `video:14988KiB audio:115360KiB **subtitle:0KiB other streams:0KiB**` | `TASK\reports\preview_media_filters_v1.log` | **PASS** |
| 字幕居住地 | **只住在 `TASK\captions\`**：`864-review-v1.srt`(2,923 B)、`864-review-v1.stats.json`(542 B)、`source_transcript.json`(24,647 B)。`preview\` 与 `TASK\` 根级**均无 `.srt`** | `TASK\captions\`、`TASK\preview\`、`TASK\`（根级 0 文件） | **PASS** |
| 字幕交付模式自述 | `"mode": "external sidecar SRT (no burn, no mux)"` | `TASK\captions\864-review-v1.stats.json` | **PASS** |
| 渲染脚本自述 | 模块 docstring 第 8–9 行：`"Clean picture is mandatory: no subtitle stream, no burned-in text, no BGM, no decorative effects. Subtitles ship as an external SRT only."` | `TASK\cache\render_preview.py:8-9` | 佐证 |

> **结论（第 5 项）**：**PASS**。渲染命令里**没有任何烧录开关**（无 `subtitles=` / `ass=` / `drawtext` 进入预览链），
> 预览**零内嵌字幕流**（两路独立证据：`nb_streams=2` 与 `subtitle:0KiB other streams:0KiB`），
> `preview\` 下**无 `.srt` 兄弟文件、无 `-burn` 产物**，字幕**只住在 `TASK\captions\`**。

---

## 6. 本阶段范围

| 检查项 | 我的实测值 | 依据（绝对路径） | 判定 |
|---|---|---|---|
| 本次是否只出 720p 审片预览 | **是**。唯一成品 `preview\864-review-v1.mp4`，**1280×720 / 60 fps / 614.921333 s / 802,410,248 B** | `ffprobe TASK\preview\864-review-v1.mp4` | **PASS** |
| 是否出 4K 成片 | **否**。TASK 内 18 个 MP4 全部 ≤1280×720；`deliverables\` 不存在；`E:\Cujian导出\` 无 `864*` | 第 2 项全表 | **PASS** |
| 预览流结构 | `ffprobe -show_streams` → **1 条视频 + 1 条音频，无第三条流** | 同上 | **PASS** |
| 视频流实测 | h264 High（`codec_tag=avc1`），`width=1280 height=720`，`r_frame_rate=60/1`，`duration=614.900000`，`bit_rate=10266612`（10.27 Mbps），`nb_frames=36894`（= 614.9×60，与节目秒数吻合），`encoder=Lavc62.11.100 libx264` | 同上 | — |
| 音频流实测 | aac `mp4a`，`sample_rate=48000`，`channels=2`，`channel_layout=stereo`，`duration=614.921333`，`bit_rate=160342` | 同上 | — |
| 是否有第二条音频流 / BGM 轨 | **否，`nb_streams=2` 已封死**。渲染侧 `-map 0:a:0` 只取源第 1 条音轨（源 `source_probe_raw.json` 也是 `nb_streams=2` = 1v+1a，无第三轨可取），**无第二输入文件、无 `amix`、无 `acrossfade`、无音量滤镜** | `render_preview.py:97` + `analysis\source_probe_raw.json` + `ffprobe` | **PASS** |
| BGM 侧证 | 整片实测 `I = -17.8 LUFS`、`LRA = 9.6 LU`、`True peak = -0.2 dBFS`，为**单一未处理游戏混音**特征；若叠过 BGM，动态范围与真峰形态会明显不同 | `TASK\reports\preview_media_filters_v1.log`（ebur128 段） | **PASS** |
| 是否有装饰特效 | **否**。视频滤镜仅 `scale` + `fps`（第 98 行），合成仅 `-c copy`（第 115–116 行）；全文无 `overlay` / `fade` / `vignette` / `colorbalance` / `drawtext` 进入预览链 | `TASK\cache\render_preview.py` | **PASS** |
| 分析音频 `TASK\audio\audio_16k.wav` | **36,871,588 B（35.16 MiB）**，`pcm_s16le`，`sample_rate=16000`，`channels=1`（单声道），`duration=1152.234688`（= 源全长），`bit_rate=256000` | `Get-Item` + `ffprobe TASK\audio\audio_16k.wav` | 符合题述 35.9 MB（十进制 36.87 MB） |
| `audio_16k.wav` 是否被拼进预览 | **否**。三条独立反证：① 它是 `pcm_s16le` 16 kHz 单声道 WAV，而预览音轨是 `aac` 48 kHz 立体声；② 时长 1152.23 s vs 预览 614.92 s；③ 渲染脚本的输入只有 `--source`（源 MP4）与 `--timeline`（时间线 JSON），**从未引用该 WAV** | `render_preview.py:39-40, 96` + `ffprobe` 双向比对 | **PASS** |
| `TASK\cache\proxy_360p30.mp4` | **89,403,741 B（85.26 MiB / 89.4 MB 十进制）**，`h264`，`640×360`，`duration=1152.233008`，`bit_rate=620733`，**`nb_streams=1`（只有视频，根本没有音轨）** | `Get-Item` + `ffprobe TASK\cache\proxy_360p30.mp4` | 符合题述 89.4 MB |
| `proxy_360p30.mp4` 是否被拼进预览 | **否**。① 它无音轨，无法贡献 BGM/音频；② 它是 640×360，而预览是 1280×720；③ 时长 1152.23 s vs 614.92 s；④ 它只被 `analysis\proxy_360p30-Scenes.csv`（22,931 B）消费，定位是 PySceneDetect 分析代理 | `ffprobe` + `TASK\analysis\proxy_360p30-Scenes.csv` | **PASS** |
| 两个分析中间件的位置 | 均在 **TASK 目录内**（`TASK\audio\`、`TASK\cache\`），**无外泄** | 上两行 | **PASS** |
| 成品可解码性 | `preview\864-review-v1.decode.log` 仅 3 字节（空 stderr），`frame=36894` 全片解码无告警 | `TASK\preview\864-review-v1.decode.log` | PASS（附注） |
| `cache\smoke\`（冒烟测试残留） | 3 个分段 + `smoke.mp4`，均 1280×720，合计 47.9 MB，时间 13:20–13:21 | `TASK\cache\smoke\` | 属可再生中间件，**仍在 TASK 内**，符合"cache 可删"归类 |

> **结论（第 6 项）**：**PASS**。本次**只出了 720p 审片预览**（`preview\864-review-v1.mp4`，
> 1280×720 / 60 fps / 614.92 s / 802,410,248 B），**没有出 4K 成片**，**没有加 BGM**
> （`nb_streams=2`，1 视频 + 1 音频，无第二条音频轨），**没有装饰特效**（滤镜仅 `scale`+`fps`）。
> `audio\audio_16k.wav`（36,871,588 B，pcm_s16le 16 kHz 单声道）与
> `cache\proxy_360p30.mp4`（89,403,741 B，640×360，`nb_streams=1` 无音轨）
> **都只留在任务目录内，均未被拼进预览**。

---

## 汇总

| # | 验收项 | 判定 | 关键数字 |
|---|---|---|---|
| 1 | 源片未动 | **PASS** | 2,984,729,760 B，探测值差 0；`LastWriteTime` 09:38:25 早于任务起点 3h12m；`E:\PR导出` 8 个 `86*.mp4` 无一在 12:50 后被写 |
| 2 | 无 4K 偷跑 | **PASS** | 18 个 MP4：17 × 1280×720 + 1 × 640×360；4K 产物 0；`deliverables\` 不存在；`E:\Cujian导出` 无 864 |
| 3 | 目录合规 | **FAIL** | TASK 根级 0 文件、8 个合法子目录、项目根干净、编号唯一、14:42 笔误目录已无残留；**但窗口内新增 2 处越界落点**：`C:\Project\姘稿姭鏃犻棿`（4 项空壳，0 B，13:13:59，使预检 BLOCKER / 退出码 2）与 `123\19.861永隙无间_x.txt`（78,884 B，13:19:35，861 lane_meta 的逐字节副本） |
| 4 | 命名规范 | **PASS** | 预览/时间线/字幕/校验四类核心命名全部符合；3 处后缀差异与 1 处未落盘已声明映射，不计缺失 |
| 5 | 无烧录 / 无内嵌 | **PASS** | 滤镜仅 `scale`+`fps`；`nb_streams=2`，subtitle 0；解码日志 `subtitle:0KiB other streams:0KiB`；`preview\` 仅 MP4+decode.log |
| 6 | 本阶段范围 | **PASS** | 仅 720p 预览（1280×720 / 614.921 s / 802,410,248 B）；1 视频 + 1 音频，无 BGM、无装饰；WAV 与 360p 代理均未被拼入 |

**问题清单（FAIL 侧，唯一一项）**

1. **[BLOCKER / 路径铁律] 项目上一级存在乱码野目录** `C:\Project\姘稿姭鏃犻棿`
   （码点 U+59D8 U+7A3F U+59ED U+93C3 U+72BB U+68FF = `永劫无间` 的 GBK 误解码）。
   内含 `123\18.860姘稿姭鏃犻棿2026-09-26 22-43-03\shots\adv_v5_3\` 空壳 4 项、0 字节，
   创建于 2026-09-30 13:13:59（本任务窗口内）。`check_video_environment.ps1` 因此判
   `blocker=1, ready=false`，**退出码 2**。**未删除**（须人确认）。
   建议：确认无用后执行
   `& 'C:\Project\永劫无间\scripts\sanitize_stray_dirs.ps1' -Remove`。
2. **[路径铁律] 派生物落在 `123\` 根级** `C:\Project\永劫无间\123\19.861永隙无间_x.txt`
   （78,884 B，创建/修改同刻 2026-09-30 13:19:35，文件名含乱码 `隙`），
   与 `123\19.861…\shots\adv_v5\adv1\lane_meta.txt` SHA256 完全相同
   （`8E895FC3071BFA31EE658F9ACE3127248165D9E78EE084AFC059CF1412C48846`）。
   **未删除**（须人确认）。建议移入对应任务目录或删除该副本。
3. **卫生观察项（不判 FAIL）**：`TASK\cache\adv8_src_thumb.raw` 为 0 字节空残留（14:45:56）。
4. **风险观察项（不判 FAIL）**：`TASK\cache\render_preview.py` 无 UTF-8 BOM 且第 21、25 行
   含中文路径字面量。Python 3 当前按 UTF-8 读无害；若被 PowerShell 以 ANSI 读入，将复现问题 1/2
   的乱码落点。建议日后存为 UTF-8 with BOM。
5. **命名对齐建议（不判 FAIL）**：`reports\acceptB_revalidate_v1.json` 缺 864 素材号前缀、
   扩展名为 `.json`；`reports\selfaudit_864_v1.md` 尚未落盘（仅 `shots\selfaudit_v1\` 取证帧已生成）。
   建议 v2 对齐三分立规范。

---

**总判定**：5 项 PASS，第 3 项（目录合规）FAIL。失败项属**工作路径卫生 / 沙箱越界**，
**不涉及内容完整性**：源片零改动、无 4K 偷跑、无烧录无内嵌、无 BGM 无特效、命名合规，
且 864 的派生物**没有一件写到 TASK 之外**；两处越界落点均为**空壳（18.860）与既有内容副本（19.861）**，
与本任务素材无关。

STATUS: FAIL
