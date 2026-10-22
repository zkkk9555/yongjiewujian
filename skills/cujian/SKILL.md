---
name: cujian
description: "完整战斗粗剪 / 高质量粗剪 / 保留整场战斗 / 粗剪 / cujian / complete-combat roughcut: cut each fight from engagement through outcome while removing loot, travel, waiting, repetition and long no-event sections; by default deliver 720p review preview with sidecar SRT and frozen timeline, on grant (输出 4K 成片) rebuild cujian.mp4. Triggers on 完整战斗粗剪, 高质量粗剪, 保留整场战斗, 粗剪, cujian, complete-combat roughcut."
metadata:
  short-description: "完整战斗粗剪"
---

# Cujian 粗剪

## Outcome

只做一件事：**完整战斗粗剪**。把素材中的每一场有效战斗从接战完整截取到结果明确，
删掉战斗之间的舔包、跑图、等待、重复与长无事件段。产出 720p 审片预览 + 外挂 SRT +
冻结时间线，默认先交付审片预览等审片；用户说“输出 4K 成片”即授权在本链路按冻结线从源重渲 `cujian.mp4` 直渲 E 盘。要 BGM/特效包装才交给 `jingjian`。

触发词：完整战斗粗剪 / 高质量粗剪 / 保留整场战斗 / 粗剪 / cujian / complete-combat roughcut。

最小剪辑单位是 `combat_episode`（完整战斗事件），不是单个击杀、音量峰值、
场景变化或字幕关键词。开工前先读 [references/complete-combat-roughcut.md](references/complete-combat-roughcut.md)。

输入输出约定：

```text
Source: E:\OBS or E:\PR导出, read-only（只读，绝不写入/覆盖）
Output: C:\Project\永劫无间\123\<编号>.<素材文件名>
  preview/<号>-review-vN.mp4 + captions/<号>-review-vN.srt（外挂）+ timeline/combat_episodes_vN.json（冻结）
```

禁令：**禁 BGM、禁装饰特效、禁烧录**（MP4 内零字幕流、零烧录像素字，字幕只出外挂 SRT）。
风格名与用途见项目根 `style_profiles/complete_combat_roughcut_v1.json`（相对项目根，非 skill 内）
（`profile_name` 完整战斗粗剪 / `purpose` 先保证战斗完整性，再进行高燃成片包装）。

本目录是 `cujian` 的唯一正本（由归档前 `naraka-highlight-studio` 拆分沿袭；旧目录已归档，不再引用）。不要在用户级 skill 目录安装、复制或维护同名副本。

## Required workflow

1. **预检**：跑 `scripts\check_video_environment.ps1`（只读），以其输出为唯一环境真源；
   FFmpeg/FFprobe 路径运行时解析，不硬编码。不新建环境、不安装。
2. **取号**：**用分配器建目录，不要自己算编号**——
   `& 'C:\Project\永劫无间\scripts\new_task_dir.ps1' -Material '<素材文件名>'`
   （加锁 + 同一素材幂等复用 + 留 `123\index.tsv`；治「两个对话同时开 → 撞号」）。
   规则详见 `123\README.md`。
3. **batch manifest**：枚举去重输入素材，一个素材一个来源单元。
4. **完整战斗分集**：按 `references/complete-combat-roughcut.md` 三层结构
   把候选分组为完整战斗 episode，前后扩展验边界，同场战术停顿合并，
   战斗未结束不设边界；并行编排与角色分工按 `references/roughcut-launch.md §2`。
5. **入片状态曲线**（28 起为必做，别再漏）：跑 `scripts/squad_state.py` 生成
   `analysis/squad_state.json`，确认**每一场 `source_start` 上玩家与全部队友的血条/护甲都是满的**——
   不满就说明这一场漏了开战，头必须往前移。口径见 `references/complete-combat-roughcut.md §2.1.1`；
   `qa_gate.py` 会自动发现该文件并 FAIL，**不需要额外开关**。
6. **720p 预览**：按冻结候选时间线渲染 `preview/<号>-review-vN.mp4`，
   字幕映射为外挂 `captions/<号>-review-vN.srt`（禁烧录禁内嵌）。
7. **门禁**：`scripts/qa_gate.py` 任一 FAIL 即ブロック冻结；
   冻结门禁、自审与验收按 `references/roughcut-launch.md §3`（三分立命名、冻结门禁 2.0）。
8. **冻结**：时间线 JSON + validate pass + 现行预览三件套对齐后冻结，
   版本化命名（三件套 + 验收三分立 + 门禁检查表），冻结后交 `jingjian`。

判定标尺只用 `references/complete-combat-roughcut.md` 第二层；
`scripts/` 下 7 个 helper 只管可重复的机械检查，不代替看图判断与事件裁决：

- `scripts/validate_combat_timeline.py` — 战斗边界、排序、重叠、删除审计检查；
- `scripts/episode_geometry.py` — 节目时长几何（qa_gate / validate / 导出共用）；
- `scripts/orchestrator_state.py` — 编排状态；
- `scripts/watchdog.py` — 超时看门狗；
- `scripts/merge_partial.py` — partial 草稿合并；
- `scripts/qa_gate.py` — 全部门禁单一入口（任一 FAIL 阻止冻结）；
- `scripts/squad_state.py` — 入片状态（我方血条/护甲）逐秒曲线，供 `entry_state_full` 门禁读取。

## Delivery

**先预览后母版**：

① 默认先交付审片预览（720p MP4 + 外挂 SRT + 冻结时间线），等待用户审片反馈；
源素材只读，派生全在任务目录。

② 用户说"输出 4K 成片"即授权粗剪 4K 重建链：按冻结线从源素材重渲 4K60 VBR
（H.264 NVENC 目标约 18 Mbps、峰值约 28 Mbps、AAC 48 kHz，不从 720p 预览放大）
直渲 `E:\Cujian导出\<源文件名> cujian.mp4` → `scripts\verify_master.sh` 验收 →
`scripts\cleanup_after_master.ps1` 收尾。与精剪 `jingjian.mp4` 双轨各渲各的、互不覆盖；
精剪缺席时粗剪链不断链。
