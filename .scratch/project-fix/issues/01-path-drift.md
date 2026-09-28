# 01 — 路径漂移修正

> 历史注记（2026-09-24 反向迁移）：本 issue 是此前一次迁移的历史记录，当时方向与本次相反；本次已统一迁回当前工作根，下文保留当时原意，其中的“旧根/实际根”指当时语境。

Status: resolved
Anchors: `AGENTS.md :: 项目级工作规则`, `docs/TOOLS.md :: 主工具环境`

## Task
把可编辑文档/JSON/任务脚本中的旧根 `C:\Project\永劫无间` 批量替换为实际根 `C:\Project\永劫无间`；`.codex\skills` → `.zcode\skills`；Codex 称谓 → ZCode。

## Answer
已用项目 venv Python 批量替换 11 文件 + 2 文件二次修复（JSON 转义与 skill 路径），`config/production_dependencies.json` 用 JSON 解析方式单独修正。`.video-tools` 内虚拟环境文件与任务历史 log 不动（前者是环境二进制，后者是历史记录）。

## Verify
复查命令：`grep -rF 'C:\Project' --include md/json/ps1/py` 仅剩新路径；`grep -rF '.codex\skills'` 为空。
