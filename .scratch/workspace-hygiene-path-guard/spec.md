# Spec: 工作路径约束与即时清理（保C盘简洁）

## Goal
用户原话两条：工作路径不正确，根目录与乱码路径产出零散文件，真正的工作路径只能是 `123\<编号>.<素材文件名>` 内；工作时不及时删除无用文件，大体积视频快速占满 C 盘。目标是路径护栏 + 即时清理 + 只留最新，让工作区长期保持简洁。

## Anchors
- `AGENTS.md :: 项目级工作规则`
- `docs/WORKFLOW.md :: 标准视频剪辑工作流`
- `skills/naraka-highlight-studio/SKILL.md :: Required workflow`
- `skills/naraka-highlight-studio/references/roughcut-launch.md :: 并行编排`
- `skills/naraka-highlight-studio/references/deliverables-and-qa.md :: Versioned naming, lifecycle, and cleanup`
- `skills/naraka-highlight-studio/scripts/qa_gate.py :: main`
- `scripts/check_video_environment.ps1 :: Write-Check`

## Non-goals
- 不碰 `E:\OBS` / `E:\PR导出` 源片，不改 `.video-tools` 环境，不重跑历史任务转写渲染。
- 不删除仍被冻结版引用的证据（联系表、审计点名的边界高清帧、三分立审计）。
- `$T`、星号目录、乱码兄弟目录等0文件空壳只删空目录本体，不碰任何有文件的目录。

## Slices（3 票，顺序执行）
1. `01-path-guard-docs`：工作路径铁律落文档（唯一工作目录 + 禁止落盘清单 + 派工 prompt 必备行 + 发现即打回）。
2. `02-realtime-cleanup`：即时清理规则落文档（旧版预览单保留、散帧段冻结即清、可再生音频成片即删、每次删除记 cleanup_log）+ `qa_gate.py` 增 `workspace_hygiene` 门（根目录零散产物即 WARN/FAIL）。
3. `03-cleanup-regress`：回归（fixture + py_compile + grep）+ 本次经用户确认的孤儿与空壳清理 + 任务目录零散复查 + NOTES + 删 marker。

## Checks
- 复查：`roughcut-launch.md` 派工 prompt 必备行含工作路径禁令；`deliverables-and-qa.md` 生命周期含即时清理节。
- 验证：fixture 仍 PASS；py_compile 全绿；根目录 `f_*.jpg` 与空壳目录已处置（用户已确认删除）。
- 验证：`123/` 下任务目录mtime除本次清理记 log 外无新增写入。

## Glossary
- 唯一工作目录：`123\<编号>.<素材文件名>`，全部派生文件只许落此。
- 孤儿散图：根目录 `f_*.jpg` 85 张，经哈希比对与引用搜索确认无报告引用。
- 空壳目录：0文件的 `$T`、星号重复目录、乱码兄弟目录（只删空壳，不碰有文件者）。
- 即时清理：vN+1 可用即删 vN-1 及更早旧预览；段冻结且联系表覆盖即清散帧；`audio_16k.wav` 成片后即删。

## Notes
- Skills called: ask-matt T0 earlier rounds (generic doc, no verdict; routed via prelane Lane B).
- 盘点证据：根 `f_*.jpg` 85 张（9-11 23:15）；`$T`/星号/乱码兄弟目录 find -type f 均为 0；11.844任务 3.98GB（preview 2.2GB 4版旧预览 + deliverables 1.52GB + shots 179MB + audio 70MB）；C盘已用 256GB、剩余 67GB。
