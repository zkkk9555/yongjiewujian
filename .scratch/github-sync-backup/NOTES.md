# GitHub 备份同步（2026-10-29 一轮收尾记录）

> Lead 记录｜时间 2026-10-29 01:45–02:30 (+0800)｜项目 `C:\Project\永劫无间`
> 用户请求（m00002 原文）："理解项目，看看github是有没有同步最新的版本，确保GitHub上面的备份是最新的"
> 配套报告：`survey.md`（只读调研，数字以本文件与 survey.md 页首「Lead 复核更正」块为准）

## 开工卡

| 项 | 内容 |
|---|---|
| 目标 | 让 GitHub 上的备份 = 本地最新状态（含"备份是否真的完整"的复核） |
| 判据 | ① 远端 sha/tree 与本地一致 ② 全新 clone 可复现内容 ③ 无凭据泄漏 ④ 缺口清单可裁量 |
| 范围 | 只读审计 + 1 次 `git push`（14 提交）+ 2 个档案文件入库；**不动 .gitignore、不动剪辑资产** |
| 计划 | surveyor 只读调研（task-1）→ Lead 复核/推翻数字 → 同步与三重验证 → 收尾档案入库 → 一次性给结论 |
| 风险 | 仓库 **public**：push 即公开发布；`.scratch/` 含本机指纹；`123/` 证据整目录被忽略 |
| 回退 | 同步前远端为 `452dd50`（2026-10-08）；本轮无破坏性动作（无 reset/rebase/force push/删除） |

## 结论三行

1. **已同步**：`origin/main` = `3febfb9153448095c709a6d973cddfd1edc48269`，tree = `1dfec66bb8fcda79dec3a493265fe824236a06d2`，与本地 HEAD 逐字节一致。
2. **已独立复核**：GitHub API 与全新 clone 两侧都复现同一 sha/tree/587 文件/16 tag → 不是"本地以为推上去了"。
3. **备份"最新"但"不完整"**：`123/` 下 3216 份 / 48.04 MB 文本证据仍不在仓里（见"发现"1–3），是否补入属**对外可见 + 扩范围**决策，留给用户裁量。

## 事实与证据（可复算）

| 检查 | 命令 | 结果 |
|---|---|---|
| 远端头 | `git ls-remote origin refs/heads/main` | `3febfb9…`（push 前为 `452dd50…`） |
| 本次推送 | `git push origin main` | `452dd50..3febfb9  main -> main`，reflog 时间 2026-10-29 01:56:41 |
| 差集 | `git diff --stat 452dd50..HEAD` | 93 files changed, 7930 insertions(+), 343 deletions(-) |
| GitHub 侧 | `GET /repos/zkkk9555/yongjiewujian/commits/main` | sha `3febfb9…`、tree `1dfec66…`；pushed_at 2026-10-28T17:57:08Z |
| 全新 clone | `git clone -c http.proxy=http://127.0.0.1:7897 <url> <tmp>` | HEAD `3febfb9…`、tree `1dfec66…`、587 跟踪文件、16 tag；AGENTS.md / README.md / 123/README.md / skills/cujian/SKILL.md / skills/jingjian/SKILL.md / scripts/new_task_dir.ps1 / docs/lessons/POOL.md / config/production_dependencies.json 全在 |
| 标签 | 本地 16 tag vs 远端 | 名称全同，抽查 v1.001 / v1.010 / v1.016 的 `^{}` SHA 一致 |
| 凭据 | 树 + 49 提交增量 grep | `ghp_`/`github_pat_`/`sk-`/`AKIA`/`BEGIN … PRIVATE KEY`/`password=` **0 命中**；作者全为 noreply 邮箱 |
| 体积 | `git ls-files` 逐文件 stat | 587 文件 / 9,184,001 B = 8.76 MB；`.git` 8.7 MB；无任何 >1 MB 文件 |
| 未跟踪未忽略 | `git status --porcelain -uall` | 0 行 → 那次 push 没漏文件 |

> 复算坑：项目代理只写在 `.git/config`（`http.proxy=http://127.0.0.1:7897`），**在项目外 clone 必须显式 `-c http.proxy=…`**，否则表现为"远端不可达"，会误判成同步失败。

## 发现（按严重度）

1. **`123/` 任务证据 = 备份的真空区（3216 文件 / 48.04 MB）**。`.gitignore:36` 的 `123/*` 把 24 个任务目录整目录忽略，只留 `!123/README.md`。其中：`reports/**/*.md` 2413 文件 37.19 MB（审计/验收/门禁/逐点裁决）、`timeline/*.json` 335 文件 7.44 MB（"这段为什么留、那段为什么删"）、`captions/*.srt` 106 文件 0.60 MB（外挂字幕正本）、`reports/*.json` 347 文件 2.64 MB、`workflow_notes_*.md` 61 份。
2. **文档链断裂**：`123/workflow_upgrade/`（14 文件 / 171.8 KB）是 AGENTS.md §8 里 e1–e5、g 组设计的**唯一原稿**，新克隆打开这些引用会指向空。
3. **编号会撞车**：`123/index.tsv`（1.9 KB，23 行）记录了 37(892)/38(893)，磁盘最大只到 36；该文件被同一行 `123/*` 忽略 → 新克隆里 `new_task_dir.ps1` 只能算到 36，**会重发 37/38**，违反"编号只增不重置"。
4. **仓库是 public，且 `.scratch/` 含本机指纹**：`.scratch/image-budget/07-proposals.md:215-219` 写了本地服务端口 `127.0.0.1:49374` 与 Basic 认证说明（只说"密码取自 …\service.json"，**无密码值**）；另有 6 个 py 硬编码 `C:\Users\Administrator\…`。均非凭据，但已随 push 公开。
5. **小口径不一致**：`.scratch/aivideo/bench/out` 的 140 个 `.err`（722,046 B）被入库，而 138 个同名 `.log` 被 `*.log` 忽略；`.gitignore` 注释里引用的"README 的「体积与上传」一节"在 README 里已不存在；README 写"16 条成片"，实测 `E:\Cujian导出` 41 条目 / 69 GB。

## 调研数字的更正（审计留痕）

surveyor 初稿称"580 文件 / 9.40 MB"，Lead 复算为 **3216 文件 / 48.04 MB**（差 5 倍）。原因：它只数 `reports/*.md` 顶层，漏掉 `reports/**` 二级目录；`timeline/*.json` 513→335、`captions/*.srt` 198→106 也偏大。差异已在 `survey.md` 页首加更正块并就地改表，**以 Lead 实测为准**。

## 建议（成本从低到高，均未执行）

| 级别 | 动作 | 体积 | 说明 |
|---|---|---|---|
| P1 | `!123/index.tsv` + `!123/workflow_upgrade/` | ~174 KB | 修 2 条真缺陷（撞号 + 文档链断裂），几乎零成本 |
| P2 | 再补 `!123/*/timeline/`、`!123/*/captions/`、`!123/*/reports/*.md`、`!123/*/reports/*.json` | +48 MB | 备份真正完整；对 git 无压力（当前树 8.76 MB 的 5.5 倍），但**内容公开面显著扩大** |
| P3 | `git rm --cached` 140 个 `.err` + `.gitignore` 加 `*.err` | −722 KB | 与 `*.log` 口径统一；`.err` 无证据价值 |
| P4 | 仓库转 private 或改写 `.scratch` 本机指纹 | — | 若不愿公开本机路径；历史已推，彻底清除需 `filter-repo` + force push（破坏性，须人确认） |

**为什么 P2 不擅自做**：它把 48 MB 审计/字幕/时间线公开到公网，属"对外可见 + 变更范围"，automatt 规则要求停下找人。
