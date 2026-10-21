# 02: 经验收纳（规则进规格 + POOL 重整）

**What to build:** 把 873–890 这十局的可复用规则写进下一局真会读到的地方
（`skills/cujian/references/`、`docs/TROUBLESHOOTING.md`、`skills/jingjian/references/deliverables-and-qa.md`），
并把 `docs/lessons/POOL.md` 重整成机器可信的样子：编号不重复、已吸收的行不在「待升级」标题下、
每条已吸收行都有去向、待升级候选归零。补齐 854/858/860 三个任务目录缺失的 `workflow_notes`，
并把经验命名门禁从「必须相等」放宽到「前缀式」，只改真错的那 2 个文件名。

**Anchors:**
- `docs/lessons/POOL.md :: ## 待升级`
- `scripts/collect_lessons.ps1 :: Normalize-LessonText`
- `scripts/check_task_hygiene.ps1 :: §6 经验落盘`
- `skills/cujian/references/complete-combat-roughcut.md :: §2.1.1 入片状态必须满状态`
- `skills/cujian/references/roughcut-launch.md :: §2.1 角色分工`
- `docs/TROUBLESHOOTING.md :: # 已知未修的工具缺陷`

**Blocked by:** 01（体检结论决定哪些是缺口）

**Status:** ready-for-agent

- [ ] POOL 结构重整：去重复表头、去重复 L-037、把 L-036–L-040 移进已吸收区
- [ ] 每个任务目录补一行「本局经验去向摘要」（来源列 = 任务目录全名），机器闭环
- [ ] 可复用规则写进 4 个目标文件，每条带来源与实证
- [ ] 补 854 / 858 / 860 的 workflow_notes（按任务目录号命名）
- [ ] 命名门禁放宽到前缀式；849→13、863→20 两个文件改名
- [ ] 回归：`collect_lessons.ps1` 待升级 = 0；25 个目录跑 `check_task_hygiene.ps1` 全 PASS

## Answer (decision tickets only)
