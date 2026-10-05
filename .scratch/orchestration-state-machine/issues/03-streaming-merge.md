# 03: 流式合成（回来一路合一路）
**Type:** task
**What to build:** 回收一路就合并一路，立刻产出一版草稿时间线，不再等所有路回来。861 那次 26/29 路已回、盘上没成品的 9.3 小时等待消失。

**Anchors:**
- `scripts/merge_partial.py` :: `merge_available`
- `skills/naraka-highlight-studio/references/roughcut-launch.md`（§2.3 / §2.6 / §2.8 三处 partial 禁令的处置说明）
- `.scratch/orchestration-state-machine/spec.md :: Implementation Decisions`

**Blocked by:** 01

**Status:** needs-triage

- [ ] 回收 1/14 路即产出 PARTIAL 草稿，**不等待**
- [ ] 全回收后合并结果与「一次性合并」**逐字段相同**（否则就是 bug，不是优化）
- [ ] PARTIAL 草稿带机器可读标记，`qa_gate.py` / `read_episode_bounds.ps1` **按名与字段拒收**
- [ ] PARTIAL 预览放独立子目录，**绝不进对话与交付清单**
- [ ] 不修改 `§2.3` / `§2.6` / `§2.8` 的「partial 永不转正」禁令本身 —— 用拒收机制代替放宽禁令
- [ ] 回归：`test_streaming_merge.sh` 全绿

## Why reject instead of relax
09 号裁决：partial 不该「转正」（转正条件一旦可判定就退化成「永不转正」），
应加**机器化的拒收**让半成品进不了交付路径。

用户已明确：**只要经过验收的粗剪预览片，不要半成品。**
所以这是「早给你看，但绝不冒充成品」，不是「放宽标准」。

## The incident this fixes
岛式合并逃生阀其实**写在规则里了**（§2.3 / §2.8），但被自己三处「partial 永不转正、
渲染员禁认 partial」废掉，四局一次没用过（partial 文件数 = 0）。
861 因此干等 9.3 小时。
