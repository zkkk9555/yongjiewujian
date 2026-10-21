# Deliverables and quality gates

## Internal project package

Keep the following inside the numbered task directory:

```text
reports/source_probe.json
reports/batch_manifest.json
reports/event_candidates.json
reports/qa.json
timeline/master.otio
timeline/premiere.xml
timeline/edit.edl
timeline/markers.csv
audio/stems/
captions/
effects/
preview/review.mp4
deliverables/master_*.mp4
style_snapshot.json
```

Export OTIO/Premiere XML/markers via `scripts/export_edit_timeline.py` as soon as the roughcut passes review (835 v13: 5 events/569s) — do not defer rebuildable timelines to the final master.

The user may receive only the final MP4 and a preview. The other files make revisions incremental and auditable.

## Versioned naming, lifecycle, and cleanup

任务目录约定不变：`C:\Project\永劫无间\123\<编号>.<素材文件名>\` 是唯一派生输出目录。`<序号>` = 任务编号数字（如 `840`）。`E:\OBS` / `E:\PR导出` / `E:\Cujian导出` 不在清理范围内。

### Naming rules

```text
preview\<序号>-review-vN.mp4          # 粗剪预览（只到 720p），例 preview\840-review-v3.mp4
preview\<序号>-review-vN.concat.txt   # concat 分段合成伴随文件（直接单次渲染则无）
preview\<序号>-review-vN.decode.log   # 全片解码通过记录，一预览一日志（reports/ 不再存预览日志）
captions\source.srt / source.txt / source.vtt / source_transcript.json  # 转写源，永久保留，不加版本号
captions\<序号>-review-vN.srt         # 节目时间线字幕（已做跨段断裂检查）
captions\<序号>-review-vN.stats.json  # 字幕统计（条数/复读过滤/断裂切断记录）
timeline\combat_episodes_vN.json      # 唯一真源：episodes + deleted_intervals 内嵌
timeline\program_map_vN.json          # 节目时间映射（源↔节目对照）
timeline\validate_vN.json             # validate_combat_timeline.py 对同版本 JSON 的实跑结果
reports\selfaudit_<序号>_vN.md        # 冻结前自审（命名三分立见 roughcut-launch.md §3.5）
reports\accept_<序号>_vN.md           # 验收结论
reports\reverify_<序号>_vN.md         # 复验闭环
reports\workflow_notes_<序号>.md      # 该任务唯一沉淀笔记（单文件，内部按 vN 分节）
reports\cleanup_log_vN.md             # 每次删除落盘记录
reports\dispatch_ledger.md            # 启用并行编排才有；有则永久保留（三态 PARTIAL/BRIDGED/FROZEN 只追加，见 roughcut-launch.md §2.8）
reports\merge_decision_vN-partial-r{k}.md  # 岛草稿（g升级）：永不转正、不进字幕渲染自审；任一边界改动即作废重出
reports\merge_decision_vN-draft.md         # 预合专员岛 proposal（g升级）：禁碰时间线与台账
```

冻结三件套 = 同 N 的 `combat_episodes_vN.json` + `program_map_vN.json` + `validate_vN.json`。`combat_episodes.json`（无版本号）只视为当前冻结版的复制，冻结瞬间更新一次，各 vN 文件永不覆盖。成片命名沿用旧规则不变：`<源文件名> cujian.mp4`（见下文 4K 节），`deliverables/` 内只留一份同名拷贝或以 README 指明外部成片绝对路径。旧名（`preview\review_vN.mp4`、`captions\preview_vN.srt`、`validate_check_main.json`、散落 `preview_*.log` 等）不批量追改旧任务，新任务按本节执行。

OTIO / Premiere XML / markers 落盘后随冻结版保留一版，旧版与时间线同进退。

### File lifecycle

状态：**保留** = 不得删；**可删** = 满足前置条件后允许删（仍走 cleanup 流程）。

| 类 | 文件 | vN 冻结时 | vN+1 重做时 | 成片交付后 |
|---|---|---|---|---|
| 源探测/转写源 | `analysis\source_probe_raw.json`、`captions\source.*`、场景 Scenes.csv、音频活动 csv/json | 保留 | 保留 | 永久保留 |
| 提取音频 | `audio\audio_16k.wav`（可再生） | 保留 | 保留 | 可删 |
| 证据图 | `shots\contact_*.jpg`（联系表） | 保留 | 保留 | 保留 |
| 取证散帧/稀疏图 | `shots\verify\`、`v3fix\`、`tail_*.jpg`、`sheet*` 散帧、`shots\thumbs\` | 保留 | 对应段冻结且联系表 + 审计已覆盖后可删 | 可删（只留审计引用的边界高清帧） |
| 时间线/字幕/预览 | `timeline\*_vN.json`、`captions\*-review-vN.*`、`preview\*-review-vN.*` | 冻结版保留，旧版暂留 | 只留相邻两版（vN 与 vN+1），vN-1 及更早可删 | 只留冻结版一版，其余可删 |
| 审计验收 | `selfaudit/accept/reverify/workflow_notes/dispatch_ledger/cleanup_log` | 保留 | 全部保留 | 全部永久保留 |
| 中间件 | `vN_roundK_audit.md`、`roughcut_*_review_ready.md`、散落 0 字节 log、旧 concat txt、`edit_timeline*`、`candidate_clips*.csv`、`auto_editor_temp\`、`cache` 外渲染中间件、作废 partial/draft（g升级：旧 N 下全部 partial/draft，边界改动即作废） | 当轮需要则保留 | 结论被三分立文件吸收后可删 | 可删 |
| 缓存脚本 | `cache\*.py` | 保留 | 保留 | 保留 |

重做 vN+1 真正需要：源片（只读）+ 上一冻结版 `combat_episodes_vN.json` + `validate_vN.json` + `selfaudit/accept_vN.md`（问题清单）+ `captions\source.*` + `source_probe_raw.json`；按需加未改动段的联系表/边界帧/场景与音频活动参考/`cache\remap_*.py`。不需要旧节目字幕 SRT、旧 program_map、旧 concat txt 与旧 decode log（新时间线一切点必须重映射重算）。旧预览分段复用仅为例外加速路径：该 episode `[source_start, source_end]` 一秒未变且 ffprobe 对时长通过且复用决定写入 merge_decision/workflow_notes，缺一即从源片重渲。

### Mid-run cleanup（vN+1 冻结后，以省磁盘为目的）

冻结定义：`combat_episodes_vN+1.json` + `validate_vN+1.json` + `preview\<序号>-review-vN+1.mp4` 解码通过 + `selfaudit_<序号>_vN+1.md` 四者齐。动作：预览/字幕/时间线只留相邻两版（例 v3 冻结后可删 v1，只留 v2+v3），被删版本结论须已吸收进新版 selfaudit 或 workflow_notes（删文件不删结论）；取证散帧与稀疏 `thumbs\` 在对应段冻结且联系表已覆盖后可删，保留联系表 + 审计点名的边界高清帧；`cache\*.py`、转写源、探测、场景/音频活动任何时刻不删；空日志与 0 字节文件确认为空即可删并记 log。

### Realtime cleanup（工作期间即时清理，保 C 盘简洁）

- 旧版预览不等收尾：vN+1 可解码可用即删 vN-1 及更早旧预览（含 concat txt 与 decode log），成片后只留冻结一版预览。11.844 教训：单任务 4 版旧预览占 2.2GB，必须在工作期间逐版清，不堆到收尾。
- 散帧段冻结即清：对应段冻结且联系表 + 审计已覆盖，散帧与稀疏 `thumbs\` 当轮即删，不等 vN+1。
- 可再生大文件成片即删：`audio_16k.wav`（11.844 单文件 70MB）成片对账后即删，用户明确要留 stems 除外并注明。
- 触发器（事件绑定，不是新规则）：渲染员在 `preview_build_vN.md` 落盘同时检查并执行旧预览清理；修线员在 `merge_decision_vN.md` 确认段冻结同时列出本段可删散帧；指挥在台账回收行确认清理已记 `cleanup_log`，未记即视为该路未完工。
- 每次删除仍记 `reports\cleanup_log_vN.md`（无 log 的删除视为违规）；只删本任务目录内派生文件，绝不碰源片、`.video-tools\`、其他任务目录、`123\workflow_upgrade\`。

### Master ownership（成片归属：E 盘是唯一归属）

**4K 成片的唯一归属是 `E:\Cujian导出\<源文件名> cujian.mp4`。**
任务目录**不得长期持有成片**——它只承载可再生的过程物与文本证据。

出 4K 的顺序（不可颠倒）：

```text
1. 渲 4K 到 E:\Cujian导出\<源文件名> cujian.mp4     <- 直接渲到交付目录，不进任务目录
2. verify_master.sh 验收 E 盘那一份
3. cleanup_after_master.ps1 收尾（自动）
```

> 2026-09-30 立。此前成片长期留在 `deliverables\`，849 / 854 / 859 各自在任务目录与 E 盘各存一份，
> **重复约 6.2 GB**；对外报路径时报的是任务目录路径，被判为"输出错目录"。两条是同一个根因。

### Post-master cleanup（成片交付后的固定步骤，**不是可选项**）

用户说「输出 4K 成片」= 授权整条交付链。**成片一旦落到 E 盘并通过验收，本步骤自动执行，
不额外问用户、不需要用户手动发起。**

```powershell
& 'C:\Project\永劫无间\scripts\cleanup_after_master.ps1' -TaskDir 'C:\Project\永劫无间\123\<编号>.<素材名去扩展名>'
```

**交付闸门（先证明成片已落地，再删任何东西）**：脚本先在 `E:\Cujian导出\` 找
`<素材名>*.mp4`（非空）。**找不到或文件为 0 字节 -> 拒绝删除、一个字节都不删**，报 `[BLOCKED]`
并列出任务目录里现有的成片副本。这是数据丢失护栏，**优先级高于省磁盘**。

通过闸门后：

- **删**：`preview\`、`cache\`、`shots\`、`audio\`（可由源素材再生），
  以及 `deliverables\*.mp4` 的**成片副本**（只删 mp4 文件，`deliverables\` 目录本身保留）
- **留**：任务目录本身（取号规则读它，删掉会导致编号复用）、`timeline\`、`reports\`、
  `analysis\`、`captions\`、所有根级文件
- **为什么留目录**：真正值钱的是约 10 MB 的时间线与审计记录（"这段为什么留、那段为什么删、谁核过"），
  而 849 实测 3.39 GB 里有 3.38 GB 是可再生的。删重量、留证据、留目录壳。
- **护栏**（脚本自带，缺一即拒）：E 盘无正本 -> 拒绝；任务目录不在 `123\` 直接子级 -> 拒绝；
  待删路径解析后不在任务目录内 -> 拒绝；先写 `reports\cleanup_log_after_master.md` 再删
  （无 log 的删除视为违规）
- **幂等**：已清过再跑一次只会报 SKIP

> 历史：849 的 `reports\cleanup_log_v4.md §5` 早就登记了「可再生大文件成片即删」，但从未自动化，
> 用户只能整目录手删，顺带把审计记录一起删掉。本节即那条登记的落地。

### Stray directory gate（项目旁的野目录是 BLOCKER）

预检 `check_video_environment.ps1` 会检查项目根的**上一级目录**是否只含项目本身。
发现任何别的目录即报 `[BLOCKER] stray dirs beside project`，**退出码 2，停止开工**。

成因几乎总是路径乱码：`.ps1` 存成 UTF-8 无 BOM -> PowerShell 5.1 按 ANSI 读源码 ->
中文项目路径读成 GBK 乱码 -> 整棵输出树被建到 `C:\Project\<乱码名>\` 下。

处置：确认无用后 `& 'C:\Project\永劫无间\scripts\sanitize_stray_dirs.ps1' -Remove`
（默认 dry-run，加 `-Remove` 才真删）。**删目录属破坏性动作，必须由人确认。**

> 这条曾是 WARN，被反复忽略，乱码目录持续复发（2026-09-30 升级为 BLOCKER）。
### Final wrap（成片后收尾）

保留冻结包 + 证据包：`deliverables\<源文件名> cujian.mp4`（一份，干净画面，禁烧录禁内嵌字幕流）、冻结三件套 vF（含无版本号复制若存在）、冻结版外挂字幕 SRT + stats（住 `captions\` 异目录）、转写源四件、冻结版预览一版 + decode log、全部 `selfaudit/accept/reverify/workflow_notes/dispatch_ledger/cleanup_log`、探测 + 场景 + 音频活动、联系表、`cache\*.py`。删除其余非冻结预览/字幕/时间线、散帧与稀疏图、`audio_16k.wav`（可再生，用户明确要留 stems 除外并注明）、过程审计中间件与渲染中间件。`deliverables\` 成片后只留成片一份，预览不住 `deliverables\`；旧 delivery 文件要么删除要么在 cleanup_log 注明去向，终版统一对账。不出任何烧录版；字幕只以外挂 SRT 交付。

### cleanup_log（无 log 的删除视为违规）

每次删除落盘 `reports\cleanup_log_vN.md`：触发点（vN+1 冻结后途中清理 / 成片后收尾圈一）、冻结版 vF、拟删清单 + 删前 dir 体积 + 合计、保留确认（冻结三件套/字幕/预览/审计清单路径）、吸收确认（被删结论已记入 selfaudit/workflow_notes 的章节）、执行人/时间、删后验证（dir 体积 + 冻结版 validate 仍 pass + 冻结预览仍可解码）。收尾时末尾追加成片对账：成片绝对路径（任务 `deliverables\` 与外部路径各一行）、是否从原始素材重新渲染、分辨率/帧率/编码器/实际码率、体积、外挂 SRT 路径、原始素材未动声明。删除五步法：先列体积再动手；只删本任务目录内派生文件，绝不碰源片、`.video-tools\`、其他任务目录、`123\workflow_upgrade\`；双条件确认（生命周期标可删 + 结论已被冻结版吸收）；删后验证；途中清理建议先经回收站或保留 7 天再彻底清空。

## Quality gates before delivery

### Source and timeline

- source files remain unchanged;
- every selected shot has valid source timecodes;
- no shot cuts away before the combat outcome unless the style explicitly requests a cliffhanger;
- no subtitle stream or burned pixels inside any preview or master; subtitles ship as external SRT only;
- source and program timelines agree after remapping.
- deleted-interval audit disposes every audio-active interval ≥20s that falls outside episodes (835 v11: 204.5–234s/29.5s had to be frame-verified as looting/decrypt, not an outpost fight).
- `validate_combat_timeline.py` only passes when `deleted_intervals` (or `gaps`) with start/end is embedded in the timeline JSON itself; a standalone audit file in reports/ does NOT satisfy the gate (835 v11: gate stayed red through v2–v10 until intervals were embedded, then overall True).
- any episode boundary change must update the adjacent `deleted_intervals` in the same edit and re-run the seamless-coverage check (835 v13: 001 head 260→261 left a 1s seam 260–261 until the 0–260 deletion was extended).

### Audio

- no A/V drift;
- no clipping or long silent gaps introduced by the edit;
- BGM does not mask important game or voice cues;
- impact SFX are aligned to the intended event frame;
- final loudness and true peak are recorded.
- preview segments may be reused across iterations only when the episode interval is unchanged AND ffprobe confirms the segment duration matches (835 v11: v4_seg1 re-rendered for 256→260 while v3_seg2–5 reused after 59/65/155/143/148 probe match).

### Picture and effects

- no black frames, frozen frames, unintended duplicate frames, or broken alpha plates;
- slow motion and speed ramps preserve the decisive action;
- flashes and shakes do not hide the parry/kill itself;
- text is readable at the target resolution and stays inside safe margins;
- the final encoder, frame rate, resolution, and bitrate follow the source and delivery profile.

### Output

- preview is decoded from start to finish;
- final master is decoded and probed;
- file size is reasonable for the selected VBR target;
- exact absolute paths are reported;
- original media is explicitly reported as preserved.

### Freeze gate 2.0（e5升级，来源 `123\workflow_upgrade\e5_freeze_gate.md`，判定细则见 `roughcut-launch.md §3.7`）

- 冻结定义五门AND：`冻结 vN ≡ G1 ∧ G2 ∧ G3 ∧ G4 ∧ G5`（G1数字验收四角全过 / G2全片密集扫零新增 / G3尾部逐段三信号确认 / G4预览对抗审零低级错误 / G5问题清单清零），任一FAIL即 `NOT_FROZEN` 推下一版。
- 每版一张门禁检查表 `reports/freeze_gate_<序号>_vN.md`（模板见e5设计稿§2）；每格须带文件绝对路径 + 关键数字，否则该门按FAIL计。
- 零新增连续两版（`streak ≥ 2`）才送用户审片；`streak = 1` 判 `FROZEN（候选）` 须再跑一版完整复核；用户报障回来后 `streak` 清零重计。旧预览作废、版本号、分段复用规则仍按本文件生命周期与 `roughcut-launch.md §3.4` 执行。FROZEN 全局唯一（g升级）：须引用全岛 PARTIAL seq + 双证据号且 base_ver 一致；FROZEN 计数 >1 即锁账停渲染，回单写者按 seq 重放定唯一胜者。

### 4K master volume and naming rules（835 用户规则沉淀）

- 成片体积必须明显小于源素材：源才两三个 GB 的节选成片，绝不允许导成七八个 GB。默认沿用已验证的 4K60 受控 VBR（H.264 NVENC、目标约 18 Mbps、峰值约 28 Mbps、AAC 48 kHz），569 秒节目约 1.3 GB；禁止默认 150 Mbps CBR。
- 成片文件名 = 源文件名（不含扩展名）+ ` cujian.mp4`，其余不动。如 `835永劫无间 2026-07-02 22-50-51.mp4` → `835永劫无间 2026-07-02 22-50-51 cujian.mp4`。

### 粗剪成片字幕规则（全外挂，禁烧录禁内嵌，2026-09-11）

- 粗剪成片（`complete_combat_roughcut` 模式输出的 ` cujian.mp4`）一律干净画面：不烧录、不内嵌任何字幕流，只保留画面与原声音轨。字幕以外挂 SRT 形式单独交付（冻结版 `captions\<序号>-review-vN.srt`），播放器按需挂载。不出任何烧录版，不存在 ` burn` 后缀分支。
- 依据：`complete-combat-roughcut.md` 第7条硬性规则（粗剪审片版默认不加 BGM、对话字幕和装饰特效）同样适用于粗剪成片；成片只是把冻结时间线按源分辨率重建，不改变“干净可再用”的性质。用户本次已明确：所有视频不内嵌字幕，所有字幕全外挂，预览与成片一视同仁。

## Feedback loop

Save user feedback as structured notes, for example:

```json
{
  "time": "00:00:08.400",
  "kind": "pacing",
  "request": "振刀前多保留一点进入交战的过程",
  "scope": "style_profile.high_energy",
  "status": "accepted"
}
```

Update a versioned style snapshot only after the feedback is confirmed by a finished preview. Keep exceptional one-off edits local to the task.

### 复验按「我要达成什么」验收，不按「秒点变了没有」（864 重剪轮）

**「改动没达成它声明的效果」本身就是缺陷**，而且它专挑边界后移类改动下手——
因为那类改动**确实删掉了 N 秒，看起来生效了**，实际只是把问题推到后面几秒。

864 实测：v2 把某段片头从源 879.0 后移到 881.0，改动理由写的是「面板已关、横幅已散」。
两路独立验收各自发现**货郎采购会话根本没结束**——884.0「购买成功」横幅回归、面板重新全开、886.0 仍未关。
881.0 只是把它往后挪了 2 秒，**没有删掉**。真正终点是源 **887.5**。

**三条验收纪律**：

1. **写改动理由时要说清「我要达成什么」**，复验时按那个**目标**验收，不是按「秒点变了没有」验收。
   864 的复验任务书写的是「核 881.0 面板已关、横幅已散」，复验员严格执行了——
   但真正该问的是「**成片里还有没有交易画面**」。**问题在问题定义，不在执行。**
2. **观感类改动一律问「成片里还剩这个问题吗」**，不问「边界动了吗」。
3. **一路问到「同类内容彻底不再出现」为止。** 边界后移类改动最容易"看起来生效"。

> 与「数值锁死复核」配套：只改 JSON 散文层（`boundary_reason`/`notes`/`evidence`）后，
> 必须重算切口并与已渲染 `program_map` **逐字段比对**，确认零差异才敢断言「无需重渲」。
> 现行「任一边界改动即重渲」是粗口径，缺这条散文层旁路会让人凭感觉宣称免渲。