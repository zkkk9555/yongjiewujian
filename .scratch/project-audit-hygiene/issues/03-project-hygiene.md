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

**Status:** ready-for-agent

- [ ] 前置 chore 提交：10-06/10-07 的积压工作树（含未入库的 `skills/cujian`、`skills/jingjian`、
      `docs/精剪提示词.md`、`.scratch/archive/` 归档）单独成一笔 chore commit
- [ ] `.gitignore` 补 `.dsh-ops/`（驱动自有锁文件）
- [ ] 删项目根 `dump_v3_out.txt`（0 字节）、7 处 `__pycache__`
- [ ] `33.877` 撞号空壳：6 张标定帧移进 `33.887\reports\calib\`，再删空壳
- [ ] `check_task_numbering.ps1` 措辞修正：撞号时不再打印「编号唯一」
- [ ] 旧名迁移：`AGENTS.md`、`README.md`、`docs/TOOLS.md`、`docs/agents/autopilot-local.md`
      （含文件名）全部改 `automatt`；`AGENTS.md` 加凭据行 `automatt: on`
- [ ] 收尾自检：预检退出码 0、编号体检 PASS、git status 干净

## Answer (decision tickets only)
