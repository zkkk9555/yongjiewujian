# 修线员作业书（任务 21 / 素材 864）

你是「修线员」，负责把 14 路扫描报告合成**一条无缝时间线**。你不重抽帧、不重看图定边界，只认书面报告加证据帧路径。
指挥（主对话）不看图、不改 `timeline/`、只验收落盘产物。

## 绝对路径

| 用途 | 路径 |
|---|---|
| 任务目录 TASK | `C:\Project\永劫无间\123\21.864永劫无间 2026-09-30 02-57-13` |
| 源素材（只读） | `E:\PR导出\864永劫无间 2026-09-30 02-57-13.mp4`，1152.233 秒 |
| 扫描报告 | `TASK\reports\seg1_scan_report.md` … `seg14_scan_report.md` |
| 派工台账 | `TASK\reports\dispatch_ledger.md`（只读，不许你改） |
| 扫描员规约 | `TASK\reports\scanner_brief_common.md`（判定口径来源） |
| 时间线（你写） | `TASK\timeline\combat_episodes_v1.json` |
| 校验输出（你写） | `TASK\reports\v1_validate.json` |
| 合并决策（你写） | `TASK\reports\merge_decision_v1.md` |
| 节目映射（脚本写） | `TASK\timeline\program_map_v1.json` |

## 工具

- Python：`C:\Project\永劫无间\.video-tools\venv\Scripts\python.exe`
- 校验脚本：`C:\Project\永劫无间\skills\naraka-highlight-studio\scripts\validate_combat_timeline.py`
- 几何模块：`C:\Project\永劫无间\skills\naraka-highlight-studio\scripts\episode_geometry.py`（节目时长唯一口径，含 `excluded_inside` 挖洞）
- 禁止新建虚拟环境、禁止 pip install、禁止出 4K、禁止渲染 MP4、禁止看图。

## 时间线 JSON 格式（字段名以 validate 脚本为准）

```json
{
 "schema": "naraka-combat-roughcut-timeline/v1",
 "version": "v1",
 "source": "E:\\PR导出\\864永劫无间 2026-09-30 02-57-13.mp4",
 "source_duration": 1152.233,
 "program_seconds_total": <由 episode_geometry 算出的值>,
 "combat_episodes": [
  {
   "id": "combat_001",
   "source": "E:\\PR导出\\864永劫无间 2026-09-30 02-57-13.mp4",
   "source_start": 181.0,
   "source_end": 261.0,
   "engage_start": 186.0,
   "impact_points": [200.0, 212.0],
   "outcome_time": 253.0,
   "boundary_reason": "……",
   "event_types": ["kill", "parry"],
   "confidence": 0.9,
   "complete": true,
   "needs_review": false,
   "excluded_inside": [],
   "notes": "……",
   "evidence": {"head": ["…hd 帧绝对路径"], "tail": ["…"], "sheets": ["…"]}
  }
 ],
 "deleted_intervals": [
  {"start": 0.0, "end": 181.0, "category": "travel_loot_wait", "reason": "……"}
 ]
}
```

硬性要求：

1. `episode` 用 `engage_start`（**不是** `engage`）；删除审计用 `deleted_intervals`（**不是** `deletions`/`gaps`）。
2. `deleted_intervals` **必须内嵌在时间线 JSON 本体**，独立审计文件不算过门。
3. `deleted_intervals` 与 `combat_episodes` 必须**无缝覆盖** `[0, 1152.233]`：不留缝、不重叠、不越界。
4. episode 必须单调不重叠：`0 <= source_start < engage_start <= outcome_time <= source_end <= 1152.233`，且下一段的 `source_start >= 上一段的 source_end`。
5. `needs_review: true` 的段**不得**进入送审预览。你必须先用报告里的证据把它定死（要么补齐证据升为 `false`，要么降级为删除段并写明理由）。
6. `excluded_inside` 是**源时间轴上的洞**（战斗中开了战利品面板/进菜单/无信息停顿）。节目时长要扣掉它：
   `program_seconds = Σ[(source_end − source_start) − Σ(hole.end − hole.start)]`
   用 `episode_geometry.timeline_program_seconds()` 算，别手算。
   洞必须完全落在 episode 内部、长度非正、不得吃光整段。

## 合成规则（判定尺度唯一来源：`scanner_brief_common.md` 第 5 节）

- 一场战斗 = 第一次明确交战 → 结果明确（击杀／团灭／敌人逃脱／玩家脱险／胜负已分）+ 短暂收束。
- **战斗中不切走。宁可留长，不漏战、不切断。**
- 前置默认 5 秒（`lead_in`），前置里必须能看懂"为什么打起来"。
- 内部停顿 < 8 秒（`internal_gap`）先保留在同一场内。
- 停顿 < 12 秒（`rejoin_window`）且同战区、战斗信号连续 → 合并为同一场。间隔 < 12 秒但期间无战斗信号、上一场已有完整收束 → 判两场成立。
- 结果后至少 8 秒（`outcome_hold`）+ 5 秒（`recovery_tail`）= **13 秒尾部验证窗**；窗内任一秒出现战斗信号就重置时钟。
- 两场之间 ≤ 5 秒纯战术间隙（战后感叹词、无新交战）**并入上一场尾**，不单独成删除段。
- 删：跑图、搜物资、等待、重复操作、长时间无事件（>120 秒的删除段必须由报告里的独立抽帧核验支撑）。
- 留：拉扯、救援、追击、躲技能、重新接战 —— 同一场战斗的一部分。
- **玩家倒地 ≠ 这段没战斗**：死亡原因链 = 掉血过程 + 击杀提示 + 等待救援/结算 + **队友来救／转返魂／重新站起来**。整段"等待救援"不得作为无战斗删除。
- 终局结算（段位屏/加分屏）若出现：从终局起保留「终局 → 结算屏」完整片段，并入最后一战（只改 `source_end`），不得独立成段。
- 自动标签（转写关键词、音频能量、场景变化）只是候选信号，不能单独当"这里有战斗"的证据。

## 重叠带互证（5 秒带，全局单裁决，裁决权在你）

相邻两路的 5 秒重叠带必须**双方各给至少 1 个相互独立的证据**（画面三信号／连续战斗声／连续战斗语音中任一，但不得复用同一帧）才可合并。
互证失败（一方说有战斗一方说跑图、边界差 > 3 秒、一方 `needs_review`）**不硬合**：按保守边界落盘，中间缝标 `needs_review`，并在 `merge_decision_v1.md` 里点名"哪一路的哪一秒需要定点复核"。

## 指挥交接指令（14 路全回，以下为跨路硬指令，必须逐条处置）

### A. 取证材料可信度（先读这条，否则会误删）

1. `shots\segN\thumbs\` 与 `shots\segN\sheets\` 的**联系表每路只覆盖该路前 85 秒**，5 秒重叠带的帧被分给了上一路（切分脚本先到先得）。所以 `segN_sheet01` 的首格**不是** `segN` 的起点。**重叠带互证请一律用 `shots\segN\hd\`，那里每路有完整 90 帧**（末路 47 帧）。seg2、seg10 的报告已独立发现并绕过此坑。
2. **`cache\make_route_frames.ps1` 不可信，禁止用作证据**：在本机 ffmpeg 上，input `-ss` 叠加 `fps=` / `setpts=` 会把流压成重复帧（seg8 实测 8 秒区间输出 600 个 MD5 相同的帧）。**唯一经过验证的高清帧来源是 `shots\segN\hd\tXXXX.0.jpg`** —— 全片单遍抽取、1152 帧、MD5 互不相同、文件名秒点 == 烧入 h:mm:ss == 源秒、代理 offset = 0。
3. **480x270 联系表看不见 1–2 px 高的敌方红血条**（seg8 实测：632–636 / 648 / 671–674 三处初筛「没在打」全被 960x540 推翻）。所有 `needs_review` 与删除判定必须回到 `hd\` 的 960x540 帧。

### B. 跨路合并/边界硬指令

| # | 涉及路 | 指令 |
|---|---|---|
| B1 | seg3 ↔ seg4 | seg3 的 E3 `[234,256]` **收束未走完**（t0255–t0259 背包面板疑似仍开）。seg4 判定 `[255,260)` 属 seg3 的收束尾巴。→ E3 的 `source_end` 至少延到 **261.0**（保险 266），**不得**把 `[255,260)` 单独做成删除段 |
| B2 | seg3 内部 | E1 `[181,215]`、E2 `[216,235]`、E3 `[234,256]`，E1↔E2 间隔 7s、E2↔E3 间隔 4–5s，**都 ≤ rejoin_window 12s / internal_gap 8s**。按"宁可留长、不漏战"优先：**若中间无明确脱离、无新交战、战斗语音连续，合并为 `[181,261]`**；若你判定任一间隔内战斗信号中断、上一场已有完整收束，才允许分三场。两种都要在 merge_decision 里写明采信理由。 |
| B3 | seg5 ↔ seg6 | seg5 的 EP-B `[412,430+]` 尾部无法闭合（427.5 起玩家倒地，13 秒验证窗在段内只覆盖 2.5 秒且三信号成立）；seg6 的 E1-T `[425,442]` 是它的收尾跑路段（426 有两个敌方红血条、430 脱身）。→ **合并为 `[412,442]`**，`outcome_time` = 430.0（玩家脱险） |
| B4 | seg6 ↔ seg7 | seg6 的 E2 `[495,515]` 真实尾 **517.5**（收束第 2、3 步落在 514–517）；seg7 的 E1 `[510,517.5]` 是同一场。→ **合并为 `[495,517.5]`**，`outcome_time` = 512.0（击杀+连杀"3"） |
| B5 | seg7 内部 | E1 尾 517.5 → E2 头 528，间隔 10.5s（< rejoin 12s）。seg7 建议拆。→ 你裁决：中间 `[517.5,528)` 若无战斗信号、上一场已有完整收束，判两场成立；若有连续战斗信号，合并 |
| B6 | seg7 → seg8 | seg7 末场止于 556.5，`[556.5,600)` 为舔包/整备/移动；seg7 查 584–599 无红血条。红血条首帧 = **602.0**（seg8 逐帧确认，596–601 全零）。→ seg8 的 `source_start` = **597.0**（602 − 5s lead_in） |
| B7 | seg8 ↔ seg9 | seg8 的 E1 `[597,683]`；seg9 判 `[680,685)` 是它的战后余波，**若 seg8 要走收束三步第 2 步应留给它当尾巴，不要整段删**。→ E1 的 `source_end` 至少 **683.0**，建议 **685.0** |
| B8 | seg9 ↔ seg10 | seg9 的 E1 `[722,770]` 真实尾 ≥784（战局未结束，收束三步全缺）；seg10 的 E1 `[765,800]` 是同一场（seg10 独立判定 765–770 重叠带 = 有战斗，且 `engage_start ≤ 764` 归 seg9）。→ **合并为 `[722,800]`**，`outcome_time` = 792.0（敌方整队团灭，含玩家本人 790.0 的击杀） |
| B9 | seg10 内部 | E2 `[793,800]` confidence low / needs_review，seg10 建议整段删。→ 落在 E1 区间内，**直接不单独建段**；若删，用 `excluded_inside` 或直接让 E1 覆盖，不要产生重叠 |
| B10 | seg10 尾 | seg10 自查：严格按 13 秒尾部验证窗应到 **810.5**，它只收到 800.0。→ 你裁决延到 800.0 还是 810.0，理由写清 |
| B11 | seg10 尾 → seg11 | seg10 报 `[801,833]` 是买卖搜刮闭环（`801 转商店`）、`837–838.5` 开全屏地图导航、839 后一路滑翔。→ 与 seg11 的 `[850,880]` 交易段之间的删除段，category 写 `trade_loot_navigation` |
| B12 | seg11 ↔ seg12 | seg11 的 E1 `[911,940]` 尾界未闭合（真实尾约 **943**）；seg12 独立判定 `[935,940)` 是 seg11 那场的收尾/转场、**不在 940.0 新起场**。→ E1 的 `source_end` 取 **943.0**；`[943,949)` 是 6 秒间隙，按"两场间 ≤5 秒纯战术间隙并入上一场尾"规则处理：≤5 就并入上一场尾（→ `source_end` 948.0），>5 就做成删除段 |
| B13 | seg12 ↔ seg13 | seg12 的 E12-1 `[949,1037]`，`engage_start` = **954.0**（红血条首帧），outcome 1024.0（脱险）；其尾部验证窗 1025–1037 跨段。seg13 **独立否定** 1020–1024 的 engage 候选（"他要死了"是画外队友处境），1020–1057 为纯跑图。→ 边界 1037 站得住，**不得在 1025.0 切断** |
| B14 | seg12 头 | seg12 标 `[935,949)` 为 needs_review。→ 由 B12 一并处置 |
| B15 | seg13 | `seg13-ep01 = [1053,1101]`，`engage_start` 1058.0，`outcome_time` 1088.0（团灭失败，绿焰吞没+1089「失败」大字+1090「战报」）。**结算屏已并入**（1097 黑屏 → 1098 三角色过场 → 1099/1100 分数卡 → 1101 回大厅），只改 `source_end` = 1101.0，未独立成段。 |
| B16 | seg13 ↔ seg14 | 1101 之后是回大厅 idle 屏（1105–1109 五帧完全相同的静态加载原画）。按 seg14 的结论处置；成片**不得**出现"打完 → 黑屏"或"结算凭空出现" |
| B17 | seg11 needs_review | seg11 对 `904.8「没事我杀了」` 判**不成立**（画面是「获得物品」横幅、905 背包面板、播报栏无本队击杀者），但要求**保留不挖**并标 needs_review。→ 你必须处置：给独立证据（`shots\seg11\verify\` 里有 4K 裁切：killfeed / banner / banner4k / teambar / feed4k / feed4k_early）后升为删除段或降为保留，**不许把 needs_review 悬进冻结版** |
| B18 | seg2 needs_review | seg2 判 `[85,175)` 全段无战斗，零三信号。`[85,90)` 用 `hd\t0085..t0089` 独立判为涉水+舔包。→ 归入删除段，category `travel_loot` |
| B19 | seg1 needs_review | seg1 判 `[0,90)` 全段无战斗；`t49–50`「小心行善」是善恶值提示、`t66–72` 紫/红文字是左上角**全局击杀播报栏**（他人对局事件流），画面无敌人。→ 归入删除段，category `birth_ability_ui_travel` |
| B20 | seg6 更正 | seg6 指出 `[442,495]` 才是删除段（53 秒跑图+全屏背包/魂玉 UI），且 **482.0–509.5 音频连续活动、499–514 是确证战斗**（伤害数字 117/114、锁定线、玩家倒地、击杀横幅）。→ 派单里"475–517 静音"的说法**作废**，以 seg6 实测为准 |
| B21 | seg7 修正 | seg7 第一轮曾把 `[528,543]` 误判为跑图，用高清帧推翻（531/539 取到敌方红血条，531 另有玩家被掀飞+地面血迹）→ 改为 E2 `[528,556.5]`，engage 528.0（可能早至 525，seg7 标 needs_review），outcome 549.0（击杀横幅+红色伤害数字「1319」+全屏金色冲击波）。→ 你用 `hd\t0524..t0528` 定死 engage |
| B22 | seg7 needs_review | seg7 报 `[517.5,528)` **缺 HD 直接证据**（只有 480x270 联系表 + 语音 + 无长音频活动）。→ 你用 `hd\t0517..t0528` 的 960x540 帧裁决：这一段到底是有战斗（则并入 B5 合并）还是舔包/整备（则做成删除段） |
| B23 | seg9 修正 | seg9 **否决**了「我去找他了」作为开战证据（719→730 十帧全带蓝色队友名条，绿色长线是钩锁瞄准线）。engage 定 **731.0**（首次贴身刀光），**732.0 是敌方红血条首帧**；`[726,730]` 的紫色爆散与 705 暗域晶格同形态，判环境不判交战。→ `source_start` 至少 **722.0**（= 731 − 9s 前置），注意 703–716 换装丢弃 UI、718.5–722 平台穿行 |
| B24 | seg9 needs_review | seg9 报 `t0717` 有横向白色救援光 + 青色队友形象 + 该队友血条残缺，形态符合"复活白光即战斗"，但无敌方红条。→ 你用 `hd\t0714..t0720` 裁决是否要建救援段 |
| B25 | seg2 硬结论 | seg2 的高清帧核验显示 `[154,172]` 队伍面板三人血条**始终全满**、小地图只有 3 个紧邻己方标记、无敌方红点或受击 ping；`154.5/161.7「誰在打我」` 是**队友间排查提问**（疑为排查攻击性道具/技能误伤），非交战。→ 支持删除 |
| B26 | seg3 硬结论 | seg3 指出「哦 起来了」（233–243）是 faster-whisper 单句幻觉循环，**不是倒地被救**；实画面 240 被击飞横躺 → 241 横卧 → 242 已站立 → 243 金色护体再战，仅 1–2 秒，相机仍是越肩第三人称、无复活白光。→ 是同场内 `knockdown`，不触发救援链，无需拆段 |
| B27 | seg10 硬结论 | seg10 核实**本段玩家没有死亡**：793.2「诶 死了」是队友对"敌方被淘汰"的反应；玩家 792.0–801.5 全程站立/奔跑/持械，无红屏无倒地 HUD 无「等待救援」横幅，能力轮全程点亮，796–797 只是受身击退。→ **不建死亡链段** |
| B28 | 收束三步缺项 | seg8 报其 E1 缺①击杀播报（这场是 `escape` 脱险收的，播报栏全是他人淘汰）；seg13 报其 ep01 缺③跑路（团灭失败，客观上不存在胜利后舔包跑路），已用 1088→1101 共 13 秒完整链替代。→ 允许这两处例外，但**必须在 merge_decision 里逐条写明"缺哪一步 + 为什么这场的结局形态决定它不存在 + 替代收束是什么"** |
| B29 | seg13 ↔ seg14（结算链，**最高优先**） | seg14 逐帧实测三屏完整：战报/名次屏（第 3/8 名）`[1115.9, 1121.7)`、段位/加分屏（破境 4 段 + 2967(+50)）`[1121.7, 1123.8)`、熟练屏（171 级）`[1123.8, 1127.4)`。前置：黑屏结算过场 `[1096.0, 1097.8)` + 队伍战绩展示（含返回大厅/分享）`[1097.8, 1100.8)`；对局内最后一帧 1095.8，**1096.0 为终局**。→ seg13 那一战的 `source_end` **必须延到 1127.5**，`outcome_time` 落在段位确认帧 **1122.5**，`event_types` 加 `settlement`。**绝不能切在"打完 → 黑屏/结算前"。** |
| B30 | seg13 挖洞 | `[1100.8, 1115.9)` 共 **15.1 秒纯加载屏**（seg14 建议挖，标 needs_review）。→ 这是全片唯一一段合法的 `excluded_inside` 挖洞（终局过场已完整保留在前、结算三屏完整保留在后，中间只是加载）。用 `excluded_inside: [{"start":1100.8,"end":1115.9,"category":"loading_screen","reason":"终局过场与结算屏之间的纯加载，无信息"}]`。**节目时长要扣掉这 15.1 秒**（用 `episode_geometry.timeline_program_seconds()` 算，别手算） |
| B31 | seg14 尾 | 1129–1152 共 23.3 秒画面零变化（`1105–1109` 五帧完全相同的静态加载原画）→ 归入删除段，category `lobby_idle`。片尾自然收尾止于 1127.5（最多 1129.0） |
| B32 | 工具缺陷（横向，三路独立复现） | `cache\make_route_frames.ps1` **确认不可用**：input `-ss` 配 `-t`（或 `-to`）在本机 ffmpeg 上会把整段重复吐出（seg8 实测 8 秒区间 → 600 个同 MD5 帧；seg14 实测误生成 2200+ 帧垃圾；seg10 改用 `-i` 之后 `-ss` 才正常）。**禁止用该脚本产出的任何帧作证据。** seg10 报告 §10、seg14 报告 §10 各写了正确写法。唯一可信高清来源 = `shots\segN\hd\` |

### C. 合规

`needs_review: true` 的段**一律不得**进入送审预览。全部 14 路点名过的 needs_review 点（B5、B11、B12、B14、B17、B21、B22、B24）必须逐条给出处置。


### 1. `TASK\timeline\combat_episodes_v1.json`
上面那个格式。

### 2. `TASK\reports\v1_validate.json`（**必须实跑，不许手写**）

```powershell
& 'C:\Project\永劫无间\.video-tools\venv\Scripts\python.exe' `
  'C:\Project\永劫无间\skills\naraka-highlight-studio\scripts\validate_combat_timeline.py' `
  'C:\Project\永劫无间\123\21.864永劫无间 2026-09-30 02-57-13\timeline\combat_episodes_v1.json' `
  --source-duration 1152.233 `
  --output 'C:\Project\永劫无间\123\21.864永劫无间 2026-09-30 02-57-13\reports\v1_validate.json'
```

必须 `pass=true` 才算过门。warnings 只允许是已声明并已处理完的项；不许有 `needs_review` 残留。

### 3. `TASK\reports\merge_decision_v1.md`（不写即视为未合）
必含：
- 用了哪 14 路报告（逐一点名 + 各自 STATUS）
- 每段采信了谁的边界、为什么
- 5 秒重叠带逐带的互证结果（双方证据帧路径）
- 每个 `deleted_intervals` 条目的 category 与依据
- `needs_review` 的逐条处置（升为 false / 降为删除段 / 拆段），写明依据
- validate 实跑结论（pass 值、episode 数、deleted 条数、warnings 分类）
- 节目总秒数与算式
- 结尾单独一行 `STATUS: DONE` 或 `STATUS: BLOCKED`

## 禁止事项

- 禁止重抽帧、重看图定边界 —— 你只认书面报告加证据帧路径。
- 禁止改 `TASK\reports\dispatch_ledger.md`（台账只由指挥追加）。
- 禁止改 `TASK\reports\segN_scan_report.md`。
- 禁止渲染任何 MP4；禁止出 4K。
- 禁止写 TASK 目录以外的任何路径。

做完后回一句：episode 数、每段 [start,end]、节目总秒、validate pass 值、STATUS。
