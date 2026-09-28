# Spec: 832完整战斗粗剪跑通（找问题→再优化工作流）

## Goal
对 `E:\PR导出\832永劫无间 2026-06-29 00-34-53.mp4` 跑通 `complete_combat_roughcut` 一遍：
建编号任务目录 → 探测 → 音频/转写/场景/活动分析 → 候选与时间线 → 低清预览 → 解码检查，
输出问题清单，为下一步工作流优化提供证据。不输出4K最终版。

## Anchors
- `skills/naraka-highlight-studio/SKILL.md :: complete_combat_roughcut`
- `skills/naraka-highlight-studio/references/complete-combat-roughcut.md :: 硬性规则`
- `style_profiles/complete_combat_roughcut_v1.json :: selection/review`
- `scripts/check_video_environment.ps1 :: 只读检查`

## Non-goals
- 不加 BGM、不烧录对话字幕、不堆装饰特效。
- 不输出4K最终成片；不改原素材；不装新工具/新依赖。

## Slices（Lane B，3 个）
1. 探测+建目录：ffprobe源探测→`123/<编号>.832...`任务目录→batch manifest→环境只读检查。
2. 分析+候选：16k音频提取→faster-whisper GPU转写→PySceneDetect→Auto-Editor→缩略图/候选→combat_episodes.json+源时间线+删除区间审计。
3. 预览+质检：720p预览→完整解码检查→validate脚本→问题清单（卡点/报错/需优化处）。

## Checks
- 预览从头到尾完整解码，无黑帧/冻结/音画漂移。
- 每段从交战开始到结果明确；不确定的标 needs_review。
- 原素材只读；派生文件全在任务目录。

## Glossary
- combat_episode：从第一次明确交战到结果明确+短收束的完整战斗。
- needs_review：边界不确定、保留等审片的候选。
