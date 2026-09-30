# spec: 段内挖洞（excluded_inside）在全链路丢失

状态：完成（2026-09-30）
触发：861 的 `qa_gate_v4.json` 报 `preview_duration FAIL`，实测 1090.5s vs 期望 1119.4s

## 问题

时间线 schema 里的 `excluded_inside`（战斗中途要挖掉的停顿/菜单/开面板）**在全项目代码里零实现**：

```
项目脚本命中 excluded_inside: 0 处
任务目录 Agent 手写脚本命中:    42 处（build_preview.py / make_adv_ctx_v*.py）
```

规格 `complete-combat-roughcut.md` §3.3 把「战斗内短暂停顿未挖空」列为交付前必查违规项，
schema 也给出该字段，但没有任何项目代码读它。于是：

1. Agent 只能在任务目录手写渲染脚本绕路（`cache\build_preview.py`）。
2. 项目自己的门禁 `qa_gate.py` 用 `Σ(source_end − source_start)` 算期望时长，
   **不扣洞**，于是把一个正确的渲染判成 FAIL。
3. 4K 链路 `read_episode_bounds.ps1` 只吐 `S=/E=` 对，**结构上无法表达洞**。

已使用段内挖洞的任务：849（5 段）/ 860（8 段）/ 861（6 段）——7 个任务里 3 个。
**这不是一次性意外，是每局都会复发的坑。**

## 唯一真源：节目时长公式

```
program_seconds = Σ_episodes [ (source_end − source_start)
                             − Σ_holes (hole.end − hole.start) ]
```

有效切片 = 每段按洞切成 N 个子区间（洞在**源时间轴**坐标上）。

实测校验（861 v4）：`1119.4 − 28.9 = 1090.5`，
与 `program_map_v4.json` 头部 `program_seconds_total = 1090.5`、
与渲染出的 `19-review-v4.mp4` 实测 1090.500000s **三者完全一致** → 渲染是对的，门禁是错的。

## 波及的 6 处实现

| 文件 | 行 | 现状 |
|---|---|---|
| `skills/…/scripts/qa_gate.py` | 89 | `program_sum` 不扣洞 → WARN |
| `skills/…/scripts/qa_gate.py` | 136 | `preview_duration` 不扣洞 → **FAIL（本次故障）** |
| `skills/…/scripts/validate_combat_timeline.py` | 146 | `program_total` 不扣洞 |
| `scripts/read_episode_bounds.ps1` | 97-103 | 只吐 S/E 对，无法表达洞 |
| `skills/…/scripts/export_edit_timeline.py` | 81,185 | program_end 不扣洞 |
| `skills/…/scripts/map_events_to_beats.py` | 54 | 不扣洞 |

`scripts/verify_master.sh` 本身算法正确（拿 `PROGRAM=` 去比），
只要上游 `read_episode_bounds.ps1` 修好就自动正确 —— 不需要改。

## 切片

- [x] **S1 新建共用几何模块** `skills/naraka-highlight-studio/scripts/episode_geometry.py`
      —— 公式与洞的合法性校验只写一遍，纯标准库。
- [x] **S2 修 `qa_gate.py`**：`program_sum` / `preview_duration` 改用共用模块；
      新增 `in_segment_holes` 门禁（洞越界/重叠/吞掉整段即 FAIL），
      这样坏洞会被当场抓住，而不是静默污染时长算术。
- [x] **S3 修 `validate_combat_timeline.py`**：`program_total` 扣洞 + 校验洞合法性。
- [x] **S4 修 `read_episode_bounds.ps1`**：按洞把每段展开成多个 `S=/E=` 子区间，
      `N=` 改为子区间总数，`PROGRAM=` 改为扣洞后的和。
      **`seg_render_master.sh` 一行不用改** —— 它只认 S/E 对逐段切再 concat，
      展开后它自动多切几段短的，正是 concat demuxer 想要的。
- [x] **S5 修 `export_edit_timeline.py` / `map_events_to_beats.py`**：program 时间轴跨洞压缩。
- [x] **S6 跨实现一致性测试** `scripts/test_insegment_holes.sh`：
      同一份 fixture 喂给 Python 与 PowerShell 两套实现，断言结果一致。
      规则写在散文里必然漂移，测试才锁得住。
- [x] **S7 端到端验证**：合成 fixture + 真渲一小段低清片，确认时长算术与实际产出吻合。
- [x] **S8 规格文档**：`complete-combat-roughcut.md` 写明公式 + 工具链已实现。

## 不做的事

- 不改 `seg_render_master.sh` / `verify_master.sh`（算法本来就对）。
- 不碰 861 的工作目录（用户明确要求），只读它的报告与时间线取证。
- 不给 4K 链路加 Python 依赖（那是有意去掉的，见 `read_episode_bounds.ps1` 的存在理由）。
