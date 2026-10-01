# cleanup_log_v2.md — 任务 21 / 素材 864

## 本轮触发点

v2 冻结候选完成后（`combat_episodes_v2.json` + `v2_validate.json` + `program_map_v2.json` + `preview\864-review-v2.mp4` 解码通过 + `selfaudit_864_v2.md`），按 `deliverables-and-qa.md` 的「Mid-run cleanup」与「Realtime cleanup」执行途中清理。

## 拟删清单与本轮决定

| 候选 | 目录/文件 | 删前体积 | 本轮决定 |
|---|---|---|---|
| 旧预览 v1 | `preview\864-review-v1.mp4` | 802,410,248 B | **不删**。生命周期表规定「vN+1 冻结后只留相邻两版（v2 与 v1）」，v1 仍在相邻窗口内，且是对照依据 |
| v1 字幕 | `captions\864-review-v1.srt` + `.stats.json` | ~8 KB | **不删**，同上 |
| v1 时间线 | `timeline\combat_episodes_v1.json` / `program_map_v1.json` / `proxy_map_v1.json` | ~78 KB | **不删**（审计依据，永不删） |
| v1 校验与门禁 | `reports\v1_validate.json` / `qa_v1.json` / `qa_v1_programbounds.json` / `merge_decision_v1.md` | ~95 KB | **不删**（审计依据） |
| v1 预览日志 | `preview\864-review-v1.decode.log` | 3 B | **不删**（相邻两版规则） |
| 取证散帧与稀疏图 | `shots\segN\thumbs\`、`shots\adv*\`、`shots\selfaudit_v1\`、`shots\adjudicate_*\` | 数百 MB | **本轮不删**。`deliverables-and-qa.md` 规定「对应段冻结且联系表 + 审计已覆盖后可删」，而 v2 的自审/对抗审**仍在引用 v1 的取证帧路径**做闭环复核；待 v2 冻结门禁收口、且 4K 成片交付后由 `cleanup_after_master.ps1` 统一回收 |
| 分析用音频 | `audio\audio_16k.wav` | 36,871,588 B | **本轮不删**。生命周期表规定「成片对账后即删」，尚未出 4K；v2 复验仍可能需要重跑分析 |
| 分析代理 | `cache\proxy_360p30.mp4` | 89,403,741 B | **本轮不删**，同上 |
| 分段中间件 | `cache\v1segs\` / `cache\v2segs\` | 约 1.5 GB | **本轮不删**。v2 复验若需重渲可复用（渲染器已带 `-frames:v` 精确帧数，复用条件已可核）；由成片后的收尾清理回收 |
| 冒烟测试残留 | `cache\smoke\` | ~24 MB | **本轮不删**，登记待收尾清理 |

**本轮实际删除的文件：无。**（`cleanup_log` 的存在意义是记录"删了什么、为什么"，本轮没有符合双条件（生命周期标可删 + 结论已被冻结版吸收）的对象。）

## 本轮新增（不是删除，但一并登记）

- `timeline\combat_episodes_v2.json`、`timeline\program_map_v2.json`、`timeline\proxy_map_v2.json`、`timeline\combat_episodes_v2_programbounds.json`
- `reports\v2_validate.json`、`reports\merge_decision_v2.md`、`reports\preview_build_v2.md`、`reports\qa_v2.json`、`reports\qa_v2_programbounds.json`、`reports\preview_probe_v2.json`、`reports\preview_media_filters_v2.log`、`reports\srt_crosscheck_v2.json`
- `captions\864-review-v2.srt`、`captions\864-review-v2.stats.json`
- `preview\864-review-v2.mp4`、`preview\864-review-v2.decode.log`

## 一次已执行的纠正性删除（记录在案）

`C:\Project\永劫无间\123\21.864永劫无间 2026-05-13\cache\srt_crosscheck.py`（4,357 B）—— 指挥在写脚本时把任务目录名里的日期打错（`2026-09-30` 误写为 `2026-05-13`），在 `123\` 下多建了一个同编号目录。**该目录内只有这一个文件、创建于当次、字节数与内容均可核**；删除前已验证「目录内文件数 == 1 且文件名 == srt_crosscheck.py」，随后删除该文件与两个空目录，并复查 `123\` 下编号无重复。修正后脚本重写到正确路径 `123\21.864永劫无间 2026-09-30 02-57-13\cache\srt_crosscheck.py`。

**这次误建是编号复用风险**，所以留档。

## 合规登记：不属于本任务可自行处置的越界落点（0 字节，未删）

预检 `check_video_environment.ps1` 会因 `C:\Project` 下的乱码目录报 `[BLOCKER] stray dirs beside project`（退出码 2）。**该乱码树现已核实为「0 文件、纯空目录壳」**（递归 `Get-ChildItem -Recurse -Force` 结果：8 个目录、**0 个文件**），因此没有任何数据面临风险或丢失。

| 归属 | 路径 | 创建时间 | 判据 | 本轮处置 |
|---|---|---|---|---|
| **本任务的 v2 对抗审 adv2** | `C:\Project\姘稿姭鏃犻棿\123\21.864姘稿姭鏃犻棿 2026-09-30 02-57-13\shots\adv2r2\sel_r2_residue` | **17:38:19** | 落在本任务 adv2 的工作窗口内（其 `shots\adv2r2\mk.ps1` 落盘于 17:38:29，前 10 秒）。成因与 AGENTS.md §1 记载的失败模式一致：**中文任务路径作为命令行参数被 ANSI 化**（`永劫无间` → `姘稿姭鏃犻棿`），脚本文件本身是纯 ASCII 所以合规，是**参数**而非源码出问题 | **不删**。理由：① 空目录壳，0 字节，无数据可保；② 删目录属破坏性动作，按 AGENTS.md §1「必须由人确认后执行，不要自己删」；③ 该乱码树还含并发的 860 会话的壳，一起删会误伤别人 |
| **并发的 860 会话** | `C:\Project\姘稿姭鏃犻棿\123\18.860姘稿姭鏃犻棿2026-09-26 22-43-03\shots\adv_v5_3` | 13:13:59 | `18.860` 任务目录在 17:37:16 仍有文件更新 → 会话活跃 | **不删**（不是本任务的目录） |
| **并发的 861 会话** | `C:\Project\永劫无间\123\19.861永隙无间_x.txt`（78,884 B） | 13:19:35 | SHA256 与 `19.861永劫无间 2026-09-26 23-26-54\shots\adv_v5\adv1\lane_meta.txt` 相同，是并发会话的副本 | **不删**（不是本任务的产物） |

**建议的处置（需人执行）**：等 860 / 861 两个会话收工后，跑
`& 'C:\Project\永劫无间\scripts\sanitize_stray_dirs.ps1' -Remove`（默认 dry-run，加 `-Remove` 才真删）。
在那之前，`check_video_environment.ps1` 会持续报该 BLOCKER —— **它只影响「新任务开工」，不影响本任务在制**（本任务的 T0 预检已在该目录出现之前 exit 0 通过）。

**本任务自查**：19 个 `.ps1` 全部**纯 ASCII、含非 ASCII 字节者 0 个**（角色 D 验收独立复核），不存在源码层面的 BOM 风险。本次两处乱码的成因都是**命令行参数**，已定位到具体路（adv2 的 `-TaskDir`），已记入 `reports\dispatch_ledger.md`。

## 一处已刷新的过期证据（记录在案）

`reports\preview_probe_v2.json` 曾是**重渲前的过期快照**（记录 `size=781,114,172`、`avg_frame_rate=270643200/4510843 ≈ 59.99995`，即 CFR 修复**之前**的那一版）。角色 C 验收时发现并报 WARN。**已用交付件重新生成**，现记录 `size=781,042,716`、`duration=587.354333`、`r=avg=60/1`、`nb_frames=35,240`、`bit_rate=10,465,670`。教训：任何"探测快照"在**重渲之后必须重跑**，否则会变成指向旧版本的假证据。

## 删后验证

本轮无删除，故无"删后验证"项。冻结状态验证见 `reports\qa_v2.json`（fail 0）与 `reports\qa_v2_programbounds.json`（fail 0）。

## 成片对账

**尚未出 4K 成片**（用户本轮未授权「输出 4K 成片」）。成片路径、分辨率/帧率/编码器/实际码率、体积、外挂 SRT 路径、原始素材未动声明将在 4K 交付时补记。
