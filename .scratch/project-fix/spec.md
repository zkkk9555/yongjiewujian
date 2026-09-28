# Spec: 项目修正（路径漂移 + 策略对齐 + autopilot 脚手架）

> 历史注记（2026-09-24 反向迁移）：本 spec 是此前一次迁移的历史记录，当时方向为
> 无 `zcode` 旧根 → 有 `zcode` 新根；本次已反向迁回 `C:\Project\永劫无间`，下文保留当时原意，
> 其中“旧根/新根”指当时语境，不作为当前工作路径。

## Goal
把项目实际位置 `C:\Project\永劫无间` 与文档中的旧根路径对齐，消除 BGM 策略矛盾，补齐 autopilot 本地脚手架，修复质检脚本在 Git Bash 路径下的误判。

## Anchors
- `AGENTS.md :: 项目级工作规则`
- `docs/TOOLS.md :: 工具基线与固定入口`
- `config/production_dependencies.json :: schema naraka-highlight-production-dependencies/v1`
- `style_profiles/high_energy_v1.json :: music`
- `assets/README.md :: 素材库`
- `skills/naraka-highlight-studio/scripts/validate_delivery.py :: numbered_task_path`

## Non-goals
- 不改动 `.video-tools` 内虚拟环境的二进制与已安装包。
- 不重跑任务 1/任务 2 的转写与渲染。
- 不引入新依赖、新管线、外部服务。

## Slices（Lane B，3 个）
1. 路径漂移修正（历史归档，当时动作）：文档/JSON/任务脚本中的旧根写法 → 当时实际根（带 zcode 写法）；`.codex\skills` → `.zcode\skills`；Codex 称谓 → ZCode。
2. 策略对齐：`high_energy_v1.json` music 改为 `local_or_supplied_only` 且 `prefer_platform_native_when_publishing=false`；`assets/README.md` 去掉“按平台趋势重排”表述。
3. 脚手架与质检：补 `docs/agents/issue-tracker.md`、`docs/agents/domain.md`、`.scratch/`、`AGENTS.md` autopilot 说明；修 `validate_delivery.py` 的编号目录判断为跨平台实现。

## Checks（当时口径，已归档，不作为当前执行标准）
- 复查（当时）：可编辑区无当时旧根残留，无 `.codex\skills` 残留。
- 复查：`config/production_dependencies.json` 可解析且根路径为当时新路径。
- 验证：`validate_delivery.py` 对 `123/2.839...` 目录返回 pass；`check_video_environment.ps1` 只读检查通过（沙箱限制如实记录）。

## Glossary（当时语境，已归档）
- 项目根（当时）：`C:\Project\永劫无间`（实际工作区）。
- 旧根（当时）：`C:\Project\永劫无间`（文档历史残留，已替换）。
- autopilot：`mattpocock-skills` 全自动工程流程，只用于项目代码/文档修正，不替代视频剪辑流程。
