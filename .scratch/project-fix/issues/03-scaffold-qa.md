# 03 — 脚手架与质检脚本

Status: resolved
Anchors: `skills/naraka-highlight-studio/scripts/validate_delivery.py :: numbered_task_path`, `AGENTS.md :: Agent skills`

## Task
补 autopilot 本地脚手架；修 `validate_delivery.py` 在 Git Bash 正斜杠路径下的误判。

## Answer
新增 `docs/agents/issue-tracker.md`、`docs/agents/domain.md`（取自 setup 模板本地版）、`.scratch/`、`AGENTS.md` 的 Agent skills + Autopilot 说明。`validate_delivery.py` 改为按 `parent.name == "123" 且目录名前缀为数字` 判断，不再依赖反斜杠字面量。

## Verify
待跑：`validate_delivery.py` 对任务 2 目录 smoke；`check_video_environment.ps1` 只读检查。
