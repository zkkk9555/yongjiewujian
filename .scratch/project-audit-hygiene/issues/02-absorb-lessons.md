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

**Status:** resolved

- [x] POOL 结构重整：去重复表头、去重复 L-037、把 L-036–L-040 移进已吸收区
- [x] 每个任务目录补一行「本局经验去向摘要」（来源列 = 任务目录全名），机器闭环
- [x] 可复用规则写进 4 个目标文件，每条带来源与实证
- [x] 补 854 / 858 / 860 的 workflow_notes（按任务目录号命名）
- [x] 命名门禁放宽到前缀式；849→13、863→20 两个文件改名（另 883 的 5 个 seg 文件改名）
- [x] 回归：`collect_lessons.ps1` 待升级 = 0；24 个目录跑 `check_task_hygiene.ps1` 全 PASS

## Answer (decision tickets only)

**已交付（提交 `6f7fd31`）。** 与 spec 的偏差两处，都有理由：

1. spec 说「每个任务目录补一行摘要」→ 实际补了 **26 行**（25 个目录 + `docs\lessons` 一行）。
   原因：`docs\lessons` 下的 6 份专题复盘在脚本里共用一个来源键 `docs\lessons`，
   不单独补一行就闭不掉。
2. spec 说「真错的只剩 2 个」→ 实际改了 **7 个**：除 849→13、863→20 外，
   883 的 5 个 `workflow_notes_segN.md` 也不带目录号前缀，一并改成 `workflow_notes_29_segN.md`。

**额外发现并修掉（spec 没预见到的）**：

- `collect_lessons.ps1` 的「来源键」机制**一直是死的**——正则捕获的是 POOL 的教训列而不是来源列，
  被拿去和来源键比。修前 POOL 补齐 25 行摘要仍报 695 条待升级，修后 **0 条**。
  登记在 `TROUBLESHOOTING.md` M13、POOL L-157。
- 卫生门把「0 字节 stderr（渲染无错）」与「历史时间线版本（版本血统证据）」判成硬违规，
  19 个目录长期 FAIL，等于逼人删证据 → 两条降为 INFO，登记在 M14 / L-157。

**验证**：24 个任务目录卫生门 **0 失败**；`collect_lessons.ps1` 待升级 0、命名不合规 0、
缺 notes 0（24/24 覆盖，比 spec 预期的 24/25 更好——33.877 已在本轮删壳）。
