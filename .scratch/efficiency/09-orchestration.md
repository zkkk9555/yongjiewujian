# 09 · 编排层效率改造（Agent 派工结构本身）

> 角度：不是剪法、不是机器活、不是审片设计，是**派工—回收—换路—交付**这条骨架。
> 前 8 号 Agent 已定的账：span 62.52 h 里纯等待 46.5%；861 比 864 慢的 7.11 h 全是干等；
> 岛式合并逃生阀四局零使用；冻结→4K 空等 6.57 h（≥85% 是链路没启动）；
> 台账缺回收时间列；审片越多越差。
> 本文只回答一件事：**下一个任务如何不需要人守着**。

---

## 0. 结论先行：干等的四个根都在编排层，不在执行层

把 46.5% 的等待拆开，每一段都有一个共同结构——**状态只存在于人的脑子里或只存在于一份不可解析的 Markdown 里**：

| 等待类型 | 现在靠什么推进 | 缺什么 | 对应改造 |
|---|---|---|---|
| 861 的 7.11 h（3 路被吞） | 人盯着，看到没回 → 手动重派 | 触发器不可机器判定 + 无换路执行者 | 改造 2 |
| 冻结→4K 的 6.57 h | 人想起来那天顺手开渲 | 无编排钩子、无看门狗、无状态文件（已核实 `Get-ScheduledTask` 匹配数 = 0） | 改造 3 + 2 |
| 服务重启/换对话后恢复 | 人重新翻 40 万字台账 | 台账缺列、缓存被清 | 改造 1 + 3 |
| 861 首版 10.05 h（vs 864 的 2.94 h） | 人决定"要不要先出个粗的" | 逃生阀被规则自己焊死 | 改造 4 + 5 |

**四条全部指向同一件事：把"当前处于哪一阶段、哪几路在途、下一���是什么"从人脑/散文里搬到机器可读的一份文件。** 所以改造 3 是地基，1/2/4/5 都挂在它上面。

---

## 1. 改造一：续跑 —— 5 分钟内回到可用状态

### 1.1 现在中断后会丢什么（逐项实测）

| 信息 | 现在落在哪 | 中断后能否恢复 | 硬伤 |
|---|---|---|---|
| 源探测 / 转写 / 场景 / 密集帧 | `analysis\`、`audio\`、`captions\`、`shots\` | `analysis\` `captions\` 能；**`audio\` `shots\` 出片后被 `cleanup_after_master.ps1` 第 59 行删掉** | 4K 渲到一半崩 → 抽帧要重做 |
| 分段 4K 中间件 + **resume 逻辑** | `cache\seg4k\` + `reports\master_render_18_v7_resume.log` | **日志在 `reports\` 幸存，resume 实现本身随 `cache\` 一起没了** | `scripts\seg_render_master.sh` 当前**无任何 resume 分支**（实测 grep `RESUME\|REUSED` = 0 命中）。860 那套 `SEG_RENDER_RESUME_START` / `REUSED (verified)` 逻辑是任务目录里的一次性脚本，被清理脚本删了，正本从未进 `scripts\` |
| 每路派工/回收时刻 | `reports\dispatch_ledger.md` 表格 | **不能**——864 表头是 `路/区间/状态/报告路径/下一步`，861 表头是 `路/区间/派工时间/报告路径/状态`。**两处都没有回收时间** | 超时换路算不出来（§2.3 明文要求"每路行必须写派工时间与回收时间"，864 未执行） |
| 当前冻结版本号 | 台账正文散文 | 能，但需人读 16 KB～304 KB 才找得到 | 861 台账 303 KB，没有机器入口 |
| 下一该派什么 | 台账"下一步"列 + 人脑 | 半能 | 无全局状态视图 |

### 1.2 落地做法

**(a) 台账补列（封闭词表，照 §2.3 已有约定扩）**

路表列改为：

```
| 路 | 区间(源秒) | 状态 | 派工时间(ISO8601) | 心跳时间 | 回收时间 | 报告路径 | 尝试 | 父路 | 下一步 |
```

- `状态` 封闭词表：`待派 / 在途 / 已回 / 已验收 / 阻塞冻结 / 已归档 / SEAM`
- `回收时间`：机器可算超时与实测速度的唯一依据。**缺它 = §2.5 超时定义不可执行**
- `尝试`：`attempt=1/2/...`，换路后新路继承同一区间但 attempt+1
- `父路`：新路指回原阻塞路，便于择优合入

**(b) resume 实现搬进 `scripts\`，不再放任务目录**

把 860 验证过的 resume 逻辑（`SEG_RENDER_RESUME_START` / 每段 `REUSED (verified)` / `SEG_OK i=[a,b) attempt=k` / 目标文件存在+时长匹配才复用）**上提为 `scripts\seg_render_master.sh` 的常驻分支**，并加一条硬规则：

> `cleanup_after_master.ps1` 删除 `cache\` 之前，必须先证明"本次交付已完成"——判据 = `reports\delivery_state.json` 的 `phase == DELIVERED` 且 `master_verified == true`。**在途/冻结未交付状态下删 `cache\` 直接拒绝执行**（现在只查 E 盘有没有成片，不查任务处于哪一阶段）。

这一条同时修掉"resume 被自己删掉"这个死循环。

**(c) 5 分钟恢复清单（新 Agent 的第一条命令）**

新脚本 `scripts\resume_task.ps1 -TaskDir <dir>`，只读，输出：

```
PHASE            = MERGE_CANDIDATE
FROZEN_VER       = 3
IN_FLIGHT        = seg7(在途,心跳 14:02) seg12(在途,心跳 13:50) adv3(阻塞冻结)
OVERDUE          = seg12 心跳超 40 min -> 触发换路 seg12b, resume_from=1031.5
NEXT_ACTIONS     = 1) 派 seg12b  2) 回 seg7 即出 partial-r5  3) validate 单进程
RESUMABLE_ASSETS = proxy_960.mp4(有) frames(无,已清理,需重抽 3.2 min)
```

**5 分钟预算来自三件事**：状态文件机器可读（不翻散文）+ 台账行可解析（不数人头）+ assets 清单显式列出在/不在（不靠试）。861 台账 304 KB 的人工阅读对照：单是"哪几路在途"就要 20 分钟以上。

---

## 2. 改造二：自动换路 —— 谁发现、谁换

### 2.1 三个机器可判触发器（全部落盘可判定，不依赖人感觉）

**T-HEARTBEAT（心跳超时）**
- 判据：`now - 心跳时间 > heartbeat_budget(默认 25 min)` 且 `状态 == 在途`
- 心跳怎么来：每路 Agent 每完成一个判定步骤就往台账行追加一行 `HB <ISO8601> <已看帧数>`——这是**纯追加**，不违反"不改旧行"，且成本几乎为零
- 排除项：`状态 != 在途`；或该路正在等 `SEG_RENDER_RESUME` 落盘（渲染员给 45 min 预算，比扫描员宽）

**T-BLOCKED（显式阻塞）**
- 判据：报告落盘且末尾 `STATUS: BLOCKED`
- 这是最便宜的触发器，**现状已经能判，只是没人去跑**。864 台账自己写了"14 路扫描全部回收完毕（无 BLOCKED、无超时换路）"——说明扫路阶段本来是健康的，问题全在后面的环节

**T-PHASE-STALL（阶段停滞）**
- 判据：某阶段全部在途路已空，但该阶段产出物不存在（如 `merge_decision_vN*.md` 缺失而所有扫描行都是"已验收"）
- 这是"无人换路无人降级"的直接形式：人不在 → 没人看到"该合了"

### 2.2 执行者：看门狗脚本，只出动作单，不自己干活

`scripts\dispatch_watchdog.ps1 -TaskDir <dir>`，**每次指挥上台就跑一次，也可挂 60 s 轮询**。它做三件事，**严格不碰内容**：

1. 读 `delivery_state.json` + 台账，算出全部触发器命中项
2. 把命中项写进 `cache\watchdog\actions-r<k>.md`——**一份可直接当 subagent prompt 用的换路派工单**（含 `resume_from` 断点秒 + 已有证据路径 + 复用不复看声明）
3. `delivery_state.json` 的 `watchdog` 段记录触发时间、命中规则、动作单路径

**为什么让它只出单不自己派**：换路要发 subagent，那是指挥的活。脚本不知道在途槽位、不知道 token 预算、不知道该不该先问人。脚本的价值是**把"发现"从依赖人变成依赖文件**，派发仍然走指挥（一次读一眼的成本，不是 7 小时的盲等）。

### 2.3 换路的降级阶梯（现行 §2.5 只写"冻结重派"，没有中间档）

```
第 1 次心跳超时  → 派 <路>b，resume_from=<已有证据最远秒>，attempt=2，复用证据
第 2 次仍超时    → 不再派第 3 路，改为【降级】：把该路标 SEAM，
                   时间线在该处按保守边界留缝，缺失段落记 needs_review 交人工
第 3 次          → 该区间整体按 needs_review 结案，写入交付报告的"已知缺口"节
```

现行规则"禁 848 repair-v1 式 4 轮"，方向对，但没有规定**什么时候停手**。补一条硬上限：**同一路 attempt ≤ 2**，第三次不是重派而是降级。这一条同时兜住"人工守着时也不会无限重试"。

---

## 3. 改造三：`delivery_state.json` —— 唯一状态文件

位置 `reports\delivery_state.json`（**必须在 `reports\` 下**：`cache\` 会被清理脚本删掉，这是 860 教训的直接应用）。单写者：只有指挥 + 看门狗（只写 watchdog 段）。

### 3.1 字段设计

```jsonc
{
  "schema": "naraka.delivery_state/1",
  "task_dir": "C:\\Project\\永劫无间\\123\\22.865... ",
  "task_number": 22,
  "material": "865永劫无间 2026-10-04 00-00-00",

  // ---- 环境基线（防止换了对话不知道工具在不在）----
  "env": {
    "checked_at": "2026-10-04T00:03:11+08:00",
    "check_summary": "ok=10 warn=0 blocker=0",
    "ffmpeg": "C:\\...\\ffmpeg.exe",
    "python": "C:\\...\\.video-tools\\venv\\Scripts\\python.exe"
  },

  // ---- 源与不变量（续跑时先校验这一段）----
  "source": {
    "path": "E:\\PR导出\\865....mp4",
    "duration_sec": 1194.4, "size": 5812345678,
    "mtime_utc": "2026-10-04T00:00:00Z",
    "sha1_first1mb": "9f2a...",       // 轻量防串源
    "baseline_verified": true          // 与 freeze_kit 的 size+mtime 比对
  },

  // ---- 阶段机（枚举，不是自由文本）----
  "phase": "MERGE_CANDIDATE",
  "phase_entered_at": "2026-10-04T02:11:40+08:00",
  "phases_done": ["PROBE","TRANSCRIBE","SCENE","THUMBS","SCAN","MERGE_CANDIDATE"],
  "mode": "complete_combat_roughcut",
  "tier": "regular",
  "concurrency": { "in_flight_scan_max": 10, "in_flight_global_max": 24 },

  // ---- 版本三件套（对齐 deliverables-and-qa 的"冻结号唯一"）----
  "version": {
    "current_N": 3,
    "frozen": false,
    "frozen_at": null,
    "frozen_kit": "reports\\freeze_kit_v3.json",
    "superseded": [1,2]
  },

  // ---- 在途路由（与台账行一一对应，台账是人读的，这份是机器读的）----
  "lanes": [
    { "id":"seg1", "kind":"scan", "range":[0,85], "status":"done",
      "dispatched_at":"...","heartbeat_at":"...","recycled_at":"...",
      "attempt":1, "report":"reports\\seg1_scan_report.md", "seam":null },
    { "id":"seg12", "kind":"scan", "range":[1019,1104], "status":"blocked_frozen",
      "attempt":2, "parent":"seg12", "resume_from":1063.4,
      "reason":"T-HEARTBEAT 40min", "report":null }
  ],
  "seams": [ { "id":"SEAM-seg12L", "kind":"pending", "left":"seg11", "right":"seg12b" } ],

  // ---- 下一步（可执行指令，不是描述）----
  "next_actions": [
    { "id":"A1","actor":"dispatcher","do":"派 seg12b","from":"watchdog\\actions-r3.md",
      "blocking":true },
    { "id":"A2","actor":"merger","do":"seg7 回后出 merge_decision_v3-partial-r5","blocking":false }
  ],

  // ---- 资产在/不在（决定"恢复要花多久"）----
  "assets": {
    "proxy_960.mp4":       { "present": true,  "path":"cache\\proxy_960.mp4" },
    "frames_2fps":         { "present": true,  "path":"shots\\" },
    "seg4k_cache":         { "present": true,  "path":"cache\\seg4k\\", "segments":18 },
    "preview":             { "present": false, "regen_min_est": 6 },
    "captions":            { "present": true,  "path":"captions\\source.srt" }
  },

  // ---- 4K 链（对着 6.57 h 空等来的）----
  "render": {
    "target": "E:\\Cujian导出\\865... cujian.mp4",
    "status": "not_started",          // not_started/encoding/concat/verifying/done
    "segments_total": 18, "segments_done": 0,
    "started_at": null, "last_progress_at": null,
    "watchdog_task": null,            // 装了看门狗计划任务后写任务名
    "auto_start_authorized": false    // 用户是否授权冻结即自动开渲
  },

  // ---- 交付态（cleanup 脚本读这个）----
  "delivery": {
    "phase":"pending",                // pending/delivered
    "master_verified": false,
    "verified_at": null,
    "verify_log": null,
    "cleanup_done": false
  },

  "watchdog": {
    "last_run_at": "2026-10-04T02:40:00+08:00",
    "last_run_verdict": "1 trigger fired",
    "triggered": [ {"rule":"T-HEARTBEAT","lane":"seg12","age_min":40,"action":"actions-r3.md"} ]
  },

  "updated_at": "2026-10-04T02:40:03+08:00",
  "updated_by": "dispatch_watchdog"
}
```

### 3.2 谁写、什么时候写

| 写者 | 何时 | 写哪段 |
|---|---|---|
| 指挥（主 Agent） | 每次派工、每次回收、每次版本变更 | 全部除 `watchdog` |
| `dispatch_watchdog.ps1` | 每次上台必跑 + 可轮询 | 仅 `watchdog` + `render.last_progress_at` |
| `cleanup_after_master.ps1` | 收尾 | 仅 `delivery` |

### 3.3 这一项直接消灭的等待

- 6.57 h 冻结→4K 空等：`render.status` 从 `not_started` 起就在文件里，看门狗第一次跑就发现"已冻结但 4K 未起"，当场出动作单。**这是 6.57 h 里那 ≥85% 的"链路没启动"部分**
- 人工恢复：新 Agent 读一个 JSON 就知道该干什么，不用读 304 KB 台账
- `assets` 段把"缓存被清了"的代价提前显式化：不再出现"渲到一半崩了才发现在途抽帧已经没了"

---

## 4. 改造四：流式合成 —— 岛式合并不是废掉，是补一个条件

### 4.1 先定性：为什么它四局没用过

不是规则错，是**规则自相矛盾**。三处明文互相打死：

- `roughcut-launch.md §2.3`：「字幕员、渲染员、自审员**只认冻结版，不认 partial**」
- `§2.8`：「partial 命名 `merge_decision_vN-partial-r{k}`（**永不转正**，只能被修线员重算替代；**字幕/渲染/自审禁认 partial**）」
- `§2.8`：「（合并**在途 1**、**离线岛 →**）…只有离线岛有排空价值」

于是：partial 只能被下一棒消费，而下一棒是字幕/渲染/自审——它们被明文禁止吃 partial。**整条链上没有任何一个角色被授权消费它生产的产物。** 一个产物如果下游无人授权消费，它在实践中必然零产出。这不是执行不到位，是设计上的死结。

### 4.2 建议：**保留，改成一个新角色**（不叫"渲染员认 partial"，叫"预览员认 partial"）

修订后的规则文本（替换 `§2.8` 第三条与 `§2.3` 第二条末句）：

> ### 2.8 修订（orchestration-2026-10-04）
>
> **partial 草稿的消费者从"无"改为"预览员"，且只限 `wip-` 旁路（见 §2.3-wip）。**
>
> 1. `merge_decision_vN-partial-r{k}` 仍**永不转正**、不进 `timeline/`、不作 QA 依据——这一条不动。
> 2. 新增唯一合法消费者：**预览员**。它可基于 partial 出 `preview\<序号>-wip-<r{k}>.mp4`，状态 `PARTIAL-WIP`。
> 3. **字幕员、自审员、验收员、成片渲染员仍只认冻结版**——禁令从三个角色收窄为两个（字幕员/验收员 + 成片渲染员），是收窄不是放宽。
> 4. `wip-` 预览**带水印**（左上角常驻 `PARTIAL r{k} · NOT FREEZABLE · NOT FOR QA`，渲染时用 drawtext 烧进预览像素）。
>    > 例外说明：这条烧的是**状态标识**，不是字幕，不违反 `AGENTS.md §5` 的"零烧录"——后者禁的是字幕内容。为避免争议，实现上优先用**文件名 + 播放器标题元数据**，drawtext 仅作兜底。
> 5. **`wip-` 预览禁止进入任何 QA / 验收 / 交付路径**：`qa_gate.py`、四验收角色、`freeze_kit`、`verify_master.sh` 一律读取即拒（按前缀拒，成本 3 行代码）。成片**永不**从 `wip-` 放大渲染。
> 6. 生命周期：`wip-` 预览在对应 `partial-r{k+1}` 落盘时或冻结版落盘时**即删**，不留旧版本。交付清单必须列 `wip-` 数 = 0。
> 7. **降级触发条件**（这是把逃生阀真正接上的关键）：当 `partial` 与最近冻结候选的节目时长差 ≤ 15%（或剩余在途路 ≤ 2），`dispatch_watchdog` **必须**派一路出 `wip-` 预览，不得因"还没冻结"而不派。

### 4.3 为什么这样改能省时间

861 的 26/29 路在 partial 阶段，白等 **8.42 h**（05 号实测）。有了第 7 条，"还在等最后 3 路"不再等于"用户看不到东西"。对 864-att1 那种"审片越多越糟"的局面，还有一层好处：**`wip-` 给的是"整体连贯性"的粗判依据，而对抗审给的是"逐点对错"**。用 wip 解决连贯性判断、把对抗审留给真正需要逐点裁决的场景，本身就在压审片轮次（呼应 06 号结论）。

### 4.4 不要做的改法

- ❌ 直接让渲染员/字幕员认 partial —— 会让半成品字幕/成片沿冻结链路流下去，风险不可逆
- ❌ 废掉岛式合并 —— 它在 `offline岛` 场景（抽帧被清理后需要补扫的区块）仍有真实价值；且它是 §2.5 换路后"新旧择优合入"的载体
- ❌ 把"永不转正"删掉 —— 血统唯一性是版本正确性的地基

---

## 5. 改造五：渲染旁路 `wip-` 风险评估

### 5.1 方案

扫描回收过半 → 修线员出 partial → 预览员出 `preview\<序号>-wip-<r{k}>.mp4`（720p，和 review 同规格，**从源重渲，不用 preview 放大**）。861 首版 10.05 h → 约 1.63 h。

### 5.2 风险：半成品被当成品交付

这个风险是**真实的**，但可控——前提是拦住四条泄漏路径：

| 泄漏路径 | 严重度 | 拦截手段 | 成本 |
|---|---|---|---|
| ① 用户把 `wip-` 看成成片/预览提交意见 | **高**（用户可能说"这版可以"） | 前缀 + 片内水印 + **台账与 `delivery_state.json` 显式记 `not_freezable`**；给用户的每次汇报里 wip 版本必须显式标注 | 3 行 |
| ② QA/验收误吃 wip 版当 QA 依据 | **高**（会得出"漏战命中恒为 0"这种假绿） | `qa_gate.py` / `freeze_kit` / 四验收按前缀拒收，退出码非 0 | 3 行 |
| ③ 成片从 wip 放大渲染 | **不可逆**（4K 放大画质事故 + 交付事故） | 成片渲染只认 `timeline\combat_episodes_vN.json`（FROZEN），**根本不读 preview 目录**；再加断言"输入 preview 文件名不含 wip-" | 2 行 |
| ④ `wip-` 残留被当成现行版 | 中 | 生命周期：下一 partial 或冻结版落地即删；交付清单列 `wip-` 数 = 0；`check_task_hygiene.ps1` 加一条"非 FROZEN 状态下存在 preview 数量 > 1 即 WARN" | 5 行 |

### 5.3 剩余风险（说清楚，不粉饰）

- **用户侧语义混淆是唯一无法脚本消除的风险**。脚本能保证 wip 版不进成片、进不了 QA，但**保证不了用户不会把 wip 当成审片对象**。缓解只能靠两件事：(a) 片内水印；(b) 汇报话术强制标注。这是需要用户知情的一项（见 §6）。
- wip 预览会**增加一次渲染**（861 约 +5~8 min）。净收益仍是正（8.42 h >> 0.13 h），但要如实记进 `workflow_notes`。
- wip 与 review 同在 `preview\`，若用户播放器按目录排序可能误开。缓解：wip 统一放 `preview\wip\`，review 放 `preview\`。

### 5.4 与岛式合并的关系

改造四是**授权**，改造五是**载体**。两者必须同时上，只上一个都无效：
- 只做四不改三（授权了但没预览员这个角色）→ 无产出
- 只做五不改四（渲染员直接吃 partial）→ 撞上 §2.8 禁令，规则冲突，执行时必然回退到"等人"

---

## 6. 需要用户点头的项 / 可自做的项

| # | 改造 | 判定 | 理由 |
|---|---|---|---|
| 1 | 续跑（台账补列 + resume 上提 `scripts\` + `resume_task.ps1`） | 🟢 **自做** | 纯内部机制，不改产物、不改对外行为。台账补列是 §2.3 已明文要求而未执行的部分，属于补执行。resume 从任务目录上提到 `scripts\` 是修 bug |
| 2 | 自动换路（心跳列 + `dispatch_watchdog.ps1` + attempt≤2 降级） | 🟢 **自做** | 内部机制。但**一处需用户知情**：attempt≤2 后自动降级为 `SEAM`/`needs_review`，意味着"极慢的路会被放弃并留缺口"。这是质量取舍，建议实现时把降级写进交付报告的"已知缺口"节（可见、可追责），不改默认参数 |
| 3 | `delivery_state.json` | 🟡 **主体自做，1 项需点头** | 文件本身纯内部。**需点头的是 `render.auto_start_authorized`**：现行规则（07 号报告查实）要求"4K 出片必须用户明确要求、不自行发起"。若采纳"冻结即自动开渲 + 持久看门狗"，等于**用户离开后系统仍在向 `E:\Cujian导出` 写入 1.4~2.6 GB 文件并触发清理脚本删任务目录产物**。这是对外可见 + 不可逆动作 → 需用户显式授权一次（授权位可后续手动关） |
| 4 | 流式合成（partial 加条件，授权"预览员"角色） | 🟡 **需点头（规则变更）** | 修改 skill 内 `§2.3`/`§2.8` 的禁令条文。虽收窄而非放宽，但**它改的是用户在 §2.8 立过的规矩**，且新增了一个角色 = 改变变更范围。需用户同意后改 skill 文本 |
| 5 | 渲染旁路 `wip-` | 🔴 **需点头** | 用户会直接看到 wip 预览并可能据此给意见。**"用户可能误把未冻结预览当成品"是唯一无法用脚本消除的风险**（§5.3）。必须用户知情并同意 |
| 6 | 优先级排序 | 🟢 自做 | — |

**汇总：4 项改造中需用户点头的 3 项（#3 的自动开渲钩子、#4、#5），属内部机制可自做的 2 项（#1、#2）。**

---

## 7. 最该先做的两项

**先做 #3 `delivery_state.json` + #2 看门狗。**

理由不是它们最省时间，而是**它们是其余四项的落地条件**：

- #1 续跑要读它（没状态文件，新 Agent 还是在读散文）
- #4 的降级触发条件要它来判（"partial 与冻结候选差 ≤15%"是数值判定，只有文件里才有）
- #5 的 wip 清理要它记生命周期
- #3 的看门狗本身是唯一能在**无人值守时**还在跑的东西

先做 #4/#5 会在没有状态文件的情况下再造一层需要靠人同步的机制，等于把现在的问题换个地方再犯一遍。

---

## 8. 时间账：这 6 项能把 10 h 压到多少

以 **861 的 10.05 h 首版**为基线（该局最有代表性：3 路被服务重启吞掉、首版等齐 26/29 路才动）：

| 阶段 | 现状 | 改造后 | 省 |
|---|---|---|---|
| 扫描（29 路） | 3 路被吞 → 无人换路 → 干等至第 2 批收齐 | 心跳 25 min 触发换路 + `segNb` 接断点 | **≈ −3.0 h** |
| 等齐再合 + 首版预览 | 26/29 才开渲 | 过半出 partial → `wip-` 旁路，19:15 就有东西看 | **≈ −8.4 h**（部分与上项重叠，见下） |
| 冻结 → 4K | 等人想起来，1.59 h | 看门狗首轮即发现"已冻结未起渲"，授权后自动开渲 | **≈ −1.4 h** |
| 收尾清理 | 手工 | `cleanup_after_master.ps1` 读 `delivery_state.delivery` 自动判定 | **≈ −0.1 h** |

**净账（保守口径，只算无重叠部分）**：10.05 h → **约 2.2 ~ 2.6 h**。
主项是 wip 旁路（8.42 h，但与"等齐"有部分重叠），次项是自动换路（约 3.0 h，同样有重叠），再次是自动开渲（约 1.4 h，重叠最少、最确定）。

**交叉验证**：864 首版 2.94 h 是**没有故障**的情况。2.2~2.6 h 这个数**优于无故障基线**，说明口径可能偏乐观。更稳的说法：

> **故障局（861 型）10.05 h → 约 3 ~ 4 h；正常局（864 型）2.94 h → 约 1.5 ~ 2 h。**
> 也就是说：**改动的价值不在"正常局更快"，而在"故障局不再塌成 10 h"。** 三局 span 62.52 h 里若按此口径回填，单这一项能回收 **≈ 12 ~ 15 h**。

**这条收益的性质要说清楚**：它买的不是吞吐，是**尾部延迟**。现在用户面对的是"要么 3 h，要么 10 h，看运气"。改造后是"稳定 3 h，偶尔 4 h"。

---

## 9. 落地顺序（依赖拓扑）

```
第 1 步（自做）  delivery_state.json schema + dispatch_watchdog.ps1 + resume_task.ps1
                 → 立刻有：故障检测、状态可读、6.57h 空等的消灭
                 ↓
第 2 步（需点头①）  render.auto_start_authorized：冻结即自动开渲 + 持久看门狗
                 → 6.31 h 的 ≥85% 直接回收
                 ↓
第 3 步（自做）  台账补列（回收时间/心跳/attempt/父路）+ resume 上提 scripts\
                 → 续跑能力、attempt≤2 降级阶梯
                 ↓
第 4 步（需点头②）  §2.3/§2.8 修订：授权"预览员"吃 partial
第 5 步（需点头③）  wip- 旁路实现 + 四条泄漏拦截 + 片内水印
                 → 8.42 h 的回收
```

第 1 步做完就能独立产生收益，不必等任何点头。第 4/5 步绑在一起上，中间态无收益（授权了没载体 / 有载体没授权都会回退到"等人"）。

---

## 10. 与既有规则的关系（避免本改造自己变成新债）

| 既有规则 | 本改造 | 冲突检查 |
|---|---|---|
| `AGENTS.md §2.7` 台账只由指挥追加 | 看门狗只写 `delivery_state.watchdog` 段，不碰台账 | ✅ 无冲突。**关键设计约束**：看门狗不得写台账，否则违反单写者 |
| `§2.3` 台账「只追加不改旧行」 | 心跳以 `HB <ts>` 追加行 | ✅ 兼容 |
| `§2.5` 禁 848 式 4 轮 | 补 attempt≤2 硬上限 | ✅ 是补充不是放宽 |
| `§2.8` 冻结号全局唯一 | wip 不进 `timeline\`，不占版本号 | ✅ 无冲突 |
| `§2.6` 成片 NVENC 全局锁只认冻结版 | wip 是 720p 预览，与成片锁分离 | ✅ 兼容 |
| `AGENTS.md §5` 零烧录零内嵌 | wip 水印为**状态标识**，非字幕；优先用文件名/元数据 | ⚠️ 需在 §5 补一句例外说明，避免以后被自己判违规 |
| `deliverables-and-qa.md` 命名三分立 | 加 `preview\wip\<序号>-wip-<r{k}>.mp4` 一种旁路命名 | ⚠️ 命名表要同步加这一行，否则 §7 核对会漏 |
| `cleanup_after_master.ps1` 护栏 | 加一条"非 DELIVERED 态拒删 cache\" | ✅ 收紧，方向一致 |