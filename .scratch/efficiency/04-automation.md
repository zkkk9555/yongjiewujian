# 04 · 可脚本化的人工步骤诊断

> 角度：**哪些人工步骤可以被脚本吃掉**。
> 与 `02-serialization.md`（并行度）互补——那篇讲"步骤该同时跑"，这篇讲"步骤根本不该由人跑"。
> 全部结论只读取证，未改任何任务目录、脚本或时间线。

---

## 0 一页结论

| 数字 | 值 | 取证 |
|---|---|---|
| 躺在任务目录里的一次性脚本 | **144 个 / 1.25 MB** | `123\**\reports\tools\*.py`、`cache_scripts\*.py`、`timeline\evidence_*\*.py` |
| 项目脚本 `scripts\` | **15 个** | 其中 3 个是回归测试 |
| skill 脚本 `skills\naraka-highlight-studio\scripts\` | **8 个** | `qa_gate.py` 28 KB 是唯一门禁实现 |
| 重复手写类别 | **17 类**，其中 **12 类有 ≥2 份内容不同的副本** | §1 |
| 建议提升为项目脚本 | **15 个候选**，其中 **4 个已有成品、改路径即可用** | §3 |
| 最高 ROI 的三个 | **① `build_program.py` ② 帧↔秒标定 ③ `subtitle_bodies_are_text` 进 `qa_gate.py`** | §3.1 |
| 会引入**新假 PASS 源**的自动化 | **4 类**，最危险的是"删除段无战斗"自动判定 | §5.2 |

一句话：**项目已经在写项目脚本了，只是每次都重新写一遍、放在任务目录里、然后忘掉。**
144 个脚本对应 15 个项目脚本，复用率 10%。这不是"缺少工具"，是"工具没有被收编"。

---

## 1 重复手写脚本普查（17 类）

副本数 = `123\` 下的实际份数；"内容差异"用 MD5 全量比对得出。

| # | 类 | 副本 | 内容差异 | 差异根因 | 已付出的代价（取证） |
|---|---|---|---|---|---|
| 1 | **字幕映射 `map_captions.py`** | **5**（含 861 的 `map_captions_v2.py`） | 4 份主文件**两两不同**（0 份相同） | 见 §1.1 详解 | 2 次**内容丢失**级 bug；861 为此写了 19.6 KB 的 v2 补丁（是原版的 6 倍） |
| 2 | 转写 `transcribe.py` | 4 | 3 份逐字节相同（855=859=861），864 不同 | 无人收编，靠复制 | 864 改小 100 字节就换了一种切段策略，无人知道差异原因 |
| 3 | 音频活动 `audio_activity.py` | 3 | 2 份相同（855=859，3.5 KB），864 重写（1.9 KB） | 864 嫌原版太重 | 同名不同实现，`analysis\audio_activity.json` 的 schema 无保证 |
| 4 | **程序映射 `build_program.py`** | 3 | 2 份相同（855=859，6.1 KB），864 重写（2.9 KB） | 864 首次复用 `episode_geometry` | 861 的 `program_map_v9.json` 头部混进了 ffprobe 结果 → 映射与探测两件事耦在一个脚本里 |
| 5 | 1 fps 抽帧 | **7** | `extract_lane.ps1`(855/859 相同)、`extract_frames.ps1`(864)、`mkframes.ps1`(860)、`extract_1fps.py`(861)、`make_base1fps_v3.py`、`calibrate_base1fps.py/2.py` | 每次重新发明参数化方式 | 864 版把转义规则写在注释里（`C\\:` 双反斜杠、`%{pts\\:flt}`），**这些规则是 863 的 seg11/seg12 各撞一次才学到的** |
| 6 | 冻结门禁 | **3 实现** | `freeze_gate.py`(855, 8.9 KB)、`freeze_gate.py`(859, 9.8 KB)、`freeze_kit.py`(864, 9.2 KB，从零写) | 各自按当时理解写 | **861 干脆不写脚本**，手搓 `freeze_gate_19_v9.md`。三实现里**只有 864 的 `freeze_kit.py` 含 `subtitle_bodies_are_text`** |
| 7 | 删除段审计 `delaudit_*` | **13**（全在 861） | dense/dense2/calib_signal/coverage/final/hud/hygiene/panel/phases/query/read_timeline/sheet/transcript_audio | 一路一个坑一个脚本 | 864 做**同样的审计用了 0 个脚本**，10 帧全靠手读 |
| 8 | 时间线版本补丁 `patch_*` | **16**（861 8 + 860 8） | 体积 5.8 KB / 57 KB / 7.8 KB / 26 KB / 9.8 KB / 9.7 KB / 20 KB / 7.3 KB | 每版边界改动重写一遍 | 每个都是一次性 JSON 手术，无法回归测试 |
| 9 | 主版偏移 `master_*` | **6**（全在 861） | align_strong / offset_margin / offset_profile / shift_exact / slip_locate / slip_point | 一个问题六个探针 | 864 也撞了同类问题（`qa_gate_axis_defect_863.md`） |
| 10 | 帧时间标定 `calibrate_*` | **3 + 1 手工** | `calibrate_base1fps.py` / `2.py` / `calibrate_timing.py`（861）+ 864 手写 `frame_calibration.md` | 861 先错后复验 | **861 的 v0 坑一就是它**：第一次标定是循环论证（参照系与被测对象同管线），得靠独立复验推翻 |
| 11 | 数值探针（零看图） | **3 + 2 手搓** | `luma_probe.py` / `ui_probe.py` / `frame_diff_probe.py`（861）；863 手搓 numpy 55 列逐帧管道；864 手读 HUD | 每个争议点重新造 | `ui_probe.py` 有一个**写错且从未被调用**的 `mae()`（表达式 `-a[i]+b[i]-b[i]`），是雷 |
| 12 | 联系表 / 帧格 sheet | **5** | `make_sheet_range.ps1` / `build_all_sheets.ps1`（859）、`sheet.ps1`（864）、`delaudit_sheet.py` / `delaudit_hud.py`（861） | 裁切窗口需求各不相同 | 861 已记录裁切窗取景错误（`crop=2100:900:900:450` 把顶部播报整条切在窗外） |
| 13 | 转写转储 `dump_transcript.py` | 2 | 502 B vs 237 B，均不同 | 各自删减 | — |
| 14 | 场景检测 `detect_scenes.py` | 2 | 逐字节相同（1991 B） | 纯复制 | 864 干脆把 `ContentDetector` 内联进 `scene_rms.py`，成为第 3 种形态 |
| 15 | 分路计划 lane_plan | 3 | `build_lane_plan.py`(859) / `make_lane_plan.py`(861) / 内联在 864 派工里 | — | 02 报告 P1「派工单秒数脚本化」与此项重叠 |
| 16 | 渲染 / 校验 | **5** | `render_4k.sh`+`verify_4k.sh`(863)、`render_master_retry.sh`(861)、`render_preview.py`(864)、共享 `seg_render_master.sh`+`verify_master.sh` | 预览与主版分开写 | 864 §2.4：分段渲+concat demuxer 会把 `start_time` 累加成 59.955 fps 触发门禁 FAIL，**这条应该写进渲染脚本默认路径，目前没有** |
| 17 | 对抗审上下文 `make_adv_ctx` | 4（861 v1/v3/v4/v5） | 3.3 → 5.8 → 5.9 → 10.2 KB | 每版加字段 | — |

### 1.1 `map_captions.py` 五份逐份差异（题目点名要查的）

| 份 | 位置 | 大小 | 形态 | 关键差异 |
|---|---|---|---|---|
| 1 | 855 `cache_scripts\` | 5145 | `argparse`，有 `min_dur` 等参数 | 唯一**没有**最终 clamp 的版本；上限 8 s 的 cap 可能把 cue 推出所属场次边界 |
| 2 | 859 `tools\` | 5297 | 同上 + 新增注释块 | 在 1 的基础上补了"cap 之后重新 clamp 到 episode 末"的循环块。注释原话：**"the original order was a real bug"** —— 典型"复制一份再修" |
| 3 | 861 `tools\` | 3350 | **硬编码 `TASK = r"C:\Project\永劫无间\123\19.861..."`**，无 argparse，无 max_dur，无 clamp | 一次**回退式重写**。文件是无 BOM 的 UTF-8，任何 PowerShell 读它都会显示 `姘稿姭鏃犻棿` |
| 4 | 864 `tools\` | 5095 | **argv 驱动**（transcript.json + cut_list.json → srt + stats），常量 `MIN_DUR/MAX_DUR/MIN_GAP/MAX_CPS/MIN_PIECE` | **唯一正确的一份**：文本直取转写 JSON，从不回读 SRT；零跨切由 `locate()` 统一保证；自带 10 项 stats |
| 5 | 861 `map_captions_v2.py` | **19596** | 硬编码 TASK | 为修"序号被写成正文"而重写的补丁，**是正确版 4 的 3.8 倍大** |

> 五份、五种行为、两次内容丢失级 bug、零份进入 `scripts\`。
> 正确的实现（份 4）已经在 864 里，只需要搬家 + 加两个回归 fixture。

---

## 2 横切所有类的隐性税：编码与路径

这三项**不提升任何脚本也已经在收费**，且是三类返工的直接成因。

### 2.1 无 BOM 的非 ASCII 脚本：144 个里的 90 个

| 状态 | 数量 |
|---|---|
| 含非 ASCII 字节但**无 UTF-8 BOM** | **90** |
| 含非 ASCII 且有 BOM | 9 |
| 纯 ASCII（安全） | 45 |

对 `.py` 无害（Python 恒按 UTF-8 读源码）；**对 `.ps1` 是 AGENTS.md §1 那条 BLOCKER 的成因**。
本次扫出的 `.ps1`：`extract_lane.ps1`(×2)、`extract_frames.ps1`、`sheet.ps1`、`mkframes.ps1`、`preview_manifest.ps1`、`seg_duration_audit.ps1`。

### 2.2 硬编码任务路径字面量：≥30 份

`123\*\reports\tools\*.py` 里 **31 个文件**把 `TASK = r"C:\Project\永劫无间\123\19.861..."` 写死。
中途有一批改成了 `os.environ["NJ_TASK"]`（`cmd_frames.py`、`luma_probe.py`、`ui_probe.py`、`make_adv_ctx_v3/v4`、`patch_to_v3/v4/v5`、`patch_spec_v6..v9`），
另有一批 `os.environ.get("NJ_TASK") or r"C:\Project\..."` 双写（`make_adv_ctx_v5.py`、`patch_spec_v6..v9`）。
**同一个任务目录里 31 个脚本用了 3 种取路径方式**——这正是"每次重新写"的直接指纹。

### 2.3 双编码写盘：证据文件不可读

| 文件 | 乱码行数 | 性质 |
|---|---|---|
| `864\reports\audit_v1_voice_dump.txt` | **72** | **双重编码，UTF-8 存的是 GBK 乱码字符**（`鎺ヨ窇娉曡兘` 应为「按就跑法能」） |
| `864\reports\audit_v1_audio_dump.txt` | 13 | 同上 |

**必须排除的误判**：另有约 50 处 `姘稿姭鏃犻棿` 出现在 861/863 的 `.md` 里，那些是**在讨论乱码事故本身**，不是损坏。已逐条抽样核对（`dispatch_ledger.md`、`accept_863_v2.md`、`reverify_863_v2.md`）。

附带发现：同一份 `audit_v1_voice_dump.txt` 里 `lp=-0.447 nsp=0.311` 在 80 条 cue 上**恒定不变**——该指标是按窗口算的，不是按 cue 算的。

### 2.4 静默失败比崩溃贵（863 实测）

`cache\frame_pick.ps1` 因缺 BOM **静默返回 `COUNT=0`**，不报错。扫描员若不查 COUNT，会以为自己那一秒没有帧，
**然后在错误的前提下继续扫完整条路**。同任务 **6/14 路**（seg1/2/3/4/6/10）撞上这一坑。
`pull_frames.ps1` 同因崩溃（可见），`frame_pick.ps1` 同因静默（不可见）——后者危险一个量级。

### 2.5 ffprobe 输出自带乱码路径

`863\analysis\source_probe_raw.json` 的 `format.filename` 是
`E:\PR瀵煎嚭\863姘稿姭鏃犻棿....mp4`（GBK 乱码文本）。
这意味着**每个任务都要手工把探测结果里的路径修回真路径**，才能与 `source_baseline.json` 逐字段比对。
864 §2.5 已经为此建了 `source_baseline.json`，但没有建"路径修复"这一步。

---

## 3 候选提升为项目脚本清单（15 个）

ROI 口径：**一次手工做要多久 × 每局做几次 × 每局省多少**。
"一次手工耗时"凡是能挂上实测账单的都已注明出处；纯估算的标 `est`。

### 3.1 最该先做 3 个

| 排序 | 候选 | 源 | 一次手工 | 每局次数 | 每局省 | 理由 |
|---|---|---|---|---|---|---|
| **①** | **`scripts\build_program.py`** | 864 `build_program.py` + `fix_paths.py` | 25 min（重推 program↔source 三路求和） | **6–9 次**（每版本一次） | **2.0–3.0 h** | 已是成品、已复用 `episode_geometry`、**自校验（三路独立求和互验）**。零判断、纯只读输入、幂等。改个路径就能上线 |
| **②** | **`scripts\calibrate_frame_axis.py`**（帧↔秒标定） | 864 `frame_calibration.md` + 861 `calibrate_timing.py` | **861 实测 ≈1.5 h**（两次标定 + 一次独立复验 + 一次台账改写）；864 自测 **3 min** | **1 次**（全任务 14–29 路受益） | **25–90 min** | 864 原话："成本 3 分钟，建议固化进标准流程"。**必须内置 861 的反循环论证护栏**：参照系必须是 `-ss T±δ` 显式抽帧，不得用同管线重建的条带 |
| **③** | **`subtitle_bodies_are_text` 进 `qa_gate.py`** | 864 `freeze_kit.py` | **864 实测：靠人眼在删除段审计里顺带发现** | 常驻 | **防一次整轮返工（≥1 h）** | 手册（POOL L-046）已写，`freeze_kit.py` 已实现，**但共享 `qa_gate.py` 里没有**——grep 全 skill 目录零命中。全绿假 PASS 的教科书案例 |

### 3.2 其余 12 个

| # | 候选 | 源 | 一次手工 | 每局次数 | 每局省 | 风险 |
|---|---|---|---|---|---|---|
| 4 | `scripts\map_captions.py`（含 `fix_srt_gaps` 合流） | 864 正确版 | 30–90 min/次（含调试） | 6–9 | 1.5–4.5 h | 低（只读输入） |
| 5 | `scripts\hud_curve.py`（弹匣/血量机器读数曲线） | 864 §4.2 表格为手工 | 25 min/争议段 | 2–4 | 50–100 min | 中（见 §5.2-d） |
| 6 | `scripts\deletion_voice_scan.py` | 864 `voice_index.py`（已成品） | **864 实测 40 min/删除段**（手工抄 SRT 表） | 6 | 2.5–4 h | **高（见 §5.2-a）** |
| 7 | `scripts\fragmentation_report.py` | 无（新写） | 0（现状：无） | 1 | 预防返工 | **中高（见 §5.2-c）** |
| 8 | `scripts\luma_probe.py` / `ui_probe.py` / `frame_diff_probe.py` 三合一 | 861 三份 | 20 min/次（手搓管道） | 3–6 | 1–2 h | 中（见 §5.2-b） |
| 9 | `scripts\extract_lane.ps1`（ASCII-only + 全参数化） | 864 `extract_frames.ps1` | **863 实测 20–30 min/路** | 14 | **2.3–7 h**（当 BOM 坑复发时） | 低 |
| 10 | `scripts\write_text.py`（UTF-8 写盘护栏） | 新写（~30 行） | 15 min/次（发现+重跑） | 2–4 | 30–60 min | 低 |
| 11 | `scripts\timeline_patch.py`（边界改动，带 diff + 幂等） | 861/860 的 16 个 `patch_*` | 25–40 min/版 | 6–9 | 2.5–6 h | 中（有写操作） |
| 12 | `scripts\scenes_and_rms.py` | 864 `scene_rms.py` + `rms_only.py` | 30 min | 1 | 30 min | 低 |
| 13 | `scripts\transcribe.py` | 4 份中 3 份相同 | 20 min | 1 | 20 min | 低 |
| 14 | `scripts\session_helpers.ps1`（同进程 dot-source，绕开 ANSI 往返） | 863 `cache\session_helpers.ps1` | 40 min | 1 | 40 min + 防复发 | 低 |
| 15 | `scripts\proxy_build.sh`（`-fps_mode passthrough` 代理） | 864 `cache\proxy_960.mp4` 渲法 | 15 min | 1 | 15 min + **1 个数量级加速** | 低 |

### 3.3 合计

按 861（33.5 h）/ 863（18.2 h）/ 864（10.9 h）三局的中位次数估：

| 局 | 现状 span | 可脚本化部分 | 预计压到 |
|---|---|---|---|
| 861 | 33.5 h | ≈ 9–13 h | 20–25 h |
| 863 | 18.2 h | ≈ 4–7 h | 11–14 h |
| 864 | 10.9 h | ≈ 2.5–4 h | 7–8.5 h |
| **三局** | **62.6 h** | **≈ 16–24 h（26–38 %）** | **38–48 h** |

**注意这不是"每局 10 h"的解决方案。** 62.6 h 里 46.5% 是纯等待（02 报告的并行度问题），
脚本能吃掉的是那 26–38% 里属于"重复劳动"的部分。
**并行化和脚本化必须同时上，只上一个都到不了目标。**

---

## 4 题目点名的五类动作，可行性判定

| 动作 | 现状 | 判定 | 关键约束 |
|---|---|---|---|
| **帧↔秒点映射与标定** | 861 写了 3 个脚本（其中一个是循环论证）、864 手工写了一份 md | **可做，已有成品，最高 ROI** | 参照系必须是 `-ss T±δ` 显式抽帧。864 的 `frame_calibration.md` 已给出正确方法（PSNR 峰值法，5 行对照，峰值 21.37 dB vs 邻侧 15 dB） |
| **HUD 机器读数曲线** | 864 §4.2 **纯手工**：10 帧的弹匣 `50/50→46→44/50→(冻结 50 s)→41→37→34→31` 是人在 640/960 px 帧上一个个数出来的 | **可做，但必须先解决 OCR** | 这是本清单里唯一**需要新建能力**（不是搬家）的一项。`crop` 窗口必须 8× 放大逐字确认——864 §4.1 证明 HUD 上 `攻击提升/暴击/还阳·愈` 与敌方名牌位置极近、会读错。**先在 861/864 已有的人工答案上做回归** |
| **`subtitle_bodies_are_text`** | **手册（POOL L-046）写了；864 的 `freeze_kit.py` 实现了；共享 `qa_gate.py` 没有** | **可做，纯搬运，零新逻辑** | ⚠️ **不能直接照搬 864 的写法**（见 §5.2-e） |
| **碎片化检测（≥3 段且单段 <6 s）** | **无人做** | **可做，但规则本身有已知反例** | 864 §3.1 明写：`combat_002` 270 秒、`combat_005` 249.5 秒，"任何'这场仗超过 X 分钟就该切一刀'的直觉都是错的"。**纯段数阈值会在这类长战上误报** |
| **删除段语音战斗词扫描** | 864 有 `voice_index.py`（成品，纯 JSON 关键词扫描），但 `audit_v1_voice_dump.txt` 是手工版且**乱码不可读** | **可做，**但**绝不能做成自动 PASS**（见 §5.2-a） | `voice_index.py` 自己的 docstring 写得很清楚：**"it proposes candidates, it never decides"** |

---

## 5 风险分级

### 5.1 高 ROI 且低风险（纯只读、不改数据、结论是数字不是判决）

这些可以立刻做。共同特征：**输出的是可核对的数字表，人做最终判断，脚本不产生 PASS/FAIL 之外的语义。**

1. **帧↔秒标定** — 只输出「锚点 → PSNR 表 → 峰值位置」。不判"对不对"。
2. **HUD 机器读数曲线** — 只输出「秒 → 弹匣读数序列」。不判"是否在战斗"。
3. **删除段语音/音频命中表** — 只输出「cue 索引 → 原文 → 命中词」。**建议保持 advisory**。
4. **`build_program.py`** — 三路独立求和互验，两条不一致就报错，不猜哪条对。
5. **字幕映射** — 输入只读（transcript JSON + cut list），输出 SRT + stats；`stats` 是数字不是判决。
6. **编码/路径护栏**（#9/#10/#14）— 纯基础设施，不参与任何判定。

### 5.2 自动化了但会引入新假 PASS 源（**必须先立阳性对照**）

> 判据一句话：**门禁只能在"它验过的输入"上可信。**
> 引入一个新门禁而没有阳性对照，等于把"没人查"变成"报了绿"——后者更危险。

#### (a) 🔴 最危险：**「删除段无战斗」自动判定**

**为什么危险**：861 的 `v1` 已经用血买过一次——「转写否定这一重不成立」，
稀疏图/无语音**证不了"没发生战斗"**。把 `voice_index.py` 的关键词扫描升成门禁，
就会把"无战斗词"直接翻译成"无战斗"，**产出一个必然出错、且带 PASS 标记的结论**。
这正是 864 §5 的模式：「机器门禁全绿，但交付物是错的」。

**正确形态**：门禁是 **"缺席审查"门**，不是 **"缺席战斗"门**——
> `deleted_intervals` 中任一段若命中 `combat_hits`，则该段**必须**存在一份署名的人工裁决记录；
> 无记录 → FAIL。**扫描结果只决定"要不要审"，不决定"审出没有"。**

#### (b) 🟠 UI 面板探针（`ui_probe.py`）

现状是**最近邻分类器**：`verdict = OPEN if a < b else closed`，**无阈值**，裁切窗硬编码 `690x820+1230+80`。
它 PASS 的条件是"参照帧本身是对的"。而 863 §1 记录了**「只量了 UI 的一个实例」四次复发**
（v2 多挖 3 秒战斗、v3 漏 783.9–786.6、v4 漏第二次闪烁、v4 漏洞左界前两个实例）。

**必须先立**：≥3 个已知开 / ≥3 个已知关的对照秒，**报告分离度而非判决**；
分离度不足时脚本必须 **ABSTAIN**，不得二选一。

#### (c) 🟠 碎片化检测（≥3 段且单段 <6 s）

纯阈值规则，且**已知反例存在**（864 的 270 秒 / 249.5 秒长战）。
一旦误报，唯一的理性反应就是把这个门静音——**从此它保护不了任何人**。

**必须先立**：拿 864 的 5 场 4 切口（应 PASS）与 861 v1 的 9 场 7 切口（应报）做双向 fixture。
另需引入 engage/outcome 上下文，**段数不是充分条件**。

#### (d) 🟡 HUD 读数 OCR

864 的曲线是**人读出来的正确答案**——这正好是天然的阳性对照集。
但 OCR 会读错 HUD（`攻击提升` vs 敌方名牌，见 864 §4.1）。
**先在 861+864 的已知答案上跑，只报读数与不确定度，不报"是否开火"。**

#### (e) 🟡 `subtitle_bodies_are_text` 的写法

864 版的实现是**单边断言**：`not numeric_bodies and not empty_bodies`。
它能逮住本次事故（正文=序号），但**逮不住"正文被换成了另一段非数字文字"**——
那正是 POOL L-046 说的"一致性检查查不出内容被换掉"的另一种形态。
**单边断言本身就是一个新的假 PASS 源。**

**正确形态（双边）**：
> `body` 必须**是权威源（transcript JSON）某条 cue 文本的子串/规范化后相等**，
> 且 `body` 非纯数字。同时保留"条数与 stats 一致"作为**必要非充分**条件。

#### (f) 🟡 坐标系统一（节目秒 vs 源秒）

864 §5.2：`qa_gate.py` 拿节目秒比源秒，第一场不从源 0 开始时就误报。
**危险不在于现在报错，而在于"自动化把它改成 PASS"**——
如果自动加的 `subtitle_bounds()` 回落逻辑选错分支，一个真实的跨切缺陷会被吞掉。
864 的做法是对的，**必须保留**：改完跑 `test_whole_battle_gates.sh` → `RESULT: PASS`，
且该测试必须继续覆盖"第一场从源 0 开始"和"不提供 program_start"两种历史形态。

#### (g) 🟡 三门禁合一（`freeze_gate.py` / `freeze_kit.py` / `qa_gate.py`）

**ROI 最高，风险也最高**。三份实现由不同路在不同时期按各自理解写成，
合并**只能丢覆盖不能增覆盖**，除非先做：
1. 三方 check-name 集合取**并集**（861 的 `freeze_gate_19_v9.md` 里还有 `qa_gate.py` 没有的项）；
2. 拿 849/854/855/858/859/860/861/863/864 **九个任务的历史报告逐一回归**，输出前后 check 名单 diff；
3. 任何 check 消失 → 拒合并。

---

## 6 建议落地顺序

| 阶段 | 动作 | 理由 |
|---|---|---|
| **第 0 步（今天就能做，零风险）** | 把 144 个一次性脚本里**已验证正确**的 4 个搬进 `scripts\`：`build_program.py`、`map_captions.py`(864 版)、`voice_index.py`、`extract_frames.ps1` → 改名 `extract_lane.ps1` | 成品搬家，无新逻辑，最高 ROI。搬完立刻冻结副本，否则第 6 类重复会再长回来 |
| **第 1 步** | `subtitle_bodies_are_text` 双边化后进 `qa_gate.py`；补两个回归 fixture（本次事故的真/假 SRT） | 防的是"全绿假 PASS"，收益不是小时数而是**整轮返工** |
| **第 2 步** | `calibrate_frame_axis.py` + 内置反循环论证护栏；写进 `roughcut-launch.md` 标准流程 | 864 已给出 3 分钟版本 |
| **第 3 步** | 编码护栏：`.ps1` 全部 ASCII-only 全参数化 + `write_text.py` + `session_helpers.ps1`；给 `check_video_environment.ps1` 加一条**扫描 `123\` 下 `.ps1` 无 BOM** 的检查 | 这是唯一一类"复发就静默出错"的税 |
| **第 4 步** | `hud_curve.py`（先在 861+864 人工答案上做回归）+ 三探针合一 | 需要新建 OCR 能力，放最后 |
| **第 5 步（需授权）** | 三门禁合一 + 碎片化检测 + 删除段审查门 | 都必须先立阳性对照，且第 5(b)(c) 两项在立对照前**不许上线** |

**一条硬规矩**（建议写进 `AGENTS.md §8`）：
> 任何写在 `123\<任务>\reports\tools\` 或 `cache_scripts\` 下的脚本，
> 若被复用第二次，**必须**在同一轮内收编进 `scripts\` 或 skill `scripts\`；
> 收编前它不算证据，只算草稿。收编时必须附一条回归 fixture，
> **证明它对至少一个历史任务的重跑结果与人工当时的答案一致**。

---

## 7 复算方法

```powershell
# 一次性脚本总量与按任务分布
Get-ChildItem 'C:\Project\永劫无间\123' -Recurse -File -Include *.py,*.ps1,*.sh |
  Group-Object { ($_.FullName -split '\\')[3].Substring(0,5) } |
  Select-Object Count, Name

# 同名副本的内容差异（MD5 全量比对，不看大小）
Get-ChildItem 'C:\Project\永劫无间\123' -Recurse -File -Include *.py,*.ps1,*.sh |
  Group-Object Name | Where-Object Count -gt 1 | ForEach-Object {
    $_.Name; $_.Group | ForEach-Object {
      '  {0}  {1}  {2}' -f (Get-FileHash $_.FullName -Algorithm MD5).Hash.Substring(0,8), $_.Length,
        $_.FullName.Replace('C:\Project\永劫无间\123\','')
    }
  }

# 无 BOM 的非 ASCII 脚本（.py 无害，.ps1 是 BLOCKER 成因）
Get-ChildItem 'C:\Project\永劫无间\123' -Recurse -File -Include *.py,*.ps1 |
  ForEach-Object {
    $b=[IO.File]::ReadAllBytes($_.FullName)
    if (($b|?{$_ -gt 127}).Count -and -not($b[0] -eq 0xEF -and $b[1] -eq 0xBB -and $b[2] -eq 0xBF)) {
      $_.FullName }
  }

# 硬编码任务路径字面量
Select-String -Path 'C:\Project\永劫无间\123\*\reports\tools\*.py' -Pattern '\\123\\'

# subtitle_bodies_are_text 是否进了共享门禁（当前：否）
Select-String -Path 'C:\Project\永劫无间\skills\naraka-highlight-studio\scripts\*.py' `
  -Pattern 'bodies_are_text|numeric_bod'
```

---

## 8 一句话给决策者

**144 个一次性脚本对应 15 个项目脚本——缺的不是工具，是收编动作。**
最该先做的三个是 `build_program.py` 搬家、帧↔秒标定固化、`subtitle_bodies_are_text` 进共享门禁；
最危险的自动化是把「删除段无战斗」做成自动 PASS——
**扫描只能决定"要不要审"，永远不能决定"审出没有"。**

---

STATUS: DONE
