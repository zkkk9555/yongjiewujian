# 扫描员通用作业书（任务 21 / 素材 864）

本文件是本任务 14 路扫描员的共同规约。每路的 prompt 只写「你负责哪一段」，其余全部以本文件为准。
指挥（主对话）不看图、不动 FFmpeg、不改时间线，只验收落盘报告。

## 1. 绝对路径

| 用途 | 路径 |
|---|---|
| 任务目录 TASK | `C:\Project\永劫无间\123\21.864永劫无间 2026-09-30 02-57-13` |
| 源素材 SRC（只读） | `E:\PR导出\864永劫无间 2026-09-30 02-57-13.mp4` |
| Python | `C:\Project\永劫无间\.video-tools\venv\Scripts\python.exe` |
| FFmpeg / FFprobe | `C:\Project\永劫无间\.video-tools\LosslessCut\resources\ffmpeg.exe` / `ffprobe.exe` |
| 转写 | `TASK\captions\source_transcript.json` |
| 音频活动 | `TASK\analysis\audio_activity.json` |
| 预算脚本 | `C:\Project\永劫无间\scripts\check_image_budget.ps1` |
| 拼表脚本 | `TASK\cache\make_sheets.ps1` |

源盘 `E:\OBS`、`E:\PR导出` **只读**：永不写入、覆盖、改名。

## 2. 你这一路已经备好的取证材料（不需要再抽帧）

- `TASK\shots\segN\sheets\segN_sheet01.jpg … sheet06.jpg`：4x4 = 16 格联系表，每格 480x270，左上角烧了 `h:mm:ss`。一张联系表算 **1 张图**。
- `TASK\shots\segN\hd\tXXXX.0.jpg`：960x540 逐秒帧，文件名即源秒，左上角烧了 `h:mm:ss`。
- 两种材料的源时间完全一致（代理视频 offset = 0）。

需要更密的证据（同一秒多帧）时再抽，用：

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File 'C:\Project\永劫无间\123\21.864永劫无间 2026-09-30 02-57-13\cache\extract_all_frames.ps1' -TaskDir '<TASK>' -Input '<SRC>' -Fps 2.0 -Duration <秒> -Width 960 -Height 540
```

⚠ 该脚本是**全片单遍**抽取，输出到 `TASK\shots\all\`，会清空该目录。抽局部密帧请用
`TASK\cache\make_route_frames.ps1 -TaskDir <TASK> -SegStart A -SegEnd B -OutDir <TASK\shots\segN\verify\raw> -Source <SRC> -Fps 2 -Width 960 -Height 540`。
注意该脚本用 `-t`（时长）而不是 `-to`；`-ss` 配合 `-to` 会让 fps 滤镜重复吐同一帧，已修好，用 `-t` 即可。

## 3. 工作路径铁律（违反即打回）

- 唯一可写目录是 `TASK`。
- 禁止写项目根、`skills\`、`scripts\`、`docs\`、`assets\`、`E:\` 任何位置、`%TEMP%`。
- 扫描员只写两处：`TASK\shots\segN\`（自己的证据帧与拼表）和 `TASK\reports\segN_scan_report.md`。
- 禁止改 `TASK\timeline\` 下任何文件；禁止输出任何 MP4；禁止出 4K。

## 4. 看图预算（硬红线，违者会话作废）

- 单次请求累计图片 ≤ 50 张（含此前看过的全部）；单轮新增 ≤ 10 张。
- 看图前先跑：

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File 'C:\Project\永劫无间\scripts\check_image_budget.ps1' -ImageDir '<TASK>\shots\segN\sheets' -AlreadySeen <已看数>
```

- 典型节奏：第 1 轮 6 张联系表做全段普查 → 写中间结论到报告 → 第 2 轮 ≤10 张 960x540 核对候选首尾 → 写结论 → 第 3 轮如有存疑再补 ≤10 张。
- 一次要看超过 10 帧，先拼联系表（一张表算 1 张）：

```powershell
New-Item -ItemType Directory -Force -Path '<TASK>\shots\segN\verify'
# 把要看的帧 Copy-Item 进 <TASK>\shots\segN\verify\ （文件名保持 tXXXX.0.jpg 顺序）
powershell.exe -NoProfile -ExecutionPolicy Bypass -File '<TASK>\cache\make_sheets.ps1' -TaskDir '<TASK>' -ImageDir '<TASK>\shots\segN\verify' -SheetDir '<TASK>\shots\segN\verify\sheets' -SheetPrefix 'v1' -Columns 4 -Rows 4 -ThumbWidth 480 -ThumbHeight 270
```

- 每轮之间**先落盘中间结论**，再开下一轮。

## 5. 判定口径（唯一标准）

一场战斗 = 从第一次明确交战开始，到结果明确（击杀／团灭／敌人逃脱／玩家脱险／胜负已分）为止，外加短暂收束。

- 战斗中不切走。宁可留长，不漏战、不切断。
- 删：跑图、搜物资、等待、重复操作、长时间无事件。
- 留：拉扯、救援、追击、躲技能、重新接战 —— 同一场战斗的一部分。
- 边界不确定 → 保留并标 `needs_review`，不要自己截断。
- 自动标签（转写关键词、音频能量、场景变化）只是候选信号，**不能单独**当"这里有战斗"的证据。

**画面三信号是最终裁决**：敌方红血条 / 伤害数字 / 锁定线。定出候选 engage 后必须用 960x540 高清帧向前回查 3–8 秒，只看"红条出现的第一帧"，不要凭转写猜。

### 5.1 硬性反误判

- 全屏 UI（背包/选人/强化/魂玉栏占半屏以上）+ 无交战动作 → 不建战斗。
- 舔包/搜物资/换甲 + 转写只有闲聊、无报点呼救 → 不建战斗。
- 稀疏图看着像跑图但可能有战斗 → 必须 960x540 高清帧 + 连续战斗语音双重确认才可否定。1 张小图不足以定生死。
- 音频长活动段（≥20 秒）与"删除"初判矛盾 → 必须加密复核，不得直接删。
- 钩锁/御空/蓝盾类位移特效**不得单独**作为交战证据。
- 转写里"打"字在闲聊中高频（带打招/半夜打），不可按字命中建段。
- **玩家倒地 ≠ 这段没战斗**。倒地视角能看到队友与敌人的交战；队友赶路来救、按 F 救援、复活白光本身就是战斗；玩家重新站起来是明确结果帧。判"无战斗"必须逐段核验，不能用"玩家自己不能动"一票否决。
- 终局结算（段位屏/加分屏）若出现：从终局起保留「终局 → 结算屏」完整片段，不得切在"打完 → 黑屏/结算前"。

### 5.2 默认计时参数（画面证据优先于计时器）

| 参数 | 值 | 含义 |
|---|---|---|
| `lead_in` | 5 秒 | 交战前进入；前置里必须能看懂"为什么打起来" |
| `internal_gap` | 8 秒 | 小于此值的战术停顿先保留在同一场内 |
| `rejoin_window` | 12 秒 | 停顿后重接则合并为同一场（是合并充分条件，不是必要条件） |
| `outcome_hold` | 8 秒 | 最后一次动作后等结果明确 |
| `recovery_tail` | 5 秒 | 胜负/脱险后的短收束 |
| 尾部验证窗 | 13 秒 | 8+5；窗内任一秒出现战斗信号即重置时钟 |

**收束三步，步步要有帧**：
1. 击杀播报（≥1 秒可读的播报帧 + 明确结果语句）
2. 舔包/面板 UI 打开帧 + 关闭后首干净帧
3. 无敌人无伤害下跑路 ≥2 秒

缺任一步 = 收束不足，报告里写明缺哪步、建议延长几秒。

## 6. 转写查询（只读纯文本，不看图）

```powershell
& 'C:\Project\永劫无间\.video-tools\venv\Scripts\python.exe' '<TASK>\cache\show_transcript.py' '<TASK>\captions\source_transcript.json' all <起> <止>
```

转写是 faster-whisper large-v3 的输出，识别质量一般，只作候选信号。

## 7. 报告必填字段（缺任一字段判"未回"，打回重做）

写入 `TASK\reports\segN_scan_report.md`（UTF-8）：

1. 区间 `[seg_start, seg_end)`（源秒，1 位小数）
2. 结论：有战斗 / 无战斗 / needs_review
3. `episodes`：每场一段 —— id、source_start、source_end、engage_start、impact_points[]、outcome_time、event_types[]、confidence、boundary_reason
4. `deleted_inside`：段内要挖的子区间（start / end / category / 证据），没有写"无"
5. 边界证据：每个边界（头/尾）≥2 个**相互独立**的信号 + 证据帧绝对路径 + 所用联系表绝对路径
6. 收束三步逐帧（outcome_time + 播报帧 + 关 UI 帧 + 跑路帧）
7. 无战斗声明：判"无战斗"的每段写双重否定（高清帧显示什么 + 转写/音频显示什么）
8. 预算记录：每轮看了几张、累计几张、已看帧秒点清单
9. 末尾单独一行 `STATUS: DONE` 或 `STATUS: BLOCKED`（BLOCKED 写断点秒点与已落盘证据路径）

## 8. 事件类型词表

`parry` 振刀 / `kill` 击杀 / `multi_kill` 连杀 / `ultimate` 大招 / `team_save` 救援拆火 /
`escape` 脱险 / `revive` 复活 / `loot` 舔包（仅作边界说明，不单独建场） /
`downed` 倒地 / `boss` 打宝窟怪 / `settlement` 终局结算
