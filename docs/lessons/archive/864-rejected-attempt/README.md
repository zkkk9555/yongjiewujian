# 归档：864 被否决的那一次尝试

这是任务 21 / 素材 864 在 v1–v6 期间产出的**证据副本**，2026-10-01 归档。

## 为什么归档而不是直接删掉

`AGENTS.md §7.1` 规定：成片落 E 盘后收尾清理只删 `preview\` `cache\` `shots\` `audio\`，
**保留 `timeline\` `reports\` `analysis\` `captions\`** —— 因为这些是
「这段为什么留、那段为什么删、谁核过」的**唯一依据**。

864 的 v6 被用户判定仍有问题、要整局重剪，所以它永远不会有成片，
`cleanup_after_master.ps1` 的交付闸门（必须在 `E:\Cujian导出\` 找到正本）也就永远不会放行。
直接整目录删掉会把这 157 个文件、4.83 MB 的依据一起带走。

所以：**先把证据复制到这里，再删任务目录。** 归档与删除都做了逐文件核对（0 个不符）。

## 里面有什么

| 目录 | 文件数 | 内容 |
|---|---|---|
| `reports\` | 120 | 自审、对抗审、验收、合并裁决、改动单、门禁 JSON |
| `timeline\` | 21 | `combat_episodes_v1..v6` + `program_map_v1..v6` |
| `analysis\` | 3 | 源探测、场景检测、音频活动 |
| `captions\` | 13 | v1–v6 的外挂字幕与统计 |

**没有** `preview\` `cache\` `shots\` `audio\` —— 那 13.35 GB 是可再生重量，已随目录删除。

## 已提炼出的结论在哪

不必读这一大堆。结论已经提炼进工作流：

- 用户原始反馈原件 → `docs/lessons/2026-10-01_864-审片反馈与教训.md`
- v6 改动单（用户认可的推导）→ `docs/lessons/2026-10-01_864-v6改动单.md`
- 规则与教训 → `docs/lessons/POOL.md`（L-001 ~ L-040）
- 规则落点 → `skills/naraka-highlight-studio/references/complete-combat-roughcut.md` §2.2.1 / §2.2.2

本目录只是**原始依据的存档**，供将来需要复核某条裁决时查阅。

## ⚠ 这些文件里有 U+FFFD 替换字符，是原始状态，不要"修"

以下 8 个文件在归档时即含 `U+FFFD`（编码损坏留下的替换字符）：

```
reports/adjudicate_b.md              (6 处)
reports/adjudicate_b_working.md      (6 处)
reports/adjudicator_brief.md         (3 处)
reports/change_order_v6.md           (3 处)
reports/dispatch_ledger.md           (3 处)
reports/issue_list_v1.md             (3 处)
reports/merge_decision_v2.md         (8 处)
reports/seg11_scan_report.md         (3 处)
```

**这是 864 那次剪辑当时就有的损坏，不是归档引入的。**

保持原样是有意的：这一目录是**证据副本**，改字就是改证据。
已另行抢救的 `docs/lessons/2026-10-01_864-v6改动单.md` 是**修过字的工作副本**，
两份用途不同，不要互相覆盖。