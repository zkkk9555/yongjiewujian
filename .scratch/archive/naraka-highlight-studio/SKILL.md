---
name: naraka-highlight-studio
description: "Create high-quality Naraka: Bladepoint gameplay videos from local match recordings. Includes a complete-combat roughcut mode that preserves each fight from engagement through outcome while removing loot, travel, waiting, repetition, and long no-event sections; also supports optional BGM, captions, effects, audio mixing, and final delivery. Use for Naraka montage or combat-roughcut production; keep general-purpose video edits on the project’s base video skills."
metadata:
  short-description: "批量制作《永劫无间》高燃成片"
---

# Naraka Highlight Studio（旧版待退役，仅路由）

本 skill 已拆分为两个新 skill，**正文不再维护，只做重定向**。
references/ 与 scripts/ 原样保留供只读引用，不再新增规则。

## 路由表

| 用户要什么 | 去哪 |
|---|---|
| 完整战斗 / 粗剪（完整战斗粗剪 / 高质量粗剪 / 保留整场战斗 / cujian） | `skills/cujian`（skill: cujian） |
| BGM / 卡点 / 特效 / 混音 / 4K 成片（精剪 / 高燃 / jingjian / highlight / finish） | `skills/jingjian`（skill: jingjian） |

流程：cujian 冻结（720p 预览 + 外挂 SRT + 冻结时间线）→ 交 jingjian 做精剪与 4K 母版。

## 双链

- 粗剪：[skills/cujian/SKILL.md](../cujian/SKILL.md)
- 精剪：[skills/jingjian/SKILL.md](../jingjian/SKILL.md)
