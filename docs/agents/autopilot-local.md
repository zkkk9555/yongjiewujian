# Autopilot 项目本地化覆盖（本项目专用，无中央日志模式）

本项目后续工程开发走 `autopilot` 全自动流程。**`autopilot` 及其子 skill 是用户级通用工程工具，
不是本项目资产**：由 harness 的用户级 skill 目录提供，用 skill 工具按名字加载，
本项目不存放也不修改其副本（分类判据见 `AGENTS.md` § Skill 来源分两类）。

本文件记录本项目对 autopilot 包默认行为的**覆盖项**。这些约定只讲"本项目怎么做"，
不重复 autopilot 自身写了什么——那些以 skill 里的原文为准。

## 与 autopilot 包默认行为的差异（本项目覆盖）

1. **不写中央日志**：忽略包内 usage-log 的中央本追加（每任务一条、每 3 工程轮一条反思）。
   过程追踪只写任务侧：`123\<编号>.<素材名>\reports\dispatch_ledger.md`（派工/回收行）与
   `reports\workflow_notes_<序号>.md`（沉淀节）。
2. **不建任务标记**：忽略包内 trace-discipline 的激活标记文件、JOURNAL `Skills called:` 行、
   logbook 水位线自举。新窗口从 `.scratch/<slug>/spec.md` + 任务 `dispatch_ledger.md` +
   `workflow_notes` 末节恢复上下文。
3. **单轮开闭免标记**：文档小修、单文件改动等一轮内开闭的任务，不建任何标记文件
   （台账行即记录，连豁免声明行都不写）。
4. **自进化门保留**：永远不改用户级 skill 目录里的任何文件——SKILL.md、references/、agents/、
   CHANGELOG.md 一律只读。发现触发条件写错，照当前规则把活干完，想法记入
   `.scratch/<slug>/DRIVER-PROPOSAL.md`。**这一条现在比从前更要紧**：从 2026-10-06 起
   autopilot 的正本在项目外，改它等于改用户全局工具，会波及本项目之外的其它工作。
5. **版本控制照常执行**：本仓自 2026-09-29 起已入 git，commit / tag / 推送都正常做。
   autopilot 假定"落地=提交"的语义在本项目成立；只是**单次落地不等于交付**——
   视频任务目录 `123\<编号>.*` 按 `AGENTS.md §7.1` 管理，不进版本库。

## 车道映射

- 视频剪辑任务：仍以 `AGENTS.md` + `naraka-highlight-studio` 为准，autopilot 不介入。
- 项目本身的代码/文档修正：autopilot 全自动（理解 → spec → 拆票 → 构建 → 验证），
  只有破坏性、对外可见或变更范围的决策停下找人。