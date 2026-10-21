# 03: 项目卫生（版本库可信 + 散文件清理 + 旧名迁移）

**What to build:** 让仓库回到可信状态：`git status` 干净、两个正式 skill 已入库、文档与磁盘一致；
项目根无散文件；`123\` 编号占用登记清楚；门禁不再对已知占用说「编号唯一」；
旧名 `autopilot` 在工作区内的引用全部改成 `automatt`，并在 `AGENTS.md` 补上凭据行，
让本项目以后能被自动驱动。

**Anchors:**
- `AGENTS.md :: ### Autopilot`
- `docs/agents/autopilot-local.md :: 与 autopilot 包默认行为的差异`
- `README.md :: Skill 来源分两类`
- `docs/TOOLS.md :: 工程开发类 skill`
- `scripts/check_task_numbering.ps1 :: 检查 1：同一编号出现多个目录`
- `scripts/check_video_environment.ps1 :: project root hygiene`

**Blocked by:** 01、02

**Status:** resolved

- [x] 前置 chore 提交：10-06/10-07 的积压工作树（含未入库的 `skills/cujian`、`skills/jingjian`、
      `docs/精剪提示词.md`、`.scratch/archive/` 归档）单独成一笔 chore commit
- [x] `.gitignore` 补 `.dsh-ops/`（驱动自有锁文件）
- [x] 删项目根 `dump_v3_out.txt`（0 字节）、7 处 `__pycache__`
- [x] `33.877` 撞号空壳：6 张标定帧移进 `33.887\reports\calib_877_t1039-1041\`，再删空壳
- [x] `check_task_numbering.ps1` 措辞修正：撞号时不再打印「编号唯一」
- [x] 旧名迁移：`AGENTS.md`、`README.md`、`docs/TOOLS.md`、`docs/agents/autopilot-local.md`
      （含文件名）全部改 `automatt`；`AGENTS.md` 加凭据行 `automatt: on`
- [x] 收尾自检：预检退出码 0、编号体检 PASS、git status 干净

## Answer (decision tickets only)

**已完成（票 03 提交）。** 三处与 spec 的偏差：

1. spec 说「7 处 `__pycache__`」→ 实测并删掉的是 **7 处**（`skills/cujian`、`skills/jingjian`
   各一处 + 5 个任务目录的 `scripts_local`），与 spec 一致；但**它们会再生成**
   （任何一次 python 运行都会重建），所以真正的修复是「precheck 把它报成 WARN 而不是当作故障」——
   本轮预检已从 `ok=9 warn=2` 变成 `ok=10 warn=0`。
2. spec 说「`.gitignore` 补 `.dsh-ops/`」→ 顺手确认了 `dump_v3_out.txt` 其实**没有**被 gitignore
   （precheck 的附注说「*.txt is gitignored」与实际不符）——所以它是 untracked 而非被忽略，
   删掉才是正解；本轮已删。
3. 「`nul` 空文件」**已不存在**：34.889 的 `cmd dir /a` 现在只列 5 个目录、0 个文件，
   `_final_delivery.txt` 里那条「could not remove the `nul` stray」是当时的历史记录。
   本轮不删任何东西，只在体检报告里记一条「读数与现状不符」。

**验证**：预检 `ok=10 warn=0 blocker=0` 退出码 0；编号体检「命名完整、没有空壳目录；
但**编号不唯一**（1 条占用登记见下）」；卫生门 0 失败 / 24；经验池待升级 0、缺 notes 0。
