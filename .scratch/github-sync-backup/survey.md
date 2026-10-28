# 调研报告：项目理解 + GitHub 备份覆盖审计

> 调研员：surveyor｜时间：2026-10-29 01:55–02:05 (+0800)｜任务板：`task-1`
> 工作目录：`C:\Project\永劫无间\`｜remote：`https://github.com/zkkk9555/yongjiewujian.git`
> 本报告只读调研，唯一写入即本文件。**未执行任何 git 写操作**（add/commit/push/checkout/reset/stash 一次都没跑）。

> ### ⚠️ Lead 复核更正（2026-10-29 02:20 +0800）——以下数字以 Lead 实测为准
>
> 本报告 §0③ / §B.3 / §B.5 / §C.3 里的「**580 文件 / 9.40 MB**」**作废，低估 5 倍**。原因：只数了 `reports\*.md` 的**顶层**，漏掉 `reports\**` 二级目录（`reports/selfaudit/`、`reports/agents/` 等 2413 份里的绝大部分）；`timeline\*.json` 513 与 `captions\*.srt` 198 也数错（偏大）。
>
> | 资产 | 路径模式 | Lead 实测 |
> |---|---|---|
> | 时间线 | `123/*/timeline/*.json` | 335 文件 / 7.44 MB |
> | 外挂字幕正本 | `123/*/captions/*.srt` | 106 文件 / 0.60 MB |
> | 审计/验收/门禁（递归） | `123/*/reports/**/*.md` | **2413 文件 / 37.19 MB** |
> | 机器裁决记录 | `123/*/reports/*.json` | 347 文件 / 2.64 MB |
> | e1–e5 / g 组设计原稿 | `123/workflow_upgrade/` | 14 文件 / 171.8 KB |
> | 编号台账 | `123/index.tsv` | 1 文件 / 1.9 KB |
> | **白名单口径合计** | 以上六项 | **3216 文件 / 50,377,512 B = 48.04 MB** |
>
> 其它更正：`.scratch` 实测 **4.87 MB / 321 文件**（非 5.7 MB）；`123` 合计 5233 文件 / 134 MB，24 个任务目录 + `workflow_upgrade` = 25 个一级目录；`workflow_notes_*.md` 共 **61 份**（分布 24 个目录，"24/24 全覆盖"成立，只是份数不是 24）。
>
> 复核后仍然**成立**的结论：仓库 public、凭据 0 命中（树 + 49 提交历史）、`index.tsv` 37/38 撞号风险、`.scratch/aivideo/bench/out` 140 个 `.err` 已入库 722,046 B、README 的"16 条成片"过期（实测 `E:\Cujian导出` 41 条目 / 69 GB）、已跟踪 587 文件 / 8.76 MB。

---

## 0. 最该立刻知道的 3 件事

### ① push 已经在本次会话开始时发生了 —— 本地已不领先，无需再 push

我开工那一刻（01:55:32）读到的确实是「领先 14」，但 **2026-10-29 01:56:41 有一次 push 把 origin/main 推到了 HEAD**：

```
$ git reflog show origin/main --date=iso | head -3
3febfb9 refs/remotes/origin/main@{2026-10-29 01:56:41 +0800}: update by push
452dd50 refs/remotes/origin/main@{2026-10-08 09:16:23 +0800}: update by push

$ git rev-parse HEAD ; git rev-parse origin/main
3febfb9153448095c709a6d973cddfd1edc48269
3febfb9153448095c709a6d973cddfd1edc48269

$ git ls-remote origin main          # 活查远端，不是本地缓存
3febfb9153448095c709a6d973cddfd1edc48269	refs/heads/main

$ git rev-list --count origin/main..HEAD ; git rev-list --count HEAD..origin/main
0
0
```

- 「14 个提交 / 93 文件 / +7930−343」这个口径对得上 **452dd50..HEAD**：`git diff --stat 452dd50..HEAD` → `93 files changed, 7930 insertions(+), 343 deletions(-)` —— Lead 手上那份数字没错，只是**基线是 452dd50（2026-10-08 最后一次 push）**。
- 现已全部在远端：`git rev-list --count origin/main..HEAD` = **0**。**这次不需要 push，也推不出东西了。**
- 附带发现：`.git/packed-refs` 里还留着更老的 `befa356d578cad1fbf32ad5b0e8cdc65064ea2d2 refs/remotes/origin/main`（2026-10-05 打包）。它已被松散引用覆盖，`befa356..HEAD` 是 34 个提交 —— 拿 packed-refs 当基线会算错，复核请用 `git ls-remote`。

### ② 这个仓库是 **public**，刚才那次 push 等于直接发布到公网

```
$ curl -s -o /tmp/repo.html -w 'http_code=%{http_code}' https://github.com/zkkk9555/yongjiewujian
http_code=200
$ grep -o '<title>[^<]*</title>' /tmp/repo.html
<title>GitHub - zkkk9555/yongjiewujian · GitHub</title>
$ curl -s -o /dev/null -w '%{http_code}' https://raw.githubusercontent.com/zkkk9555/yongjiewujian/main/README.md
200
$ curl -s https://raw.githubusercontent.com/zkkk9555/yongjiewujian/main/README.md | head -1
# 《永劫无间》视频剪辑项目          # 与本地 README.md 首行逐字一致
```

未认证能拿到 200 + 真实标题 + raw 文件 → **公开仓**（私有会 404）。所以 §B.7 的「暴露面」不是假设，是既成事实。

### ③ 真正值钱的东西 **仍然没进 git**：`123\` 下约 3216 份 / 48.04 MB 文本证据，一份都没有（数字经 Lead 更正，见页首）

```
$ git ls-files -- 123 | wc -l
1                        # 只有 123/README.md
$ git check-ignore -v "123/21.864永劫无间 2026-09-30 02-57-13"
.gitignore:36:123/*	123/21.864永劫无间 2026-09-30 02-57-13
```

24 个任务目录 **整目录被 .gitignore:36 忽略**，里面是高价值证据（见 §B.3）：`timeline\*.json`（为什么留/为什么删）、`reports\*.md`（审计/验收/门禁）、`captions\*.srt`（外挂字幕正本）、`reports\workflow_notes_*.md`（每局经验），合计 **3216 文件 / 50,377,512 B = 48.04 MB**（Lead 更正；主力是 `reports\**\*.md` 2413 份 37.19 MB）。外加 **`123\workflow_upgrade\` 14 个文件 / 172 KB**——AGENTS.md 明确把它当 e1–e5 / g 组设计的**唯一原稿**引用，现在也不在仓里。这是本轮的核心风险，且**不因刚才那次 push 而缓解**。

---

## A. 项目理解摘要

### A.1 项目是什么、为谁服务、核心目标

以 **FFmpeg 为渲染核心**的《永劫无间》游戏录像**分析与剪辑**工作区（`README.md`、`AGENTS.md`）。
服务对象是**同一个人的单人创作者流水线**：用户丢一条整局素材（`E:\OBS` 原始录制 / `E:\PR导出` 已粗加工），
要求「**一整场完整战斗、中间不许断档**」地粗剪出审片预览，确认后**从原始 4K 素材重渲**成片。
核心目标（`AGENTS.md §8.1`，最高优先级判据）：战斗窗口内**不许挖洞、不许切断**；成片一律**外挂字幕、禁烧录**；
所有派生文件只落 `123\<编号>.<素材文件名>`；成片正本只落 `E:\Cujian导出`。
工程侧目标：把每次踩的坑沉淀成**可复查的规格 + 门禁 + 经验池**，让任意 Agent 会话接手时不重犯。

### A.2 目录职责

| 目录 | 职责 | 实测（2026-10-29） |
|---|---|---|
| `123\` | **任务结果根**：每个素材一个 `<编号>.<素材文件名>` 目录，装分析/时间线/预览/字幕/审计 | 24 个任务目录，134 MB；入库仅 `README.md` |
| `123\workflow_upgrade\` | e1–e5 / d1–d3 / f / g 组**设计原稿**与合入记录，被 AGENTS.md 引用 | 14 文件，171.8 KB，**完全未入库** |
| `scripts\` | 门禁、分配器、清理、4K 渲染/验收、回归测试（项目源码） | 33 文件：14 ps1 + 14 sh + 5 py，344 KB |
| `skills\` | **项目资产 skill**：cujian（粗剪）/ jingjian（精剪）/ ffmpeg-video-editor / ffmpeg-analyse-video-skill | 40 文件，464 KB；旧 naraka-highlight-studio 已归档为 ARCHIVED.md 指针 |
| `docs\` | 规则与专题文档（工作流、工具、故障、提示词、经验池） | 176 文件，5.6 MB（含 docs/lessons 165） |
| `config\` | 生产依赖清单（版本钉死，与 venv 对账） | 1 文件 production_dependencies.json |
| `assets\` | **素材索引**（asset_manifest.json）+ bgm/sfx/fonts/overlays 四空目录占位 | 6 文件，13 KB；**真实媒体一律不入库** |
| `style_profiles\` | 剪辑风格档案（complete_combat_roughcut_v1 / high_energy_v1） | 2 文件，12 KB |
| `feedback\` | 用户反馈 schema（feedback.schema.json） | 1 文件，1 KB |
| `docs\lessons\` | **经验池**：POOL.md 汇总入口 + 专题复盘 + 逐局保留证据 archive/864-rejected-attempt/ | 165 文件，3.15 MB |
| `.scratch\` | 工程任务档案（<slug>/spec.md + issues/NN-*.md），issue-tracker 的落地处 | 321 tracked / 5.7 MB（占入库文件数 55%） |
| `.video-tools\` | 工具环境：venv / 模型权重 / LosslessCut（可重装） | **9.9 GB，忽略** |

### A.3 关键脚本清单（按功能分组）

**① 环境预检与路径解析**
- `scripts\check_video_environment.ps1` —— **入口·每任务第一动作**。只读；退出码 0 可开工 / 2 BLOCKER / 1 没跑完。被 `AGENTS.md §3`、`README.md` 调用。
- `scripts\resolve_ffmpeg.ps1` —— **库（不是入口）**。FFmpeg/FFprobe 的单一真源；dot-source 取函数或 `-Emit` 给 bash 取 KEY=VALUE。被 `seg_render_master.sh`、`verify_master.sh`、`make_contact_sheet.ps1` 等 dot-source（全仓 60 个文件提到 seg_render_master.sh、83 个提到 cleanup_after_master.ps1，说明这套脚本是全链路公共依赖）。
- `scripts\mojibake_guard.ps1` —— **库**。「这是不是本项目乱码目录」的单一判据，预检 / 清理 / 回归三边共用。回归：`test_mojibake_guard.ps1`（36 例，含拿真脚本带 `-Remove` 跑的端到端）。

**② 任务目录与编号**
- `scripts\new_task_dir.ps1` —— **入口·建目录唯一合法入口**。加锁 + 幂等 REUSE + 单调取号 + 写 `index.tsv`。
- `scripts\check_task_numbering.ps1` —— 门禁：编号唯一 / 命名未截断 / 无空壳 / 索引齐 / 素材号顺序。**撞号退出码 1**。
- `scripts\test_new_task_dir.ps1` —— 上面两者的回归测试。

**③ 卫生与清理**
- `scripts\check_task_hygiene.ps1` —— 门禁：保留区不该有 >10 MB 音视频、散文件、命名等。
- `scripts\cleanup_after_master.ps1` —— **入口·出 4K 后的固定步骤**（AGENTS.md §7.1）。先证明成片已落 `E:\Cujian导出`，否则 `[BLOCKED]` 一字节不删；先写 `reports\cleanup_log_after_master.md` 再删。
- `scripts\sanitize_stray_dirs.ps1` —— 手动、破坏性（默认干跑），只删反解命中的本项目乱码目录，其它一律保留。

**④ 4K 渲染与验收**
- `scripts\seg_render_master.sh` —— 入口：分段渲染 + 岛式合并（零 Python 可跑）。
- `scripts\verify_master.sh` —— 入口：母版全解码 / 字幕流 / 时长对账。

**⑤ 分析辅助**
- `scripts\make_contact_sheet.ps1`（联系表，1 张算 1 图）、`scripts\check_image_budget.ps1`（50 张红线前的分轮预算）、`scripts\read_episode_bounds.ps1`（打印某条时间线的切点）。

**⑥ 经验收纳**
- `scripts\collect_lessons.ps1` —— **入口·说「去收纳经验」就跑它**。扫任务目录 `workflow_notes_*` + `docs\lessons`，对照 `POOL.md` 列待升级 + 报覆盖率。

**⑦ 回归测试（14 个）**
- `test_auto_chain.sh` `test_coverage_gate.sh` `test_coverage_regression.sh` `test_deleted_voice_audit.sh` `test_hole_render_e2e.sh` `test_insegment_holes.sh` `test_mojibake_guard.ps1` `test_new_task_dir.ps1` `test_partial_refusal.sh` `test_state_file.sh` `test_streaming_merge.sh` `test_thread_budget.sh` `test_watchdog.sh` `test_whole_battle_gates.sh`
- 测试夹具（不是测试本体）：`auto_chain_probe.py`、`merge_probe.py`、`stream_merge_kit.py`、`watchdog_testkit.py`；一次性审计：`audit_coverage_judgement.py`。

### A.4 任务编号机制现状

- **规则**（`123\README.md` + `scripts\new_task_dir.ps1`）：目录名 = `<编号>.<源文件名去扩展名>`，**原样照抄不加工**；取号走分配器，**max+1 单调递增、绝不复用**；加锁（`123\.seq.lock`）防并发撞号；同素材幂等复用（输出 `REUSE:`）。
- **关键实现细节**（`scripts\new_task_dir.ps1:206-221`）：max 要**同时看目录和索引**——注释原文「目录被删（交付后用户手删）但索引还在，那个号仍然算用过——编号只增不重置，绝不复用」。
- **已用编号**：磁盘上 24 个任务目录，编号 **13–36**（13,14,15,…,36 连续无缺）。
- **索引 `123\index.tsv` 额外记了 37 与 38**：`37	892永劫无间 2026-10-17 22-33-09`、`38	893永劫无间 2026-10-18 00-18-48`（创建于 2026-10-22，目录已不在盘上）。
- **下一个可用号 = 39**（max(36, 38) + 1）。**不是 37**——照磁盘数会撞 892/893。
- 体检：`scripts\check_task_numbering.ps1`；索引回填：`new_task_dir.ps1 -Backfill`。

### A.5 文档地图

| 文档 | 作用 |
|---|---|
| `AGENTS.md`（26 KB） | 项目级铁律：环境真源与优先级、5 段固定工作流、外挂字幕禁令、编码体积、§7.1 成片双轨与收尾清理、§8.1 一整场完整战斗判据、§8.2 经验收纳机制、§9 单次 50 张图片红线 |
| `README.md`（178 行） | 入口导航 + 已装工具 + 一次标准任务的 4 个阶段 + 已交付参考任务 |
| `docs\TROUBLESHOOTING.md`（861 行，最长） | 26 个故障专题 + 「M1–M14 机器读数与仪表的坑」（squad_state 几何写死、护甲通道假阴性、银行家舍入串行、帧↔秒标定参照系、map_captions.py 贴边字幕、qa_gate.py 假 FAIL …） |
| `docs\lessons\POOL.md`（367 行） | **经验收纳唯一管理窗口**。三状态（待升级/已吸收/一次性）+「三条硬规矩」：①吸收后必须回填「吸收去向」，没写去向的不算吸收；②「教训」列以**原文标题加粗开头**（collect_lessons.ps1 的机器锚点）；③「来源」列写任务目录全名或专题文件名 → 该经验源一次闭合。2026-10-22 重整后待升级 789→0 |
| `docs\lessons\archive\864-rejected-attempt\`（154 文件） | 被否决方案的**完整证据链**（6 版 SRT + stats、acceptB/C/D、revalidate JSON），"为什么推翻它"的唯一依据 |
| `docs\lessons\STATUS-2026-10-22.md`、`AGENT-REPORTS.md`、`AI-VIDEO-TOOLS-2026-10-05.md`、`EFFICIENCY-PLAN-2026-10-05.md` | 阶段状态 / Agent 报告索引 / AI 视频工具调研 / 效率计划 |
| `docs\粗剪提示词.md`（269 行）、`docs\精剪提示词.md`（60 行） | **派活模板**：粗剪通用唯一版；冻结粗剪线之后走精剪 |
| `docs\WORKFLOW.md`、`docs\TOOLS.md`、`docs\CREATIVE_WORKFLOW.md`、`docs\PYTHON_RUNTIME_DECISION.md` | 标准工作流 / 工具安装与固定路径 / 批量成片 / Python 运行时决策 |
| `docs\agents\`（3 份） | issue-tracker（.scratch/<slug>/spec.md + issues）、domain（单上下文）、automatt 项目本地化覆盖 |
| `skills\cujian\SKILL.md` + `references\complete-combat-roughcut.md`、`roughcut-launch.md` | 粗剪规格：一整场完整战斗 R1–R3、7 路对抗审 + 第 8 种角色「删除段审计员」、e1–e5/g 合入参数 |
| `skills\jingjian\SKILL.md` + `references\deliverables-and-qa.md` 等 5 份 | 精剪规格：批次、BGM 卡点、事件特效配方、交付命名与门禁 |

---

## B. GitHub 备份覆盖审计

### B.1 `.gitignore` 全文逐条解释

文件共 **115 行**。它不是随手列的——每条都写了理由，下面按块解释。

| 行 | 规则 | 目的 |
|---|---|---|
| 1–11 | 注释块 | 记实测体积（2026-09-29：全项目 11.67 GB ＝ .video-tools 8.28 + 123 3.39 + 其余约 1 MB），宣示原则：**版本库只装"规则、脚本、配置、规格"**，成片在 `E:\Cujian导出` 与本仓无关 |
| 16 | `.video-tools/` | 工具环境 8.28 GB：venv 可由系统 Python 重建、模型权重首次运行自动下载、LosslessCut 可重装 |
| 17–20 | `*.safetensors` `*.bin` `*.pt` `*.pth.tmp` | 模型权重（faster-whisper 4.90 GB） |
| 27–35 | 注释块（**规则说明，不是规则**） | 解释 `123\README.md` 例外为何必须 `git add -f`；并写明**为什么必须写 `123/*` 而不是 `123/`**——git 不进入被排除的目录，「先排除整个目录再把里面文件捞回来」无效，`check-ignore` 会报命中 `123/` |
| 36 | `123/*` | 任务工作目录整体（2026-09-29 实测 3.39 GB：preview 1.57G / cache 1.22G / shots 587M / audio 73M）。**全文件唯一带例外的规则** |
| 37 | `!123/README.md` | 例外：取号规则是流水线入口规则，住在被忽略目录里 = 重克隆就没了 |
| 41–50 | `*.mp4` `*.mkv` `*.mov` `*.avi` `*.webm` `*.wav` `*.mp3` `*.m4a` `*.aac` `*.flac` | 视频/音频：一律不进版本库（可再生 + 单文件可达 GB 级） |
| 52–57 | `*.jpg` `*.jpeg` `*.png` `*.gif` `*.bmp` `*.webp` | 图片：9007 张分析抽帧全在 `123\`，这里再加一道保险 |
| 59–65 | `*.zip` `*.7z` `*.rar` `*.tar` `*.gz` `*.tgz` `*.iso` | 归档包 |
| 67–72 | `*.exe` `*.dll` `*.pyd` `*.so` `*.dylib` `*.jar` | 可执行与库（LosslessCut / 二进制依赖） |
| 74–79 | `*.parquet` `*.npy` `*.npz` `*.onnx` `*.ckpt` `*.pt2` | 数据大文件 / 模型中间格式。**副作用：`analysis\*.npy`（如 `33.887/analysis/scan_sigs.npy` 2.3 MB）因此不入库——可再生，可接受** |
| 82–96 | `*.log` `*.tmp` `*.temp` `*.bak` `*.old` `*.orig` `*.rej` `*~` `*.swp` `*.swo` `Thumbs.db` `desktop.ini` `.DS_Store` `ehthumbs.db` `$RECYCLE.BIN/` | 临时与中间产物 + 系统垃圾 |
| 99–101 | `__pycache__/` `*.pyc` `*.pyo` | Python 字节码（编译产物，不是源码） |
| 105 | `.dsh-ops/` | harness 运行锁目录（0 字节 lock），随 harness 存在而存在 |
| 107–115 | 结尾注释块 | **反向清单**：`*.py` `*.ps1` `*.sh` `*.md` `*.json` **必须**入库，禁止加进忽略列表；唯一例外是 `assets\` 下的真实素材（要用 `git add -f` 或 Git LFS） |

**观察（一致性缺口）**：`*.err` **不在**忽略列表里，而同源的 `*.log` 在——所以 `.scratch/aivideo/bench/out` 里 138 个 `.log` 被忽略、**140 个 `.err` 全部入库**（见 §C 第 6 条）。

### B.2 已跟踪覆盖（`git ls-files` 计数）

```
$ git ls-files | wc -l
587

scripts/              33      # 14 .ps1 + 14 .sh + 5 .py
docs/                176      #   根 8 + agents 3 + lessons 165
docs/lessons/        165
docs/agents/           3
skills/               40
config/                1      # production_dependencies.json
assets/                6      # README.md + asset_manifest.json + 4 个 .gitkeep
style_profiles/        2
feedback/              1      # feedback.schema.json
123/                   1      # 仅 README.md
123/README.md          1
123/workflow_upgrade/  0      # ← 0：AGENTS.md 引用的设计原稿一份都不在
.scratch/            321      # 占入库文件数 55%
根目录文件              6      # .gitattributes .gitignore AGENTS.md IMAGE_LIMIT.md README.md opencode.json
```

**结论**：规则、脚本、配置、规格（AGENTS / README / docs / skills / scripts / config / style_profiles / feedback）**全部已入库，覆盖完整**。缺口只集中在两处：`123\`（1 个文件）与 `123\workflow_upgrade\`（0/15）。

### B.3 被 .gitignore 忽略、但看起来是知识资产的

```
$ git status --ignored --porcelain | wc -l
172
$ git status --ignored --porcelain | (按前两级目录归并) | sort -rn
    138 .scratch/aivideo/            # bench 日志
      4 docs/lessons/                # archive 里的 *.log
      3 123/                         # index.tsv、.seq.lock 等
      1 123/workflow_upgrade/
      1 .video-tools/
      1 .dsh-ops/
     24 123/<任务目录>/               # 每个任务目录一条
```

**A. 该入库的（文本证据）——实测体积**

| 资产 | 路径模式 | 实测 |
|---|---|---|
| 时间线（这段为什么留/为什么删） | `123\<任务>\timeline\*.json` | 335 文件 / **7.44 MB** |
| 外挂字幕正本 | `123\<任务>\captions\*.srt` | 106 文件 / **0.60 MB** |
| 逐局经验 | `123\<任务>\reports\workflow_notes_*.md` | **61 份，24/24 目录全覆盖**（最多的 `35.889` 有 32 份：1 主 + 1 commander + 3 commander2/3 + 28 个 `_segN`） |
| 审计/验收/门禁裁决 | `123\<任务>\reports\**\*.md`（**含二级目录**） | 2413 文件 / 37.19 MB（原报告只数顶层，是 580/9.40MB 低估的原因） |
| **高价值证据合计** | timeline json + captions srt + reports md（递归）+ reports json + workflow_upgrade + index.tsv | **3216 文件 / 50,377,512 B = 48.04 MB** |
| **e1–e5 / g 组设计原稿** | `123\workflow_upgrade\` | **14 文件 / 171.8 KB**：d1/d2/d3、e1–e5、f-render-split、g-shard-merge、merge_log / merge_log_e / merge_log_g、00_ARCHIVED |
| 编号台账 | `123\index.tsv` | 23 行；**可再生**（`new_task_dir.ps1 -Backfill`），但 37/38 那两行只存在于它里面 |

**B. 不该入库的（可再生 / 重量）**

| 资产 | 实测 | 判定 |
|---|---|---|
| `reports\tools\*.log`、`analysis\*.log`（如 `13.849/analysis/ebur128_frames.log` 8.1 MB、`21.864/reports/tools/media_filters_v1~v4.log` 各 2.7 MB） | `reports` 共 3243 文件 / 60.17 MB，其中 `reports/tools` 仅 115 文件却占 8.7 MB | **不该**：纯日志，结论已写进同名 md |
| `analysis` 机器读数（`squad_state*.json` 1.0–1.5 MB、`motion_per_frame.json` 2.3 MB、`*.npy`、`source_loudness.txt` 1.9 MB） | `analysis` 263 文件 / **42.17 MB** | **不该**：逐帧读数，可由源素材重算；其**结论**在 reports/timeline 里 |
| `123\<任务>\scripts_local\` 每局一次性脚本 | **995 文件 / 6.3 MB**（764 py + 97 txt + 64 sh + 16 ps1） | **边界**：能复现"这局怎么分析的"，但高度一次性、与 `skills/cujian/scripts` 有重叠。**建议不整目录入库** |
| `123\<任务>\preview` `cache` `shots` `audio` `deliverables` | 实测**已全为 0**（`cleanup_after_master.ps1` 生效）；`123\` 里残留媒体仅 **33 文件 / 4.9 MB** | **不该**：已按 §7.1 清理干净，说明清理链有效 |
| `.video-tools/` | **9.9 GB** | **不该**：可重装 |
| `.scratch/aivideo/bench/out/*.log`（138 个） | — | **不该**：bench 日志 |
| `docs/lessons/archive/864-rejected-attempt/reports/preview_media_filters_v1~v4.log` | 989 B / 1.03 MB / 1.4 KB / 0.99 MB | **不该**（可再生日志）；注意它们因 `*.log` 被忽略，**不在仓里** |

### B.4 未跟踪且未被忽略的文件

```
$ git status --porcelain --untracked-files=all | wc -l
0
```

**无。** 本报告写入前工作区**完全干净**——这同时证明 2026-10-29 01:56 那次 push 把索引里所有东西都推上去了，没有任何文件漏在 push 之外。

> 本报告 `.scratch/github-sync-backup/survey.md` 是唯一新增的未跟踪文件（写完 `git status` 会有 1 条 `??`），属预期。

### B.5 `123\` 下任务目录：哪些文本证据被跟踪、哪些整目录被忽略

**结论先行：24 个任务目录无一例外整目录被忽略（`.gitignore:36`），跟踪数 = 0。**

```
$ for d in "13.849…" "21.864…" "23.870…" "24.871…" "30.884…" "33.887…" "35.889…" "36.890…"; do git check-ignore -v "123/$d"; done
.gitignore:36:123/*	"123/13.849永劫无间2026-08-29 00-06-20"
.gitignore:36:123/*	"123/21.864永劫无间 2026-09-30 02-57-13"
.gitignore:36:123/*	"123/23.870永劫无间 2026-10-03 19-08-41"
.gitignore:36:123/*	"123/24.871永劫无间 2026-10-03 19-50-06"
.gitignore:36:123/*	"123/30.884永劫无间 2026-10-09 18-12-51"
.gitignore:36:123/*	"123/33.887永劫无间 2026-10-15 00-17-51"
.gitignore:36:123/*	"123/35.889永劫无间 2026-10-15 22-11-13"
.gitignore:36:123/*	"123/36.890永劫无间 2026-10-15 22-38-16"
```

抽样 8 个目录的**盘上**证据（全部未跟踪，一个都没进仓）：

| 任务目录 | 体积 | md/json/srt/csv/txt 数 | 代表证据（均未入库） |
|---|---|---|---|
| `13.849永劫无间2026-08-29 00-06-20` | 14 MB | 210 | `reports/accept_849_v4.md`、`reports/accept_849_v5.md`、`timeline/combat_episodes_v8.json`、`timeline/program_map_v8.json`、2 份 SRT |
| `21.864永劫无间 2026-09-30 02-57-13` | 9.5 MB | 83 | `reports/selfaudit_864_v1.md`、`reports/workflow_notes_21.md`、`timeline/combat_episodes_v1/v2.json`、4 份 SRT |
| `23.870永劫无间 2026-10-03 19-08-41` | 9.0 MB | 266 | `reports/selfaudit_870_v6.md`、`reports/workflow_notes_23.md`、`timeline/combat_episodes_v1/v2.json`、6 份 SRT |
| `24.871永劫无间 2026-10-03 19-50-06` | 2.5 MB | 93 | `reports/accept_24_v4_AB.md`、`reports/accept_24_v4_CD.md`、2 份 workflow_notes、4 份 SRT |
| `30.884永劫无间 2026-10-09 18-12-51` | 2.3 MB | 88 | `reports/accept_30_v4.md`、`reports/accept_30_v5.md`、`timeline/combat_episodes_v1/v2.json` |
| `33.887永劫无间 2026-10-15 00-17-51` | 13 MB | 360 | `reports/accept_33_v5_A.md`、`reports/accept_33_v5_B.md`、`timeline/combat_episodes_v1.json` + `v1draft.json`、8 份 SRT |
| `35.889永劫无间 2026-10-15 22-11-13` | 16 MB | 371 | `reports/accept_34_v4_B.md`、`reports/accept_34_v4_C.md`、32 份 `workflow_notes_35*.md` |
| `36.890永劫无间 2026-10-15 22-38-16` | 5.3 MB | 155 | `reports/accept_35_v3.md`、`reports/accept_35_v5.md`、`timeline/combat_episodes_v1/v2.json` |

**24 个目录合计**：`md/json/srt/csv/txt` 共 **3954 文件 / 83.7 MB**（其中高价值证据 48.04 MB，见页首更正块），残留媒体 33 文件 / 4.9 MB，总计 134 MB，**入库 0 文件**。

### B.6 体积

```
$ git ls-files | (逐个 stat) | awk '$1 > 1048576'
(none)                                    # >1MB 的已跟踪文件：一个都没有

$ git ls-files | (逐个 stat) | sum
9184001 bytes (8.76 MB)                   # 全部已跟踪内容只有 8.76 MB

# 200KB~1MB 区间的只有 4 个，全在 .scratch/aivideo/：
  588.82 KB  .scratch/aivideo/clip90_d2.stats.csv
  587.74 KB  .scratch/aivideo/clip90_d4.stats.csv
  576.65 KB  .scratch/aivideo/clip_90s.stats.csv
  246.58 KB  .scratch/aivideo/probe_90s.csv
```

| 位置 | 体积 | 是否入库 | 证据 |
|---|---|---|---|
| `.git` | **8.7 MB** | — | 与 tracked 8.76 MB 自洽（无历史膨胀） |
| `.video-tools` | **9.9 GB** | 忽略 | `git check-ignore -v .video-tools/venv/Scripts/python.exe` → `.gitignore:16:.video-tools/` |
| `123\` | 134 MB | 忽略 | `.gitignore:36:123/*` |
| `.scratch` | 5.7 MB | 部分入库 | 321 tracked |
| 全工作区 | **10 GB** | 8.76 MB 入库 = **0.09%** | `du -sh .` |
| `E:\OBS` | **60 GB / 65 文件** | **不在仓内**（另一块盘） | 仓内路径全为相对路径：`git ls-files | grep '^[A-Za-z]:'` 无命中 |
| `E:\PR导出` | **376 GB / 87 文件** | 同上 | 同上 |
| `E:\Cujian导出` | **69 GB / 42 文件** | 同上 | 同上 |

**结论：10 GB 工作区产物与三块 E 盘媒体（60+376+69 = 505 GB）全部在仓外，无一进 git。**已入库内容 8.76 MB，**没有一个超过 1 MB 的文件**。

### B.7 push 暴露风险：已跟踪文件里的凭据/密钥痕迹扫描

**扫描方式**：① `git grep` 只扫**已跟踪**文件（清点树）；② `git log -p --all --diff-filter=AM` 扫**全部 49 个提交的增量**（历史里加过又删掉的也算暴露）。

**① 凭据类 —— 全部 0 命中**

```
$ git grep -n -I -E 'ghp_[A-Za-z0-9]{20,}|gho_…|github_pat_[A-Za-z0-9_]{20,}|glpat-…|sk-[A-Za-z0-9]{20,}|AKIA[0-9A-Z]{16}|AIza…|xox[baprs]-…' -- .
(no match)

$ git grep -n -I -E 'BEGIN [A-Z ]*PRIVATE KEY|BEGIN OPENSSH PRIVATE KEY|BEGIN RSA PRIVATE KEY' -- .
(no match)

$ git grep -n -I -i -E '(password|passwd|pwd|secret|api[_-]?key|access[_-]?key|auth[_-]?token|bearer)[[:space:]]*[=:][[:space:]]*[^[:space:]]{6,}' -- .
(no match)

# 全历史（49 提交）增量扫描
$ git log -p --all --diff-filter=AM --unified=0 | grep -E '^\+' | grep -v '^+++' | grep -E 'ghp_|github_pat_|sk-|AKIA|PRIVATE KEY|xox'
(空)
```

**② 私网地址 / 手机号 / 身份证 / 邮箱**

```
$ git grep -n -I -E '\b(10\.|192\.168\.|172\.(1[6-9]|2[0-9]|3[01])\.)…' -- .
(no match)

$ git grep -o -E '\b[0-9]{1,3}(\.[0-9]{1,3}){3}\b' -- .        # 任何 IP
.scratch/aivideo/08-local-vlm.md:56        opencv-python 5.0.0.93        ← 版本号，非 IP
.scratch/aivideo/08-local-vlm.md:357,372   127.0.0.1
.scratch/aivideo/11-asr.md:271             nvidia-cudnn-cu12 9.24.0.43   ← 版本号，非 IP
.scratch/aivideo/11-asr.md:339,357,361     127.0.0.1
.scratch/image-budget/*.md                 127.0.0.1（多处）

$ git grep -E '[^0-9]1[3-9][0-9]{9}([^0-9]|$)' -- .          # 手机号
(命中 20 行，全在 .scratch/aivideo/clip_90s.stats.csv，是逐帧时间戳/浮点数，误报)
$ git grep -E '[^0-9][1-9][0-9]{16}[0-9Xx]([^0-9]|$)' -- .   # 身份证
(no match)
$ git grep -o -E '[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}' -- .   # 邮箱
(no match)
```

**③ 真正需要关注的"暴露面"（不是密钥，是本机环境指纹）** —— 以下已随 2026-10-29 01:56 push 公开：

| 文件:行 | 内容 | 判定 |
|---|---|---|
| `.scratch/image-budget/07-proposals.md:215-219` | opencode-cli 路径 `C:\Users\Administrator\AppData\Roaming\ai.opencode.desktop\cli\2.0.22\opencode-cli.exe`、PID 30816、本地服务 `127.0.0.1:49374`，以及「/api/* 需 HTTP Basic，用户名 opencode，**密码取自** C:\Users\Administrator\.config\opencode\service.json 的 password 字段」 | **不是凭据**（只写"从哪取"，没写值），但**描述了一台机器上本地服务的认证方案**。公开无害、但没必要 |
| `.scratch/efficiency/s1_overview.py:2` 等 6 个 py | 硬编码 `C:\Users\Administrator\AppData\Local\Temp\opencode\ts_raw.json` | 暴露 Windows 用户名 Administrator 与本机临时目录布局。**低危** |
| `.scratch/aivideo/13-orchestration.md:182` | `C:\Users\Administrator\.local\share\opencode\opencode.db = 14.30 GB` | 同上 |
| `.scratch/aivideo/18-case-studies.md:103-104` | `C:\Users\Administrator\AppData\Local\naraka-toolkit-updater\installer.exe`、Naraka Toolkit 安装目录名（含乱码字节） | **低危**：第三方工具名，无凭据 |

**④ git 身份**：`git log --format='%an <%ae>'` → **49/49 提交均为** `zinc <136944065+zkkk9555@users.noreply.github.com>` —— 用的是 **GitHub noreply 邮箱，个人邮箱未泄露**。remote URL 内**不含 token**（`https://github.com/zkkk9555/yongjiewujian.git`）。

**⑤ 历史里曾经存在、现已删除的可疑文件**（仍在公网历史里；逐一看过内容，均无害）：

| 路径 | 删除于 | 内容 | 判定 |
|---|---|---|---|
| `bagY.txt`（6,469 B） | `1dbcf91` 2026-10-01 | ffmpeg `signalstats.YAVG` 逐帧日志 | 垃圾（shell 重定向手滑产物），无害 |
| `-`（187,387 B） | `d8289dd` 2026-10-06 | libvmaf 输出 JSON（`"version":"2b2cf9c"` …） | 垃圾，无害 |
| `=ro`（0 B） | `fc2364c` 2026-10-05 | 空文件 | 垃圾，无害 |
| `skills/ask-matt/`、`skills/autopilot/`、`skills/naraka-highlight-studio/` 等 | 多个提交 | 旧 skill 正文（已迁出/归档） | 设计内容，无害 |

---

## C. 风险与建议（10 条）

1. **【已发生】push 已经推完了，别重复决策。** `origin/main` 于 2026-10-29 01:56:41 被推至 `3febfb9`，`git ls-remote` 活查一致，`origin/main..HEAD` = 0。Lead 若还需动作，只剩「要不要把这些知识资产补进仓」与第 2 条。
2. **【已发生·不可撤回】仓库是 public，刚推的 393 个文件变更已公网可见。** 其中 `.scratch\` 321 个工程档案（5.7 MB）含本机 Windows 用户名、临时目录布局、本地服务端口与 Basic 认证描述（`.scratch/image-budget/07-proposals.md:219`）。
   - **建议**：若不想公开，现在改 private，或改写这几处；**但注意**——即便 `git rm` 也无法从历史移除（49 提交已推），彻底清除需 `git filter-repo` + force push（破坏性，须人确认）。
   - 好消息：**没有任何真凭据**（token / 私钥 / AKIA / 密码值）进过树或历史，见 §B.7。
3. **【核心风险·push 没解决】`123\` 里约 3216 份 / 48.04 MB 文本证据完全不在版本库（Lead 更正数）。** `timeline\*.json`（"这段为什么留、那段为什么删"）、`reports\*.md`（审计/验收/门禁裁决）、`captions\*.srt`（外挂字幕正本）、61 份 `workflow_notes_*.md`（每局经验）——**重克隆后一个都没有**，而 `docs\lessons\POOL.md` 的"来源"列指的就是这些任务目录。这是"应该备份却被忽略"的最重要一类。
   - **建议**：给 `.gitignore` 加**白名单式**例外，只捞证据不捞重量：
     `123/*` + `!123/workflow_upgrade/` + `!123/*/timeline/` + `!123/*/captions/` + `!123/*/reports/*.md` + `!123/index.tsv`
     （注意 §B.1 的坑：必须排"目录里的东西"而不是排目录本身；二级目录要逐级 `!` 回捞）。48.04 MB / 3216 文件对 git 仍无压力（当前树 8.76 MB，约 5.5 倍）。
4. **【核心风险】`123\workflow_upgrade\` 14 文件 / 171.8 KB 未入库，而它是 AGENTS.md 引用的唯一设计原稿。** `AGENTS.md §8` 写「设计原稿见 123\workflow_upgrade\e1-e5」「见 123\workflow_upgrade\g-shard-merge.md」——**新克隆打开这些引用会指向不存在的文件**。这是"文档链断裂"，比丢文件更隐蔽。**优先补这一项**（体积可忽略）。
5. **【口径风险】下一个任务编号是 39，不是 37。** 磁盘最大号 36，但 `123\index.tsv` 记了 37(892)/38(893)，而 `index.tsv` 正被忽略不入库 → **重克隆后新环境算出的 max 只会是 36，会重新发出 37/38，与历史编号撞车**，违反"编号只增不重置"。
   - **建议**：`123\index.tsv`（23 行 / 5 KB 纯文本台账）**必须入库**——它正是"目录被删后编号仍算用过"的唯一依据。
6. **【该清不清】`.scratch/aivideo/bench/out` 有 140 个已跟踪的 `.err`（722,046 B = 0.69 MB），其中 11 个 0 字节，其余 596–918 B。** 是 ffmpeg 基准测试 stderr 捕获；同目录 138 个 `.log` 兄弟因 `*.log` 被忽略，`.err` 不在忽略列表所以全被提交。**不是知识资产，占入库体积 8%。**
   - **建议**：`.gitignore` 加 `*.err`，再 `git rm -r --cached .scratch/aivideo/bench/out`（写操作，需 Lead 决定）。
7. **【体积观察】`.scratch` 占入库文件数 55%（321/587）、5.7 MB。** 其中 `.scratch/aivideo` 193 文件 / 3.4 MB（本地 VLM / ASR / 渲染基准调研）。**判断：这些是知识（调研结论 + 第一手实测），该留**；但 4 个 `*.stats.csv`（576–589 KB）是原始逐帧数据，结论已写在 `.scratch/aivideo/*.md` 里，可选择性移出。
8. **【已跟踪但内容空】`assets\` 只入库了 `asset_manifest.json`（全空数组：bgm/sfx/overlays/fonts 都是 `[]`）与 4 个 `.gitkeep`。** 真实素材按设计不入库，**也就没有任何备份**。
   - **建议**：明确这是有意的（媒体过大，应在 E 盘侧另做备份），并在 `assets\README.md` 写清"这些素材的唯一副本在哪"。当前状态是"看不出有没有备份"。
9. **【文档数字会骗人·已确认】多处文档写死了会过期的数字**，尽管 `123\README.md` 自己已写「不要在这里写死具体数字」：`README.md` 说 `E:\Cujian导出` 有 16 条成片，实测 **42 文件 / 69 GB**；`README.md` 说"123 实测 2026-09-29 = 3.39 GB"，现在 **24 目录 / 134 MB**。复核时别拿它们当基线。
10. **【工程卫生】历史里有 3 个手滑产物（`bagY.txt`、`-`、`=ro`，共 194 KB）已删除但仍在公网历史里。** 内容已逐一看过：ffmpeg signalstats 日志、libvmaf JSON、空文件——**无敏感信息**，不值得为此重写历史，仅记录在案。

---

## 附：本次审计用到的命令（可复算）

```bash
git status --porcelain --untracked-files=all | wc -l          # 0
git rev-list --count origin/main..HEAD                        # 0
git ls-remote origin main                                     # 活查远端
git reflog show origin/main --date=iso                        # push 时间线
git ls-files | wc -l                                          # 587
git ls-files -- <dir> | wc -l                                 # 分目录计数
git ls-files -z | xargs -0 -n1 -I{} stat -c %s {}             # >1MB 检查 → none
git status --ignored --porcelain | wc -l                      # 172
git check-ignore -v "123/<任务目录>"                            # .gitignore:36:123/*
git grep -n -I -E '<凭据正则>' -- .                             # 0 命中
git log -p --all --diff-filter=AM --unified=0 | grep '^\+' | grep -E '<凭据正则>'   # 0 命中
git log --all --diff-filter=D --name-only --format=''          # 历史删除路径
find 123 -type f \( -name '*.md' -o -name '*.json' -o -name '*.srt' \) -printf '%s\n' | awk '{s+=$1} END {print s}'
curl -s -o /dev/null -w '%{http_code}' https://raw.githubusercontent.com/zkkk9555/yongjiewujian/main/README.md   # 200 → public
```

> 全程未执行任何 git 写操作；除本文件外未创建/修改任何文件（唯一新建目录 `.scratch/github-sync-backup/`）。
