# 05: 字幕与映射门禁补齐

**What to build:** `validate_delivery.py` 补字幕哈希互斥（烧录 MP4 同目录同名 SRT 为 0、外挂条数对 stats、跨 episode 横跨为 0，重映射后必重算）；`validate_combat_timeline.py` 补 Proxy-Source 映射校验口径（分段求和差 ≤0.01s、预览时长差 ≤±0.3s、分段复用须区间一字未变 + ffprobe 对时长）。两处均为小改，不改 schema 主版本。
**Anchors:** `skills/naraka-highlight-studio/scripts/validate_delivery.py :: main`
**Anchors:** `skills/naraka-highlight-studio/scripts/validate_combat_timeline.py :: main`
**Anchors:** `docs/WORKFLOW.md :: 阶段 2：音频和字幕`
**Blocked by:** 01-qa-gate-script.md（门禁口径以 qa_gate 为准，本票只补两脚本的检查项）
**Status:** completed
- [x] 字幕互斥三阈值可执行（同名 0 / 条数对 stats / 横跨 0）
- [x] 映射校验三阈值可执行（求和 0.01s / 时长 ±0.3s / 复用三条件）
- [x] fixture 与历史任务目录回归通过

## Verify
PASS: implemented and smoke-tested on 2026-09-11. See NOTES.md for evidence.
