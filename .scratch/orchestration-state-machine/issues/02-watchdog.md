# 02: 看门狗与超时换路
**Type:** task
**What to build:** 一个看门狗，读状态文件，发现「某一路早就该回来了但一直没回来」，把它标为卡死并重派。人不盯着也不会丢一路。超时判据必须用**可测量**的量，不许「感觉很久」。

**Anchors:**
- `scripts/watchdog.py` :: `should_fire / fire_and_redispatch`
- `scripts/orchestrator_state.py :: record_recycle`（看门狗写回重派次数）
- `.scratch/orchestration-state-machine/spec.md :: Implementation Decisions`

**Blocked by:** 01

**Status:** needs-triage

- [ ] 判据 = `clamp(3 × 本波已回收路时延 p50, 60, 240) min`
- [ ] **必须本波 ≥50% 回收才允许开火**，否则第一波慢路会被误判
- [ ] 回测 861 的真实时延：应在 **19:35** 换路（实际拖到次日 03:05，命中 **7.5 h**）
- [ ] 回测 864 的真实时延：**零误杀**
- [ ] 重派次数上限 `attempt ≤ 2`（09 号裁决：与回收轮次 3 是两个字段）
- [ ] 达到重派上限时**不静默放弃**，转 `WITHHELD` 并在台账点名
- [ ] 看门狗本体崩溃**不影响**正在跑的路（它只是读文件）
- [ ] 回归：`test_watchdog.sh` 全绿

## The incident this fixes
861 派 29 路，3 路被服务端重启吞掉，**无人发现、无人换路、无人降级**，
干等 **7.5 小时**。台账缺「回收时间」列，所以触发器算不出来 —— 01 票修的就是这个。
