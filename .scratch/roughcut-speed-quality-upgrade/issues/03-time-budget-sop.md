# 03: 可信时间预算 SOP

**What to build:** 新增 `skills/naraka-highlight-studio/references/time-budget.md`：写入可信时间表（有缓存 30 分钟快览 / 无缓存 60 分钟快览 + 90-120 分钟可审预览 + 终渲另计）、全局时钟熔断（快览超 10 分钟、预览超 30 分钟即降级）、cache-miss 早退（缺模型/缺显存/NVENC 占满记缺口出降级清单，不重试不安装）。并在 `roughcut-launch.md` 与 `SKILL.md` 各加一行索引，不展开。
**Anchors:** `skills/naraka-highlight-studio/SKILL.md :: Required workflow`
**Anchors:** `skills/naraka-highlight-studio/references/roughcut-launch.md :: 并行编排`
**Blocked by:** None
**Status:** completed
- [x] time-budget.md 落盘，含时间表 + 熔断 + 早退三节
- [x] roughcut-launch.md 与 SKILL.md 各有一行索引指向新文件
- [x] 快览明确标注不可冻结、不可送审

## Verify
PASS: implemented and smoke-tested on 2026-09-11. See NOTES.md for evidence.
