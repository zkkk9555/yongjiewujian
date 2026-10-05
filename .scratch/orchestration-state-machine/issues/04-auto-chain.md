# 04: 授权后链路自跑（不是自动开渲）
**Type:** task
**What to build:** 授权仍然由用户给（一句「输出 4K 成片」）。但**一旦检测到授权已给，链路自己跑完**（渲 4K → 验收 → 收尾清理），不再停在那儿等下一句。

**Anchors:**
- `scripts/auto_chain.ps1` :: `Wait-ForAuthorizationThenRun`
- `scripts/cleanup_after_master.ps1`（链路终点，复用不改）
- `scripts/verify_master.sh`（验收，复用不改）
- `.scratch/orchestration-state-machine/spec.md :: Implementation Decisions`

**Blocked by:** 01

**Status:** needs-triage

- [ ] **未授权时一个字节都不动**（这是硬红线）
- [ ] 检测到授权后，链路无人干预跑完，实测 16–25 分钟
- [ ] 成片**只**落 `E:\Cujian导出\<源文件名> cujian.mp4`，绝不覆盖已有文件
- [ ] 链路终点仍是 `cleanup_after_master.ps1` 的交付闸门（找不到成片就 `[BLOCKED]` 拒删）
- [ ] 链路中任一步失败 → `WITHHELD` + 台账点名，**不许静默继续**
- [ ] 回归：`test_auto_chain.sh` 全绿

## Why this is NOT auto-render
实测（2026-10-06，30 秒素材，跑两遍取第二次）：

| | 30 秒片段 | 换算 13 分钟成片 |
|---|---|---|
| 720p 预览 | 25.70 s | 约 11 分钟 |
| 4K 母版 | 108.65 s | **约 47 分钟** |

**慢 4.2 倍。** 每渲一版 4K 要 47 分钟，而**人看到才会想到要改**。
自动开渲等于每个版本白烧 47 分钟，一次返工就吃回省下的 6.57 小时。

所以本票只治「授权之后那段发呆」：实测 6.57 小时里 **≥85% 是链路没启动**
（无编排脚本、无看门狗、无状态文件），真正的 4K 编码只要 12–34 分钟。

用户的原话（准）：**「每渲一次 4K 要 47 分钟，改一点就得重渲，我不愿意见到就自动出片。」**

## The incident this fixes
「冻结完成 → 4K 真正开渲」空等 **6.57 小时**，门禁全绿、机器空闲。
