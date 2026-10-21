---
name: jingjian
description: "精剪 Finish-stage skill: 把已冻结粗剪做成高燃 highlight 成片 —— BGM 卡点、特效、混音、4K交付. Trigger on 精剪/高燃/卡点/特效/混音/4K交付/jingjian/highlight/finish. 唯一输入为已冻结粗剪 timeline/combat_episodes_vN.json + 审片结论；禁挖洞/禁切断/禁回源重选，要改返工回 cujian."
---

# Jingjian 精剪

## 输入契约（唯一合法输入）

- 已冻结粗剪时间线 `timeline/combat_episodes_vN.json`（冻结三件套同 N：`program_map_vN.json` + `validate_vN.json`）+ 审片结论（accept / reverify）。
- 本 skill 不做粗剪选片：**禁挖洞**（不动 `excluded_inside`）、**禁切断**（不动 episode 边界）、**禁回源重选**（不从源素材另选片段）。
- 任何边界 / 选段改动需求 → 返工回 cujian（粗剪），冻结新版后再进精剪。

（冻结语义见 skills/cujian/references/complete-combat-roughcut.md:27（只读引用）：粗剪审片版先验证选片和连续性，「确认后再进入高质量成片阶段」。）

## Modes

- `high_energy`（默认）：BGM 集锦 45–90s，振刀 / 反打 / 击杀 / 极限 / 拆火 / 大招高光，事件包节奏 + 卡点 + 特效 + 混音。风格基线见项目根 `style_profiles/high_energy_v1.json`（相对项目根，非 skill 内）（高燃卡点：3840×2160 60fps；selection 事件表 parry/counter/combo/clutch/team_save/ultimate/kill/multi_kill；music 仅本地或自供 + duck；effects 中强度、保可读）。
- `story`：cinematic / team_save / teaching / comedy 收敛为本 mode 下的选项（长语境克制剪辑 / 完整救援线 / 解说字幕 / 轻快节奏），不另设 mode。

只读源 skills/cujian 已冻结语义 + 本 skill Modes 定义；high_energy 定义见本 skill Modes 节。

## Workflow

1. 读冻结线：载入 `combat_episodes_vN.json` + 审片结论，核对冻结三件套同 N。字段复用粗剪定义（`source_start` / `source_end` 为渲染依据；`engage_start`、`impact_points`、`outcome_time` 用于解释、质检、卡点和后续特效 —— skills/cujian/references/complete-combat-roughcut.md:360（只读引用），不复制全文）。
2. 事件包：将冻结 episodes 转为 event packs（lead-in / key action / result / recovery；`impact` 为卡点与特效锚点）。
3. Beat map：`scripts/analyze_bgm.py` 分析本地 / 自供 BGM → `scripts/map_events_to_beats.py` 落事件包到 beat map（事件绑乐段与重音，不机械逐拍切）。
4. 特效配方：按 `references/event-effect-recipes.md` 施加语义配方（慢放 / 定格 / 闪 / 推 / 震 / 字 / SFX），保持玩法可读；对白字幕默认 off，impact 短标签 selective。
5. 4K 母版（需“输出 4K 成片”授权，与 auto_chain 红线一致）：从源素材重渲 4K60 VBR（H.264 NVENC、目标约 18 Mbps、峰值约 28 Mbps、AAC 48 kHz），直渲交付目录为 `E:\Cujian导出\<源文件名> jingjian.mp4`（收尾规则见自家 `references/deliverables-and-qa.md`，双轨口径见本文件 Delivery rule）。
6. 验收：`scripts/validate_delivery.py` 跑交付检查。

## BGM rule

BGM 规则（由归档前拆分沿袭）：只用本地 / 用户自供音频文件；不注册 API、不爬榜单、不下无授权平台曲；无可用文件则用原声混音推进，不造需要二次手工的 cue。

## Revision rule

修订规则（由归档前拆分沿袭）：用户反馈沉淀为版本化风格快照，不覆盖原 profile，不从单次例外推全局规则；一次性特效留本任务本地。

## Delivery rule

- 默认交付：横屏 4K60 VBR 母版 + 审片预览（VBR 参数见自家 `references/deliverables-and-qa.md`）。母版干净：无烧录、无内嵌字幕流；字幕只以外挂 SRT 交付。
- **双轨归属**：粗剪冻结时间线重建 → `E:\Cujian导出\<源文件名> cujian.mp4`（由 cujian 产出）；本 skill 高燃包装 → `E:\Cujian导出\<源文件名> jingjian.mp4`。直渲交付目录，不进任务目录 `deliverables\`；E 盘验收通过后自动跑 `cleanup_after_master.ps1`（交付闸门：E 盘无非空正本则 BLOCKED，一个字节不删）。

## Environment rule

环境规则（由归档前拆分沿袭）：项目自带 > 系统安装；禁依赖临时 / 缓存 / runtime 目录；FFmpeg 路径运行时解析（`scripts/resolve_ffmpeg.ps1` + `check_video_environment.ps1`），不硬编码。

## 跨 skill 依赖（只读，不改逻辑）

- `scripts/map_events_to_beats.py` 与 `scripts/export_edit_timeline.py` 顶部的 `from episode_geometry import ...` 为从 cujian 原样复制；在本目录无 `episode_geometry.py` 时跨路径断链，原样保留，不断链改法，不改逻辑。几何定义以 cujian 的 `episode_geometry.py` 为准。
