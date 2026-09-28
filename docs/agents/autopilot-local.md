# Autopilot 项目本地化覆盖（本项目专用，无中央日志模式）

本项目后续工程开发走项目内 `skills/autopilot`（`C:\Project\永劫无间\skills\autopilot\SKILL.md` 及其 25 个子 skill，均已随项目存放）。

## 与 autopilot 包默认行为的差异（本项目覆盖）

1. **不写中央日志**：忽略 `usage-log.md` 的中央本追加（`C:\Project\全自动启动mattpocock工作流skill\autopilot-USAGE-LOG.md`）、每任务一条、每 3 工程轮一条反思。过程追踪只写任务侧：`123\<编号>.<素材名>\reports\dispatch_ledger.md`（派工/回收行）与 `reports\workflow_notes_<序号>.md`（沉淀节）。
2. **不建任务标记**：忽略 `trace-discipline.md` 的 `.scratch/WORKFLOW-ACTIVE.md` 标记、JOURNAL `Skills called:` 行、logbook 水位线自举。新窗口从 `.scratch/<slug>/spec.md` + 任务 `dispatch_ledger.md` + `workflow_notes` 末节恢复上下文。
3. **单轮开闭免标记**：文档小修、单文件改动等一轮内开闭的任务，不建任何标记文件（与 autopilot V2.019 单轮豁免一致，只是本项目连豁免声明行都不写——台账行即记录）。
4. **自进化门保留**：永远不改 `skills/autopilot/**` 任何文件（SKILL.md、references/、agents/、CHANGELOG.md）。发现触发条件写错，照当前规则把活干完，想法记入 `.scratch/<slug>/DRIVER-PROPOSAL.md`。
5. **本仓非 git**：落地 = 落盘 + 台账条目；autopilot 的 commit/tag/线性历史语义在本项目不执行。

## 车道映射

- 视频剪辑任务：仍以 `AGENTS.md` + `naraka-highlight-studio` 为准，autopilot 不介入。
- 项目本身的代码/文档修正：autopilot 全自动（理解 → spec → 拆票 → 构建 → 验证），只有破坏性、对外可见或变更范围的决策停下找人。
