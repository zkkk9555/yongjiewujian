# 01: 状态文件与台账自动投影
**Type:** task
**What to build:** 一个任务目录里有一份机器可读的状态文件 `reports\delivery_state.json`，记录编排阶段、每一路的派工/回收时刻、重派次数、以及下一步该做什么。人类可读的台账 `dispatch_ledger.md` 由它**自动生成**，不再是人工填的第二份记录。中断后重开，新 Agent 读它就知道自己在哪、还差什么。

**Anchors:**
- `scripts/orchestrator_state.py` :: `load_state / save_state / record_dispatch / record_recycle / next_action`
- `scripts/export_ledger.py` :: `render_ledger`（状态 → 台账投影）
- `.scratch/orchestration-state-machine/spec.md :: Implementation Decisions`

**Blocked by:** None

**Status:** ready-for-agent

- [ ] 顶层 27 键齐全（不是 104；见 spec 的 Implementation Decisions）
- [ ] 每路 16 个字段，含 `dispatched_at` / `recycled_at` / `attempt` / `recycle_round`
- [ ] `attempt`（重派次数）与 `recycle_round`（回收轮次）是**两个独立字段**，不是二选一
- [ ] 台账表头新增「派工」「回收」「重派」三列，从状态文件投影
- [ ] 台账里**不再出现字面 `T0`**（861 的 29 行全填字面 T0 就是没落盘的证据）
- [ ] `reports\delivery_state.json` 不落在 `$Disposable`（preview/cache/shots/audio）里
- [ ] 状态文件损坏时能重建为「阶段=未知，路=未回收」，而不是让整个任务卡死
- [ ] 回归：`test_state_file.sh` 全绿

## Why this is first
没有它，看门狗（02）没有可读的输入，流式合成（03）没有可写的进度。
这是整个 slug 的地基。
