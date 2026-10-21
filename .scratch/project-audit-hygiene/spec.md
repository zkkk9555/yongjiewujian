# Spec: 项目体检 + 经验收纳 + 项目卫生

> 本轮由用户一句话触发：`完整理解项目 / 检查一下之前的剪辑工作 / 整理经验 / 整理项目卫生`。
> 触发方式：`automatt`（用户级技能，AFK 全自动）。
> 本地化覆盖见 `docs/agents/autopilot-local.md`（不写中央日志、不建任务标记；本仓 `.scratch/` 即 tracker）。

## Problem

三件事叠在一起，彼此独立又不冲突：

1. **项目状态失真**——工作树里堆着 2026-10-06/07 两轮改动没提交，其中包含**两个从未入库的正式 skill**
   （`skills/cujian/`、`skills/jingjian/`，即粗剪与精剪的全部规格与脚本）。仓库的 HEAD 仍是旧的
   `naraka-highlight-studio`。文档（AGENTS.md 工作树版）已经写着 cujian/jingjian 是正本，版本库却不是。
   → 一旦需要重克隆，本项目的核心资产就没了。
2. **经验池退化成摆设**——`collect_lessons.ps1` 扫出 **789 条**待升级候选（25 个任务目录 + `docs/lessons/`），
   而 `docs/lessons/POOL.md` 只收了 864/863 两批 57 条。873–890 这十局的经验**一条都没进工作流**。
   池子本身还有结构缺陷：待升级区里有两行重复表头、一条重复的 `L-037`、五条已标记「已吸收」的行却压在
   「待升级」标题底下。
3. **卫生**——项目根有 0 字节散文件 `dump_v3_out.txt`、7 处 `__pycache__`；`123\` 里 `33.877` 是撞号空壳、
   `34.888`/`34.889` 撞号且被上一轮明确挂起；34.888 还留着 328.6 MB 可再生的参考视频；
   4 个任务目录没有 `workflow_notes`（经验覆盖率 21/25）；39 个经验文件命名不合规（真错的只有 2 个，
   其余是门禁规则写得过严）。

## Solution

拆三张票，一票一提交（`docs/agents/issue-tracker.md`）：

| 票 | 做什么 | 产物 |
|---|---|---|
| 01 `audit-prior-edits` | 逐个体检 25 个任务目录 + E 盘母版，出一份可判读的体检报告 | `docs/lessons/STATUS-2026-10-22.md` |
| 02 `absorb-lessons` | 可复用规则写进 skill references，POOL 重整并逐条留去向，补齐缺失的 workflow_notes | `skills/cujian/references/*.md`、`skills/jingjian/references/deliverables-and-qa.md`、`docs/TROUBLESHOOTING.md`、`docs/lessons/POOL.md` |
| 03 `project-hygiene` | 提交积压工作树（含两个未入库 skill）、.gitignore、旧名迁移、散文件与撞号清理、门禁措辞修正 | git 历史 + `scripts/*.ps1` + `AGENTS.md`/`README.md`/`docs/` |

另有一笔**前置 chore**：把 2026-10-06/07 已完成但未提交的工作树先提交掉（含未入库的
`skills/cujian`、`skills/jingjian`、`docs/精剪提示词.md`），否则本轮三张票的 diff 会被淹没在别人的改动里。

## User-Stories

- **US1（我要知道之前的剪辑到底做得怎么样）**：给我一张 25 个任务目录的体检表——母版在不在 E 盘、
  冻结门禁最后判什么、收尾清理跑没跑、经验落了没有、缺口是什么。缺证据的地方直接写「缺」。
- **US2（我要经验真能被下一局用上）**：873–890 的可复用规则要出现在**下一局会被读到的地方**
  （`skills/cujian/references/`、`docs/TROUBLESHOOTING.md`、`jingjian` 交付规范），
  而不是只躺在某个任务目录里。POOL 每条都要写清「吸收去向」，否则下一轮收纳会重复提出来。
- **US3（我要仓库回到可信状态）**：`git status` 干净，两个正式 skill 在版本库里，文档与磁盘一致。
- **US4（我不想被删掉东西）**：只删「可再生 + 逐件可枚举 + 零证据」的；任何报告/时间线/成片一律不删。

## Implementation Decisions

### D1 · 「整理经验」分两路：规则进规格，审片记录判一次性

`collect_lessons.ps1:191` 把所有 `##`/`###` 标题当候选（「宁可多报也不漏报」），所以 789 条里绝大多数是
**报告标题**（「对抗审 adv9」「验收员 C」「seg12 扫描报告」），不是可复用规则。
POOL 已有的 57 条全是**规则级**条目并带 `吸收去向`。

- **可复用规则** → 写进 `skills/cujian/references/complete-combat-roughcut.md`（判定规则）、
  `skills/cujian/references/roughcut-launch.md`（派工与角色）、`docs/TROUBLESHOOTING.md`（工具与仪器坑）、
  `skills/jingjian/references/deliverables-and-qa.md`（交付与验收）；POOL 另起一行，来源写素材号，
  教训列**以原文标题加粗开头**（POOL 第 2 条硬规矩，是脚本的机器锚点）。
- **逐局审片记录** → 判「一次性」，POOL 留一行摘要，指向任务目录原文。

### D2 · 机器闭环靠**来源键**，不靠逐条抄写

`collect_lessons.ps1:209`：`InPool = $absorbedSources.Contains($c.Source) -or Test-Absorbed ...`。
POOL 里只要有一行的「来源」列写着**任务目录全名**（如 `26.873永劫无间 2026-10-03 21-09-53`），
该目录的全部候选即判已吸收。→ 每个任务目录补一行「本局经验去向摘要」（来源=目录全名），
机器闭环；规则级条目另起行（来源=素材号）以保留转述匹配能力。

### D3 · 34.888 / 34.889 撞号**不改目录名**

改号会让两份任务目录里几十处绝对路径证据（冻结门禁、验收报告、交付说明）全部变成失效路径，
代价远大于收益。改**门禁的措辞**（现在撞号时仍打印「[PASS] 编号唯一」，是误导），并在体检报告里登记为
已知占用。→ 最小可逆动作。

### D4 · 33.877 空壳：移帧再删壳，不丢字节

它只有 6 张标定帧（`cache\focus_check2\cal\t1039.0–t1041.5.jpg`），与 33.887 是同一场录屏
（文件名时间戳同秒 `2026-10-15 00-17-51`），且 887 已有完整的同场交付。→ 把 6 帧移进
`33.887\reports\calib\`，再删空壳目录；编号 33 恢复唯一。

### D5 · 只删可再生物

删：项目根 `dump_v3_out.txt`（0 字节）、7 处 `__pycache__`、33.877 空壳（帧已移走）。
不删：任何 `reports/`/`timeline/`/`analysis/` 文本证据、任何 E 盘母版、任何未提交的工作树改动。

### D6 · 经验命名门禁改「前缀式」，只改真错的那 2 个

`check_task_hygiene.ps1:123` 现在的判据是「文件名必须**等于** `workflow_notes_<目录号>.md`」，
于是把合法的多文件经验（`workflow_notes_34_seg1.md`、`workflow_notes_34_commander.md`）也判成违规——
34.889 一个目录就有 32 个这样的文件。改成**前缀式**（`workflow_notes_<目录号>` 开头即合规），
真正该改名的只剩 2 个：`13.849` 里的 `workflow_notes_849.md` → `workflow_notes_13.md`、
`20.863` 里的 `workflow_notes_863.md` → `workflow_notes_20.md`。

## Testing Decisions

- **门禁回归**：改完 `check_task_hygiene.ps1` 后，对 25 个任务目录各跑一次，退出码必须全 0；
  「命名不合规」计数必须从 39 降到 0。
- **经验闭环**：改完 POOL 后跑 `scripts/collect_lessons.ps1`，「待升级」必须为 0 条，
  「缺 workflow_notes」必须从 4 降到 1（只剩被删掉的 33.877）。
- **POOL 自洽**：POOL 里 `L-xxx` 编号不得重复；「已吸收」的行不得出现在「待升级」标题下；
  每条已吸收行必须有非空「吸收去向」。
- **母版帧精确**：对 10 份近期母版跑 ffprobe，`nb_frames == duration × 60`（本轮实测已全部 delta=0），
  并把 A/V 漂移记进报告（恒为 21 ms = 一个 AAC 包，不随段数累加）。
- **提交后自检**：`git status` 干净；`skills/cujian/SKILL.md` 与 `skills/jingjian/SKILL.md` 在版本库里；
  预检 `check_video_environment.ps1` 退出码 0。

## Out of Scope

- 不重剪任何一局，不动任何已交付母版。
- 不改 `skills/cujian/references/` 里已有的规则条文（只**增补**新章节，不改写旧条）。
- 不修 `qa_gate.py` / `map_captions.py` 的代码 bug（只登记，见票 02 的「已知未修」清单）。
- 不动用户级 skill 目录（`~/.config/opencode/skills/`）里的任何文件。

## Glossary

- **母版**：`E:\Cujian导出\<素材名> cujian.mp4`，粗剪冻结线的 4K 重建件。
- **冻结门禁表**：`reports\freeze_gate_<序号>_vN.md`，五门 AND 的判定记录。
- **streak**：连续零新增版计数，`streak ≥ 2` 才算正式冻结（`roughcut-launch.md §3.7`）。
- **待升级**：POOL 里的状态词，指「已记录但还没进工作流规则」。
- **来源键**：`collect_lessons.ps1` 用来判「这条经验是不是已经吸收」的锚。

## Notes

- 本轮是**读多写少**的体检轮，看图预算不消耗（不看片，只读盘面证据 + 报告文本）。
- `automatt` 的「改名前迁移」在本轮落地：项目里所有 `autopilot` 旧名引用改成 `automatt`，
  并在 `AGENTS.md` 补上凭据行 `automatt: on`（否则本项目以后不会被自动驱动）。
- 项目本地化覆盖优先：不写中央日志、不建 `WORKFLOW-ACTIVE` 标记、JOURNAL 行不写。

`Checks:` i18n Pass/N-A — N/A（本项目无 i18n）｜save Pass/N-A — N/A（无存档系统）｜BALANCE Pass/N-A — N/A（无平衡表）
