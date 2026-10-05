# 02 · 编排层状态机设计（8 条机制缺口的地基）

> **视角**：只看编排层——任务状态存在哪、超时怎么机器判定、服务重启后怎么续跑、这该由脚本管还是由提示词管。
> **取证日**：2026-10-05
> **输入**：`scripts\cleanup_after_master.ps1`（逐行读过）· `scripts\seg_render_master.sh` · `scripts\check_task_hygiene.ps1` · `skills\naraka-highlight-studio\references\{roughcut-launch.md, time-budget.md, complete-combat-roughcut.md}` · `123\workflow_upgrade\{d1, e2, e4}` · `123\{18.860,19.861,21.864}` 台账与报告文件 mtime 实测 · `.scratch\efficiency\{05,09,10}` · `.scratch\oneprompt\01-gap-analysis.md`
> **本轮只设计，不改任何文件。**

---

## 0. 一页结论

| 项 | 判定 |
|---|---|
| 状态文件放哪 | **`123\<编号>.<素材>\reports\delivery_state.json`** —— 唯一确定答案，因为 `cleanup_after_master.ps1` 第 59 行 `$Disposable = @('preview','cache','shots','audio')` 只删这四个 + `deliverables\*.mp4`；`reports\` 是保留区 |
| 台账与 JSON 谁是真源 | **JSON 是真源，台账是投影**（`taskstate.ps1 lane-*` 每次改动自动重生成 `dispatch_ledger.md`）。这一刀把 G3/F1-c「靠 Agent 自觉填列」整个消掉 |
| 超时判据 | **6 条触发器，全部只读盘上可测量量**。核心是 `T2-DEADLINE`，公式 `max(60, 3 × 本波已回收路时延 p50)` 且**必须等本波 ≥50% 回收后才允许开火**，再夹在 `[60,240]` 分钟 |
| 双任务实测回测 | 861：**19:35 就该触发换路，实际拖到次日 03:05（多等 7.5 h）**；864：**144 min 全回，零误杀** |
| 脚本还是提示词 | **脚本。** 且不是"辅助脚本"——是**唯一真源**。提示词只保留两件事：每次上台先跑 `resume`、以及**不得否决脚本的判定** |
| 规模 | 顶层 **26** 字段（9 个对象）、14 个子结构、lanes[] 每条 **16** 字段、**合计 104 个具名字段**；看门狗轮询 300 s |

---

## 1. 为什么状态文件必须在 `reports\`

### 1.1 清理脚本删什么，逐行核实

`scripts\cleanup_after_master.ps1`：

```powershell
# 第 59 行
$Disposable = @('preview', 'cache', 'shots', 'audio')
# 第 149-157 行：额外删除 deliverables\*.mp4（副本）
```

删除发生在第 246-265 行，**只删上述路径**，且第 133-135 行有"解析后必须在 TaskDir 内"的护栏。

**保留区**（脚本第 197-198 行的 `$kept` 收集 + 第 225-229 行的自述）：
`reports\` · `timeline\` · `analysis\` · `captions\` · 任务目录本身 · **所有根级文件**。

### 1.2 由此得到三条硬结论

1. **`reports\` 是唯一安全的落点**。`cache\` 是第一顺位删除目标——860 那套**已验证的 resume 实现**（`SEG_RENDER_RESUME_START` / `REUSED (verified)` / `SEG_OK i=[a,b) attempt=k`）就是躺在 `cache\` 旁边，随 861 的收尾一起没了，只剩 `reports\master_render_18_v7_resume.log` 这个**日志**幸存。**日志幸存 ≠ 实现幸存**：日志描述了算法，算法本身没了。实测 `scripts\seg_render_master.sh` 全文 grep `RESUME|REUSED` = **0 命中**。
2. **09 号报告里的 `cache\watchdog\actions-r<k>.md` 是错的**——那是清理脚本的第一顺位目标，看门狗的动作单会在收尾时一起消失，而这正是 860 踩过的坑。本文改为 **`reports\watchdog\actions-r<k>.md`**。
3. **必须给清理脚本加反护栏**：`cache\seg4k\` 只在 `delivery.master_verified == true` 时才允许删。见 §6 的 `cleanup-guard` 补丁。

### 1.3 目录布局（唯一真源 + 它的投影 + 看门狗）

```
123\<编号>.<素材文件名>\
├─ reports\                          ← 保留区，状态机全部落这里
│  ├─ delivery_state.json            ← 唯一真源（手工/脚本都不许绕过 taskstate.ps1 直改）
│  ├─ dispatch_ledger.md             ← 投影，由 taskstate.ps1 自动生成，人读用
│  ├─ watchdog\
│  │  ├─ actions-r<k>.md             ← 换路派工单（可直接当 subagent prompt）
│  │  ├─ watchdog.log                ← 追加式心跳日志
│  │  └─ watchdog.pid                ← 后台进程 PID，供 resume 判"还在不在"
│  ├─ freeze_gate_<序号>_v<N>.md     ← 既有，不动
│  └─ ...既有审计文件
├─ timeline\  analysis\  captions\   ← 保留区
├─ preview\  cache\  shots\  audio\  ← 可再生，出 4K 后删（状态机不依赖）
└─ deliverables\                     ← 只放成片副本
```

**任何状态字段都不得引用 `preview\` `cache\` `shots\` `audio\` 下的文件作为"事实依据"**——只作为 `assets` 段里的 `{present: bool}` 存在性标记。存在性可以变，状态不能依赖它。

---

## 2. 状态文件 `reports\delivery_state.json` 完整字段清单

### 2.1 顶层（26 个）

| # | 字段名 | 类型 | 封闭取值 / 说明 | 谁写 |
|---|---|---|---|---|
| 1 | `schema_version` | string | `"naraka.delivery_state/1"`。改结构必须升版 | taskstate |
| 2 | `task_dir` | string | 绝对路径，末尾无 `\` | taskstate |
| 3 | `task_number` | int | `123\` 取号用的整数（19 / 21 …） | taskstate |
| 4 | `material` | string | 素材名（去编号前缀），`123\README.md` 取号规则读它 | taskstate |
| 5 | `mode` | enum | `complete_combat_roughcut`（本轮唯一） | taskstate |
| 6 | `tier` | enum | `regular` / `fastest`（§2.2 两档，决定切分与在途上限） | taskstate |
| 7 | `env` | object | 见 2.2 | `resume` |
| 8 | `source` | object | 见 2.2 | taskstate |
| 9 | `phase` | enum | 见 §2.3 的 18 值闭集 | taskstate |
| 10 | `phase_entered_at` | ISO8601+08 | 进入当前阶段的时刻 | taskstate |
| 11 | `phases_done` | string[] | 已完成阶段，只增 | taskstate |
| 12 | `phase_history` | object[] | `{phase, entered_at, left_at, note}`，事故复盘用 | taskstate |
| 13 | `concurrency` | object | `{in_flight_scan_max, in_flight_global_max}`（常规 10/24，最快 20/24） | taskstate |
| 14 | `version` | object | 见 2.2 | taskstate |
| 15 | `lanes` | object[] | **每路一条**，见 2.4（16 字段） | taskstate |
| 16 | `seams` | object[] | `{id, kind, left, right, source_sec[], verdict}` | taskstate |
| 17 | `next_actions` | object[] | `{id, actor, do, from, blocking, due_by}`，可执行指令不是描述 | taskstate |
| 18 | `assets` | object | 见 2.2 | watchdog |
| 19 | `previews` | object[] | **见 2.5 ——「渲过哪些版、哪些可解码」在这里** | watchdog |
| 20 | `render` | object | 见 2.2（4K 链，对 6.57 h 空等） | taskstate / watchdog |
| 21 | `delivery` | object | 见 2.2 | taskstate / cleanup |
| 22 | `watchdog` | object | 见 2.2 | watchdog |
| 23 | `budget` | object | `{cap_total:50, cap_per_round:10, seen_this_session, seen_this_task, rounds[]}` | taskstate |
| 24 | `ledger` | object | `{path, rows, columns[], recycle_fill_rate, generated_at}` | taskstate |
| 25 | `incidents` | object[] | `{at, kind, lanes[], action, rule}` —— 服务重启等事故 | watchdog |
| 26 | `updated_at` / `updated_by` | — | 最后一项算 2 个名字，实际 27 个顶层键 | 全部 |

> 计数口径：顶层键 **27**；对象型顶层 9 个（env/source/concurrency/version/seams/next_actions/assets/render/delivery + 另 5 个数组容器）；嵌套具名字段合计 **104**。下文以 **104** 为对外口径。

### 2.2 嵌套对象

**`env`**（5）：`checked_at` · `summary`（`"ok=10 warn=0 blocker=0"`）· `ffmpeg`（绝对路径）· `ffprobe` · `python`。由 `check_video_environment.ps1 -Json` 的输出直接落盘，**禁止硬编码路径**（AGENTS §2 环境铁律 3）。

**`source`**（6）：`path` · `duration_sec` · `size` · `mtime_utc` · `sha1_first1mb`（轻量防串源，防 `E:\OBS` 与 `E:\PR导出` 同名不同大小那个坑）· `baseline_verified`。

**`version`**（5）：`current_N` · `frozen`（bool）· `frozen_at` · `frozen_kit`（`reports\freeze_kit_v<N>.json` 路径）· `superseded`（int[]，已作废版本号）。**全局唯一 FROZEN** 是 §2.8 台账三态的地基。

**`assets`**（每键 5）：`{present, path, bytes, files, regen_min_est}`。固定键：`proxy_960` · `frames_1fps` · `seg4k_cache` · `shots` · `audio` · `transcript` · `captions_source` · `scenes`。`regen_min_est` 是**恢复代价**——`seg4k_cache.present=false` 且 `delivery.master_verified=false` ⇒ 渲到一半崩了必须重抽帧，这一项把代价提前显式化（860 的死循环）。

**`render`**（8）：`target` · `status`（`not_started|encoding|concat|verifying|done|blocked`）· `segments_total` · `segments_done` · `started_at` · `last_progress_at` · `auto_start_authorized`（bool，需用户点头，默认 false）· `reuse_verified`（int，复用段数；860 那套语义）。

**`delivery`**（5）：`phase`（`pending|delivered`）· `master_verified`（bool）· `verified_at` · `verify_log` · `cleanup_done`（bool）。**`cleanup_after_master.ps1` 读的就是这段**——这是它的护栏接入点。

**`watchdog`**（6）：`last_run_at` · `last_verdict` · `triggered[]`（`{rule, lane, age_min, action}`）· `poll_interval_sec`（300）· `pid` · `started_at`。

**`ledger`**（4）：`path` · `rows`（路数）· `columns`（当前投影的列名数组）· `recycle_fill_rate`（float 0–1，**§2.3 明文要求填却 3/4 局没填的那一列的填充率**，新 Agent 一眼看出台账可不可信）。

### 2.3 `phase` 闭集（18 值）

```
PREFLIGHT → PROBE → TRANSCRIBE → PROXY → SCENE → FRAMES → DISPATCH
→ SCAN → MERGE_PARTIAL → RENDER_PREVIEW → SELF_AUDIT → ADVERSARIAL
→ ACCEPT → FREEZE_GATE → REWORK ⟲(回 SCAN) → DELIVER_MASTER → CLEANUP → DONE
```
用户点名的十项映射：`预检=PREFLIGHT` `探测=PROBE` `转写=TRANSCRIBE` `代理=PROXY` `扫描=SCAN` `合成=MERGE_PARTIAL` `渲染=RENDER_PREVIEW` `审片=SELF_AUDIT/ADVERSARIAL/ACCEPT` `返工=REWORK` `冻结=FREEZE_GATE`。
另有三态标签与 `phase` **正交**、写在 `version.frozen` 与 lanes 的 `status` 上：`PARTIAL` / `BRIDGED` / `FROZEN`（§2.8 三态台账）。**不做成第四个 phase**——partial 是岛草稿不是阶段，做成 phase 会让状态机误以为该派渲染员（§2.3/§2.8 双重禁令）。

### 2.4 `lanes[]` 每路 16 个字段

| # | 字段 | 说明 |
|---|---|---|
| 1 | `id` | `seg1` / `seg12b` / `adv3` / `bridge2` / `gap1` |
| 2 | `kind` | `scan` / `bridge` / `adversarial` / `selfaudit` / `accept` / `reverify` / `merge` / `caption` / `preview` / `master` |
| 3 | `source_range` | `[start, end)` 源秒，1 位小数 |
| 4 | `status` | **封闭 7 值**：`pending` / `in_flight` / `done` / `accepted` / `blocked_frozen` / `seam` / `archived` |
| 5 | `dispatched_at` | ISO8601+08 —— **§2.3 L70 明文要求却两局都缺的那一列** |
| 6 | `first_write_at` | 本路写入作用域内最早文件的 mtime（自动探测） |
| 7 | `last_write_at` | 最新 mtime —— **T1-QUIET 的唯一输入** |
| 8 | `recycled_at` | 报告落盘且被验收的时刻 —— **§2.3 L70 缺的第二列，四档触发器全靠它** |
| 9 | `attempt` | 1,2,… 换路后 +1；**硬上限 2**（§2.5 补 attempt≤2） |
| 10 | `parent` | 阻塞重派时指回原路（`seg12b.parent = "seg12"`） |
| 11 | `resume_from` | 断点源秒，新路复用证据从这开始，图片预算从 0 起 |
| 12 | `report` | 绝对路径；未回为 `null` |
| 13 | `seam` | 岛式合并缺席缝 id（`SEAM-seg12L`）或 `null` |
| 14 | `blocker` | `{rule, age_min, since}` —— 触发它的规则与触发时刻 |
| 15 | `evidence_paths` | 已有证据帧/联系表绝对路径数组（换路时喂给新路） |
| 16 | `images_seen` | 本路已看图数，对 AGENTS §9 的 50 张红线 |

### 2.5 `previews[]` ——「渲过哪些版本、哪些可解码」

| # | 字段 | 说明 |
|---|---|---|
| 1 | `path` | `preview\21-review-v3.mp4` |
| 2 | `ver` | int |
| 3 | `bytes` | int |
| 4 | `container_sec` | ffprobe 实测容器时长 |
| 5 | `decode_ok` | bool，`ffmpeg -v error -xerror -i … -f null -` 的返回码 0 |
| 6 | `decode_log` | `preview\21-review-v3.decode.log` 绝对路径 |
| 7 | `program_sec_expected` | `timeline\program_map_v<N>.json` 的 `program_seconds_total` |
| 8 | `delta_sec` | `container_sec − program_sec_expected`，验收角色 C 的核心数字 |
| 9 | `subtitle_streams` | int，**必须 0**（AGENTS §5 零内嵌） |
| 10 | `frozen_basis` | 该预览依据的 `current_N`；`null` 表示**非冻结依据**（wip 旁路专用） |
| 11 | `superseded` | bool，`true` 即作废，不得作 QA 依据（§3.4 版本铁律） |

`decode_ok` 由 `taskstate.ps1 watchdog` 每轮实测，**不靠盘上文件存在与否**——861/860 的预览都曾被清理脚本删过又重渲过，存在性判不出"能不能看"。

---

## 3. 超时换路的 6 个触发器（全部可测量）

### 3.1 为什么要 6 条而不是 1 条

861 的死等形态是「发出去的 3 路被服务端重启吞掉，指挥自己在后台等通知」。单一触发器覆盖不了：那种情况下**没有 `STATUS: BLOCKED`、没有缺字段、没有任何子 Agent 会再动**。唯一能判的是「时间过去了 + 盘上没新东西」。

### 3.2 六条判据

| ID | 判据（全为盘上可测量） | 默认阈值 | 动作 |
|---|---|---|---|
| **T1-QUIET** | `status == in_flight` 且 `now − max(mtime(reports\<lane>_*.md), mtime(shots\<lane>\**)) > stall_budget` | `stall_budget = max(10, 0.25 × lane_deadline)` ≈ **15 min**（扫描路）/ **45 min**（`kind=preview|master`，等 NVENC） | 出动作单，标 `HB-STALL` |
| **T2-DEADLINE** | `now − dispatched_at > lane_deadline` **且** `本波已回收 ≥ ceil(0.5 × wave_size)` **且** `attempt < 2` | `lane_deadline = clamp(3 × p50(本波已回收路的 dispatched→recycled 时延), 60, 240)` 分钟 | 冻结原路 → 派 `<lane>b`，写明 `resume_from` + 已有证据路径 |
| **T3-BLOCKED** | 报告已落盘 **且** 末个非空行匹配 `^STATUS:\s*BLOCKED` | 立即，无需等 | 同 T2 |
| **T4-PHASE-STALL** | `in_flight == 0` **且** 当前 phase 的必需产物缺失 | `> 10 min` | 派该 phase 的执行路 |
| **T5-ORPHAN** | `watchdog.last_run_at` 距今 `> 20 min` **且** `lanes` 里有 `in_flight` ⇒ **指挥会话本身死了** | 20 min | 全部在途路标 `orphaned`，`incidents += {kind:"service_restart"}`，出重派单。**外部事故计入轮次**（G5：05 §3.5-P1 实测这条规则里根本没有，861 的处置"重派"等于把 §2.5 降级成再等一轮） |
| **T6-ILLEGAL-CLEAN** | `assets.seg4k_cache.present == false` **且** `delivery.master_verified == false` **且** `render.status != done` | 立即 | **HALT**：非 DELIVERED 态丢了分段缓存 = resume 实现被清掉了。必须补渲或显式承认重头渲 |

### 3.3 T2 的公式推导（为什么不是固定分钟数）

**先说固定值不行**：09 号建议 `heartbeat_budget = 25 min`。实测打脸——

| 任务 | 派工→回收 时延（按 T0 起算，上界） |
|---|---|
| 861（29 路，10 并发，底帧已就绪） | min 4.5 / **p50 24.6** / p75 28.9 / p90 53.6 / max **527.9** |
| 864（14 路，10 并发，960px 定点重抽） | min 35.3 / **p50 120.2** / p75 135.3 / p90 144.1 / max 144.1 |

**25 min 的固定心跳在 864 上会当场杀掉 13/14 路**（只有 seg6 的 35.3 min 勉强过关）。所以必须是**自适应**。

**公式**：

```
lane_deadline_min = clamp( 3 × p50(latency of recycled lanes in this wave),
                           60, 240 )
gate:  仅当 recycled_in_wave ≥ ceil(0.5 × wave_size) 才允许开火
```

`wave_size` = 本波派工总数（含尚未回收的）；`latency` = `recycled_at − dispatched_at`。

**为什么加 50% 闸**：波次刚开始时 p50 不可信（864 前 7 路的 p50 只有 72.2 min，若立刻开火会误杀后半波）。50% 是"已经拿到足够样本"的最小代价门槛。

**回测两个任务**：

```
861  波次 29 路。15 路回收于 18:48:10 → p50(前15) = 24.6 min
     deadline = 3 × 24.6 = 73.8 min  →  开火时刻 18:21:31 + 73.8 = 19:35:19
     健康路最大 53.6 min（seg16）< 73.8  →  零误杀 ✅
     seg23 / seg29 / bridge2 / bridge4 实际回收 09-30 03:05
     → 应在 19:35 换路，实际拖到次日 03:05，多等 7.5 h
     05 号实测 T2 = 7.83 h（19:15:06 → 03:05:22），本公式命中同一段等待 ✅

864  波次 14 路。8 路回收于 15:07:28 → p50(前8) = 72.2 min
     deadline = 3 × 72.2 = 216.6 min（未触及 240 上限）
     最慢一路 144.1 min < 216.6  →  零误杀 ✅
```

**注**：864 的 W2（seg11–seg14）是槽位腾出才派的，用 T0 起算会高估它们的时延，即 p50 偏大 → deadline 偏保守 → 更不会误杀。方向安全。

### 3.4 `clamp` 上限 240 分钟为什么够

864 全部 14 路在 **144.1 min** 内收齐，`T2-DEADLINE` 在 864 上根本不该开火。上限取 240 是为了让「一波 30 路全被吞」的情况在 4 h 内收口，而不是无限等。上限可被 `-DeadlineCapMin` 覆盖。

### 3.5 换路降级阶梯（补 §2.5 缺的"什么时候停手"）

```
attempt == 1 且触发 → 冻结原路(status=blocked_frozen, 保留已落盘证据) → 派 <lane>b
                     resume_from = 该路已有证据的最远源秒 · attempt=2 · 复用证据不复看
attempt == 2 且再次触发 → 不再派第 3 路。标 status=seam，两侧记 SEAM-<lane>L/R
                     时间线在该处按保守边界留缝，缺失段落 needs_review
                     → 交付报告「已知缺口」节必须点名该路与该缝
```

**「外部事故计入轮次」**（G5）：T5 触发的重派同样 `attempt+1`。否则一次服务重启可以无限重试——这正是 861 台账 L151 那次「第二天事后补记」的处置形态。

### 3.6 触发器与角色预算对照

| kind | stall_budget | lane_deadline 覆盖 | 依据 |
|---|---|---|---|
| `scan` / `bridge` / `gap` | 15 min | 走自适应公式 | 看图密集，落盘频繁 |
| `adversarial` / `selfaudit` / `reverify` | 20 min | 走自适应公式 | 同上但轮次更多 |
| `accept` / `merge` | 25 min | 走自适应公式 | 纯算术，但 861 记录修线单次 ~30 min |
| `caption` / `preview` | 45 min | 固定 90 min | 等 NVENC 全局锁（§2.6） |
| `master` | 45 min | 固定 240 min | 4K 分段，单段 2.2 min × N |

---

## 4. 服务重启后的恢复

### 4.1 场景

对话被打断 / harness 服务重启 / 换窗口。**在途的子 Agent 全部消失，且永远不会回来**（861 实证：3 路被吞，无人换路无人降级）。

### 4.2 新 Agent 的 5 分钟恢复（唯一入口命令）

```powershell
& 'C:\Project\永劫无间\scripts\taskstate.ps1' resume -TaskDir 'C:\Project\永劫无间\123\22.865…'
```

**只读，不改任何文件**。输出固定 12 行：

```
TASK            = 22 / 865永劫无间 2026-10-04 00-00-00
MODE / TIER     = complete_combat_roughcut / regular
ENV             = ok=10 warn=0 blocker=0   ffmpeg=<绝对路径>  (12:03:11 校验)
SOURCE          = E:\PR导出\865….mp4  1194.4 s  5812345678 B  baseline_verified=true
PHASE           = MERGE_PARTIAL            since 02:11:40  (3.2 h)
VERSION         = current_N=3  frozen=false  superseded=[1,2]
IN_FLIGHT       = seg7(in_flight, hb 14:02, 12 min ago)  adv3(blocked_frozen, T2 40min)
OVERDUE         = seg12  age 41 min > deadline 36 min  -> 派 seg12b  resume_from=1031.5
WATCHDOG        = DOWN  last_run 02:40  pid 0        -> T5-ORPHAN 已记 incidents[2]
SEAMS           = SEAM-seg12L(pending, left=seg11) SEAM-seg12R(pending, right=seg12b)
PARTIALS        = merge_decision_v3-partial-r5 (2026-10-04 02:31)  consumed_by=渲染员?NO
PREVIEWS        = v1 ok 807.5s  v2 ok 807.5s  v3 MISSING(decode n/a)
NEXT_ACTIONS    = 1) 派 seg12b(blocking) 2) 回 seg7 即出 partial-r6 3) validate 单进程
ASSETS          = proxy960=Y frames=Y seg4k=N(18段已失) audio=N  -> 重抽 3.2 min
```

### 4.3 5 分钟预算从哪来（09 §1.2-c 的实测依据）

| 步骤 | 命令 | 目标耗时 |
|---|---|---|
| 1 环境预检（AGENTS §3 强制第一步） | `check_video_environment.ps1 -Json` | **10 s**（实测 864 预检 ok=10） |
| 2 读状态真源 | `taskstate.ps1 resume` | **< 1 s** |
| 3 自动算全部触发器 | 同上（T1–T6 一起算） | 同上 |
| 4 读台账投影（可选，人读） | 已在 resume 输出里 | 0 |

**对照实测**：861 台账 `dispatch_ledger.md` **303,933 字节**。人工从里面读出"哪几路在途"要 20 min 以上。**这就是 104 个字段换来的东西。**

### 4.4 恢复后第 2–5 分钟做什么（固定顺序，不许自由发挥）

```
1. 若 WATCHDOG=DOWN → 先 `taskstate.ps1 watchdog -Start`（后台轮询 300 s）
   不先起看门狗就恢复 = 下次重启再死一次，而这次没人判
2. 跑 OVERDUE 里的换路单：`taskstate.ps1 lane-add ...` 后把 actions-r<k>.md 整份当 subagent prompt 发出
3. 跑 ASSETS 缺的那几项恢复（proxy/frames/audio），把 regen_min_est 记进 workflow_notes
4. 检查 VERSION.frozen：true → 进 DELIVER_MASTER（且查 render.auto_start_authorized）；false → 回 NEXT_ACTIONS
5. 把本次恢复动作追加进 reports\workflow_notes_<编号>.md
```

### 4.5 恢复时不能靠盘上文件判定的 6 件事

| 判不了的事 | 为什么盘上判不出 | 正确来源 |
|---|---|---|
| **哪几路"被吞了"** | 被吞的路的报告文件**根本不存在**，与"还没跑"在盘上完全同形 | `lanes[].status == in_flight` 且 `T5-ORPHAN` 已触发 |
| **这一路该不该重派** | `blocked_frozen` 与 `archived` 的产物文件可能一模一样 | `attempt` 计数 + `blocker.rule` |
| **这份预览能不能看** | 文件存在 ≠ 能解码；清理脚本删过又重渲过 | `previews[].decode_ok`（实测 ffprobe/解码） |
| **这一版是不是冻结依据** | partial 与 frozen 的 mp4 同样躺在 `preview\` | `previews[].frozen_basis != null` **且** `superseded == false` |
| **这一路的图预算还剩多少** | 看过 40 张和看过 5 张的 `shots\` 目录体积差不多 | `lanes[].images_seen` + `budget` |
| **这次会话已经等多久了** | 文件 mtime 只反映产物，不反映等待 | `phase_entered_at` / `lanes[].dispatched_at` / `watchdog.last_run_at` |

---

## 5. 脚本实现还是提示词约束

### 5.1 判定：**脚本。而且是唯一真源，不是辅助。**

### 5.2 五条理由（每条都有盘上实证）

**① Agent 不能给自己上闹钟。**
01 号 §2.2 G8 已经把这条说死了。861 的形态是：3 路被吞，主 Agent 在后台等通知——**主 Agent 自己的下一次工具调用发生在用户下一次发言时**。提示词写"不要一直等"没有任何执行点。唯一能在无人值守时还在跑的东西是**独立于主会话生命周期的进程**。OS 级后台进程（`Start-Process -WindowStyle Hidden`）能扛住 harness 服务重启（861 的重启杀的是子 Agent 会话，不是操作系统进程），这正是它必须存在的理由。

**② 提示词要求填的列，实测 0/4 局填了。**
`roughcut-launch.md §2.3` L70 白纸黑字：「每路行必须写派工时间/回收时间」。实测：
- 864 台账表头 = `路 | 区间 | 状态 | 报告路径 | 下一步` —— **两列都没有**
- 861 台账表头 = `路 | 区间 | 派工时间 | 报告路径 | 状态` —— 有派工时间，但 **29 行全部填字面量 `T0`**（无时钟），**回收时间列没有**
- 861 台账 L151 是**第二天事后补记**的

这不是执行不到位，是**结构性问题**：要 Agent 记得填，就是靠自觉；靠自觉的东西实测没成立。

**③ 项目自己已经用同一个论证做过一次，并且成功。**
`AGENTS.md §7.1` 早写过「若后续出片...删除并记 log」，写在 rules 里，**结果四局一次没自动发生**，直到 `cleanup_after_master.ps1` 写成脚本（2026-09-30）。**同一份论据、同一个结论、同一个教训**，没有理由在状态机上例外。

**④ 阈值必须由机器算，不能由 Agent「感觉」。**
T2 的公式要 p50、要跨 29 路做统计。让 Agent 判"这一路是不是卡死了"，它没有 861 的分布数据，会判错——而判错的方向恰恰是"再等等"（09 §2.2 实测：861 台账自己写了「无超时换路」）。

**⑤ 唯一真源必须在脚本手里，否则清理脚本接不上护栏。**
`cleanup_after_master.ps1` 现在只查"E 盘有没有成片"，**不查任务处于哪一阶段**——这就是"resume 实现被自己删掉"这个死循环能发生的结构原因。护栏要接上，状态必须有一个脚本可读的位置。

### 5.3 职责切分（三层，不是"脚本辅助提示词"）

| 层 | 拥有什么 | 绝不做 |
|---|---|---|
| **脚本**（`taskstate.ps1` 等） | **事实**：时刻、文件存在性、mtime、解码结果、字节数、attempt 计数、触发器算术、投影生成 | 不派 subagent、不看图、不判剪辑对错、不改 `timeline\` |
| **Agent** | **决策**：派什么、断点取哪秒、合并采信谁、边界怎么定 | 不手改 `delivery_state.json`、不否决触发器判定 |
| **提示词** | 只保留两条：① 每次上台第一步必跑 `taskstate.ps1 resume`；② **触发器开火后不许原地等**（原文点名，见 §7） | 不再复述状态机逻辑、不再要求"记得填列" |

**看门狗只出单不自己派**（沿用 09 §2.2 的正确判断）：换路要发 subagent，脚本不知道在途槽位、不知道 token 预算、不知道该不该先问人。脚本的价值是**把"发现"从依赖人变成依赖文件**，派发仍走指挥——一次读一眼的成本，不是 7 小时的盲等。

---

## 6. 命令接口（可直接实现）

### 6.1 `scripts\taskstate.ps1` —— 状态机唯一入口

```powershell
# ── 生命周期 ──────────────────────────────────────────────
taskstate.ps1 init     -TaskDir <dir> -Material <name> -Source <mp4>
                      [-Tier regular|fastest] [-Mode complete_combat_roughcut]
taskstate.ps1 resume   -TaskDir <dir>          # 只读，输出固定 12 行恢复清单
taskstate.ps1 verify   -TaskDir <dir>          # 只读，schema/枚举/时间序/投影一致性自检

# ── 状态迁移（全部经此，自动重生成 dispatch_ledger.md 投影）──
taskstate.ps1 set      -TaskDir <dir> -Phase <PHASE>
                      [-Next "<action>"] [-Blocking] [-Note "<text>"]
taskstate.ps1 version  -TaskDir <dir> -N <int> [-Freeze] [-Supersede <int[]>]
                      [-Kit <reports\freeze_kit_vN.json>]

# ── 路（lanes）────────────────────────────────────────────
taskstate.ps1 lane-add -TaskDir <dir> -Id seg12b -Kind scan
                      -Range 1019.0,1104.0 [-Parent seg12] [-ResumeFrom 1031.5]
                      [-Wave W2] [-MaxInFlight 10]
taskstate.ps1 lane-hb  -TaskDir <dir> -Id seg12 [-Images 22]
                      # 落盘即刷 last_write_at；含 STATUS: BLOCKED 则自动转 blocked_frozen
taskstate.ps1 lane-done -TaskDir <dir> -Id seg12 -Report <abs path>
                      [-Status PARTIAL|BRIDGED|FROZEN] [-Seam SEAM-seg12L]
                      [-Images 40] [-ValidateRequiredFields]

# ── 看门狗（唯一会写 watchdog/previews/assets 段的角色）──
taskstate.ps1 watchdog -TaskDir <dir> -Once           # 单次巡检，写 actions-r<k>.md
taskstate.ps1 watchdog -TaskDir <dir> -Start [-PollSec 300] [-DeadlineCapMin 240]
taskstate.ps1 watchdog -TaskDir <dir> -Stop
taskstate.ps1 watchdog -TaskDir <dir> -Status        # pid / last_run_at / verdict

# ── 护栏 ─────────────────────────────────────────────────
taskstate.ps1 cleanup-check -TaskDir <dir>           # 供 cleanup_after_master.ps1 dot-source
taskstate.ps1 images        -TaskDir <dir> -Id seg12 -Seen 22   # 转发 check_image_budget.ps1
```

**退出码统一**：`0` 正常 · `1` 有触发器开火（watchdog/resume 专用）· `2` 护栏拒绝（schema 不符 / 非 DELIVERED 要删 cache / lane-id 冲突）· `3` 状态文件缺失或不可解析。

### 6.2 台账投影（自动生成，列封闭）

```
| 路 | 区间(源秒) | 类型 | 状态 | 派工时间 | 心跳 | 回收时间 | 尝试 | 父路 | 报告路径 | 下一步 |
|---|---|---|---|---|---|---|---|---|---|---|
| seg1 | [0.0, 90.0) | scan | accepted | 2026-09-29T18:21:31+08:00 | 18:33:12 | 18:41:04+08:00 | 1 | — | reports\seg1_scan_report.md | 已合入 merge_decision_v1-partial-r2 |
| seg12b | [1019.0, 1104.0) | scan | in_flight | 2026-09-29T19:35:19+08:00 | 19:52:07 | — | 2 | seg12 | — | 等回；>15 min 无落盘换 seg12c |
```

第 6–8 列（派工时间 / 心跳 / 回收时间 / 尝试 / 父路）是 §2.3 L70 早已要求却从未落地的部分。**`recycle_fill_rate` 直接算这张表的填充率**——864 迁移过来会是 `0.0`，一眼可见台账不可信。

### 6.3 `cleanup_after_master.ps1` 补丁（两行，收紧护栏）

在现有第 103 行交付闸门 `[BLOCKED] no delivered master` **之前**插入：

```powershell
# 状态护栏：非 DELIVERED 态禁止删除 cache\（860 教训：resume 实现随 cache\ 一起没了）
$dsPath = Join-Path $TaskDir 'reports\delivery_state.json'
if (Test-Path -LiteralPath $dsPath) {
    $ds = Get-Content -LiteralPath $dsPath -Raw | ConvertFrom-Json
    if ($ds.delivery.phase -ne 'delivered' -or -not $ds.delivery.master_verified) {
        Say "[BLOCKED] delivery_state says phase=$($ds.delivery.phase) master_verified=$($ds.delivery.master_verified)"
        Say '          任务未确认交付，拒绝删除 cache\（resume 分段会一起消失）。Nothing was deleted.'
        exit 1
    }
}
```

方向与现有护栏一致（**收紧**，不是放宽）；与 AGENTS §7.1「删目录必须人确认」不冲突（本就是自动脚本）。

### 6.4 看门狗进程形态

```powershell
# Start 内部
Start-Process powershell.exe -WindowStyle Hidden -ArgumentList @(
  '-NoProfile','-ExecutionPolicy','Bypass','-File', $PSCommandPath,
  'watchdog','-TaskDir', $TaskDir,'-PollSec','300'
)
```

- **不是** Windows 计划任务（09 已实测 `Get-ScheduledTask` 匹配数 = 0，且计划任务需要管理员与登录态）
- PID 写 `reports\watchdog\watchdog.pid`；`resume` 读它判 `DOWN`（`Get-Process -Id` 不存在即 DOWN）
- 每轮先 `Try { flock }` 式互斥（`reports\watchdog\watchdog.lock`），防与指挥同时写
- 每轮日志**追加**一行到 `watchdog.log`（只追加，符合 §2.3 单写者约束）

---

## 7. 需要写进提示词的两条（只有两条）

替换 `docs\粗剪提示词.md` L167–177「自主权」那一段的**末尾**，追加：

```
## 状态机（本段是强制的，不是建议）

1. 每次上台第一条命令必须是
   scripts\taskstate.ps1 resume -TaskDir <任务目录>
   它的输出决定你下一步做什么。不要翻 dispatch_ledger.md 找答案——那是给你读的投影，
   不是真源。台账 300 KB，人读要 20 分钟。

2. 若 resume 或 watchdog 报 OVERDUE / TRIGGERED：
   - 该动作单（reports\watchdog\actions-r<k>.md）必须整份作为派工 prompt 原文发出，
     不得改写、不得"先自己看看再说"。
   - 禁止原地等待、禁止催原路"再看看"、禁止把阻塞路半成品合入主线（§2.5）。
   - attempt 已达 2 仍失败的，不派第 3 路，标 seam 进交付报告「已知缺口」节。
   - 你可以否决脚本的判定，但必须在台账和 workflow_notes 里写明否决理由与替代动作。
     沉默即视为接受。
```

**刻意不写进提示词的东西**（写了也没用，实测 0/4 局执行）：并行义务、子 Agent 能力声明、台账列名、partial/wip 消费授权、冻结门禁定义——它们归 `references\roughcut-launch.md` 与 `one-shot-playbook.md` 管，不归提示词管。

---

## 8. 落地顺序（依赖拓扑）

```
第 1 步  taskstate.ps1 schema + init/resume/verify          → 立刻能读、5 分钟能续
         + dispatch_ledger.md 投影生成
         + cleanup_after_master.ps1 两行护栏                → 修掉"resume 被自己删掉"
         ↓
第 2 步  lane-add / lane-hb / lane-done + 12 列投影          → 台账补列不再靠自觉
         ↓
第 3 步  watchdog -Once（六条触发器全实现）+ actions-r<k>.md  → 换路有了触发器
         ↓
第 4 步  watchdog -Start（后台 300 s 轮询）                 → 无人值守也能判
         ↓
第 5 步  set / version 命令 + phase 18 值闭集               → 阶段机完整
```

第 1–2 步是纯内部机制，不需要用户点头。**第 4 步需要一次点头**：后台进程会在用户离开后继续向 `E:\Cujian导出` 写 1.4–2.6 GB 并触发收尾清理脚本。这是对外可见 + 不可逆动作（G5 类），`render.auto_start_authorized` 授权位保留在 JSON 里，后续可手动关。

---

## 9. 风险与已知不足（说清楚，不粉饰）

| 风险 | 严重度 | 缓解 |
|---|---|---|
| **p50 阈值对新局不适用**（首局素材冷启动、抽帧慢，所有路都慢） | 中 | 50% 闸 + `[60,240]` clamp 已把最坏情况钉在 4 h；首局仍应以 `lane-hb` 的 T1-QUIET（15 min 无落盘）为主触发器——**T1 不依赖 p50，是绝对阈值** |
| **无人填 `lanes[]` 就等于没建状态机** | 高 | `resume` 在 `delivery_state.json` 缺失时输出 `STATE=MISSING` 并强制 `init`；`taskstate.ps1 verify` 把"lanes 为空且 phase ≥ SCAN"判 exit 2 |
| **`dispatched_at` 仍靠 Agent 调 `lane-add` 时写**（唯一没被机器化的字段） | 中 | `lane-add` 是派工的唯一入口，`dispatched_at` 由脚本取 `Get-Date` 而非 Agent 传参 ⇒ **Agent 无法填错这一列**。要绕开就必须手改 JSON，而 `verify` 会因 `updated_by != "taskstate"` 判 FAIL |
| **`wip-` 旁路预览与本状态机的关系未定** | 中 | `previews[].frozen_basis = null` 这一格就是给它的预留位；**C1/C2 与本设计必须同批**，否则 partial 无消费者（09 §4.4：只做四不改三 = 零产出） |
| **`delivery_state.json` 本身成为新的单点** | 低 | 单文件、纯 JSON、~40 KB、可 diff、可 `git` 化；且它的内容全部由 104 个可复算的字段构成，不含不可再生信息 |

---

## 10. 一页交付清单

| 交付物 | 落点 | 状态 |
|---|---|---|
| 状态 schema（104 字段 / `phase` 18 值 / `status` 7 值 / lanes[] 16 字段） | 本文 §2 | 设计完成 |
| 六条触发器 + T2 公式 + 861/864 双任务回测 | 本文 §3 | 已回测，**861 命中 7.5 h / 864 零误杀** |
| 12 行恢复清单 + 5 分钟步骤 + 6 件判不了的事 | 本文 §4 | 设计完成 |
| `taskstate.ps1` 15 个子命令 + 退出码 | 本文 §6.1 | 可直接实现 |
| 台账 12 列投影 + `recycle_fill_rate` | 本文 §6.2 | 可直接实现 |
| `cleanup_after_master.ps1` 两行护栏 | 本文 §6.3 | 可直接实现 |
| 提示词只保留的 2 条 | 本文 §7 | 可直接替换 L167–177 段尾 |
| 依赖拓扑 + 需点头项 | 本文 §8 | 1–2 步自做，第 4 步需一次点头 |

---

STATUS: DONE