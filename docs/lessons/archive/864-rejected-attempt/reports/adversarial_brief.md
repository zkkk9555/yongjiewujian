# 预览对抗审作业书（任务 21 / 素材 864）

你是「对抗审员」，与本版执行无关（没参与过修线、字幕、渲染、自审）。你**只看冻结预览的内容**，
按节目时间分段逐段看，找四类低级错误。标尺唯一来源是 `reports\scanner_brief_common.md` 第 5 节，不发明新标尺。
风格 / BGM / 字幕字体 / 特效喜好一律不报（本阶段不出 BGM、不出特效）。

## 绝对路径

| 用途 | 路径 |
|---|---|
| 任务目录 TASK | `C:\Project\永劫无间\123\21.864永劫无间 2026-09-30 02-57-13` |
| 冻结预览 | `TASK\preview\864-review-v<N>.mp4`（只读） |
| 时间线 | `TASK\timeline\combat_episodes_v<N>.json` |
| 节目映射 | `TASK\timeline\program_map_v<N>.json`（含 `cuts[]` 节目↔源对照） |
| 你的报告 | `TASK\reports\adversarial_864_v<N>_segK.md` |

## 工具

- FFmpeg：`C:\Project\永劫无间\.video-tools\LosslessCut\resources\ffmpeg.exe`
- Python：`C:\Project\永劫无间\.video-tools\venv\Scripts\python.exe`
- 拼表脚本：`TASK\cache\make_sheets.ps1`
- 禁止新建环境、禁止安装、禁止出 4K、禁止改 `timeline\`、禁止重渲预览、禁止补抽帧定新边界。

## 切分

按**节目时间**把冻结预览切成 60–90 秒/路，段数 `ceil(节目总秒/75)`，段间 5 秒重叠带：
`adv1 [0,90)`、`adv2 [85,175)`…… 节目秒保留 1 位小数。

## 找什么（只报这四类）

1. **战斗中断** —— 节目里某场战斗在结果明确之前就被切走。
2. **漏战** —— 源素材里有完整一场战斗，节目里没有。
3. **跑图残留** —— 节目里出现搜物资 / 跑图 / 等待 / 全屏 UI 的长段。
4. **因果链断裂** —— 玩家状态突变（获得神兽之力 / 变灵魂 / 阵亡 / 复活 / 进出回阳境 / 倒地）缺少来源战斗；或"倒地·等待救援"直接切到"站立奔跑"这类游戏内状态矛盾。

## 怎么取证

- 从**预览**（不是源片）按节目秒抽帧，1fps 或 2fps，960x540，拼联系表（一张表算 1 张图）。
- 抽帧示例（单次按段抽，不要整片）：
  `ffmpeg -y -v error -i <preview> -ss <节目起> -t <时长> -vf "fps=1,scale=960:540,drawtext=fontfile='C\:/Windows/Fonts/arialbd.ttf':text='%{pts\:hms}':x=8:y=6:fontsize=48:fontcolor=yellow:box=1:boxcolor=black@0.6" -q:v 3 <你的输出目录>\t%05d.jpg`
  ⚠ 用 `-ss` 放在 `-i` **之前**并配 `-t`（时长），**不要用 `-to`**，否则 fps 滤镜会重复吐同一帧。
- 节目秒 → 源秒换算：`S = episode.source_start + (P − episode.program_start)`（`program_map` 里每个 cut 也直接给了 `source_start`/`program_start`，以 cut 映射为准更稳）。

## 看图预算

单次请求累计 ≤ 50 张，单轮新增 ≤ 10 张。看前先跑
`powershell.exe -NoProfile -ExecutionPolicy Bypass -File 'C:\Project\永劫无间\scripts\check_image_budget.ps1' -ImageDir <你的帧目录> -AlreadySeen <已看数>`。
超过 10 帧先拼联系表。

## 报告必填六节

写入 `TASK\reports\adversarial_864_v<N>_segK.md`：

1. **区间**：节目秒 `[P0, P1)`，并写清对应源秒范围
2. **已看证明**：抽帧规格 + 帧数 + 联系表绝对路径 + 预算记录（无问题的结论也必须附）
3. **问题清单**：每条五项 —— 类别 + `P→S` + 换算式 + 画面描述 + 证据路径，`P` 精确到 0.1 秒
4. **段缝互证**：5 秒重叠带两侧结论是否一致
5. **不报清单**：看到但按标尺不构成问题的（写清为什么不报）
6. 末尾单独一行 `STATUS: DONE` 或 `STATUS: BLOCKED`

**禁止**：改 `timeline/`、重渲预览、补抽帧定新边界、开新问题分支。
对抗审发现的战斗中断/漏战默认按大修处理。
