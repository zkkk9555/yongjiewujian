# 10 · 实施规格：把 01–09 变成 5 批可以直接照着做的活

> **本轮不改任何项目文件**，唯一写入是本报告（`.scratch\oneprompt\10-batch-spec.md`）。
> **图片消耗 0 张**（AGENTS §9 未触碰）。
> **采信 01–08 的全部结论与 09 的全部裁决**，不重开调查。
> 但**我自己重跑了三处承重数字**，因为它们决定验收标准能不能落地（见 §0.2）。

---

## 0. 执行这份规格的人需要先知道的四件事

### 0.1 批数：**5 批**（不是 6 批）

09 §1 #1 裁决「wip 不做」→ 08/07 的批 6 整批删除。原 6 批变 5 批，**工作量少一整批，交付面零损失**。
被删掉的批 6 同时消掉了 08 的点头项 N2（新增「预览员」角色、改 `§2.3/§2.6/§2.8` 的 partial 禁令）——
**那一条需要点头，是因为要改用户自己立的禁令条文；不做就不用改，也就不用点头。**

### 0.2 我重跑的三处数字（与上游有出入，出入处已点名）

| 项 | 上游说法 | 我实测 | 影响 |
|---|---|---|---|
| **历史时间线回放的基线红数** | 09 §5.1 旁证：「把门禁跑在 18 份现存时间线上，**7 份**已经是红的」 | **41 份全跑，28 份 FAIL**，全部是 `no_zero_gap_pseudo_cuts`（849 v8；855 v5/v6；858 v1–v3；859 v4/v5；860 v1–v7；861 v1/v2；863 v1–v6；archive 864 v1–v5） | **决定性**。批 1 的验收标准若写成「41 份全绿」，永远达不成，会被误判成「这批坏了」。正确写法见 §1 验证标准 ② |
| **`SKILL.md` 门数** | 09 §2.9：L57 写 twelve，实测 17 | 复核无误：实测 `checks=17`，门名 17 条；L57 原文 twelve | 零成本修正，留在批 1（它是下一任 Agent 读的第一份文件） |
| **`hostile_del` 全绿** | 09 §5.1：逐场删 7 场 7/7 全绿，最大一场 233.45 s | **复核成立**。我用 `docs\lessons\examples\864_v6_combat_episodes.json` 删掉 `combat_009`（源 894.0–1127.45，233.45 s = 全片 35%）：**不登记 → `pass:true`；登记进 `deleted_intervals` 并改 `program_seconds_total` → 仍然 `pass:true fail:0`** | 这是批 1 的**证伪用例**（falsification test）。它的判据必须是「删掉一场真战斗后门禁必须变红」 |

补充实测（07 FM-02 的规模口径，与 09 §2.5 一致）：864 v6 有 8 条 `deleted_intervals`，
其中 **3 条带 strong 战斗词命中**（`[0,181)` 5 条、`[266.5,320.27)` 1 条、`[685,718.5)` 1 条）。
所以 `deleted_voice_audit` 对 v6 的期望值是「需 3 条裁决记录」，不是 1 条。
（09 §5.2 写「v6 需 1 条记录（`[0,181)`）」——那是 04 的旧词表。我用 04 自己的 strong 词表重算是 3 条。
**写进条文时用 3，且注明词表可按素材字形维护**，因为 `source_transcript.json` 繁简混排。）

### 0.3 五批的依赖关系（一条线，拆不开的地方已标）

```
批1 门 + 接线   ──┬──> 批2 工具（收编剩余脚本 + 帧轴）──> G-C3 才可上线
                   └──> 批3 提示词新增（P2 手填形态 = 批5 的回退锚点）
                                    └──> 批4 语义替换（P6 依赖批1 有门 + 批3 有派工形态）
                                              └──> 批5 状态机（P2 手填形态在此被脚本取代）
```

### 0.4 三条贯穿全部五批的硬纪律

1. **门与接线必须同批**（09 §5.2 第 2 项）。任何一批结束时，不允许出现「门存在但没有脚本会调它」的中间态。
2. **每批一个 tag + 一个布尔开关**，开关落在 `config\oneprompt_flags.json`（该文件**本轮新建**）。
   开关必须被回归测试 **on / off 两组都覆盖**（07 §4.3）——只测 on 分支，等于回退路径从未走过。
3. **每批开工前一次提交 + tag**，回退 = `git revert` 到 tag 之前，并写 `reports\batch_k_rollback_<date>.md`
   + 在 `docs\lessons\POOL.md` 的「⚠ 已被实测推翻」节登记一条（该节已有先例：L-052、L-057）。

---

## 1. 批 1 · 漏战从人肉兜变成脚本兜（**门 + 接线 + 预览链收编，同批**）

### 1.1 批次目标（一句话）

把「漏战」和「非法预览流进 QA」从 Agent 自觉变成脚本强制：**门、接线、渲染链收编三件事一次做完**，
使批 1 结束时不存在「门存在但没人调」的中间态。

### 1.2 为什么它必须把渲染链收编进来（这是对 08 批 1 的修正）

08 批 1 只把 `read_episode_bounds.ps1` 当接线点。**09 §2.3 已实测这条不够**：
`read_episode_bounds.ps1` 只拦 4K master，**拦不住用户真正看的那条 720p 预览链路**
（864 的 `render_preview.py`、861 的 `build_preview.py`、`build_program.py` 三者都不调 qa_gate）。
用户诉求是粗剪预览，所以**接线必须落在预览链上**。
两个预览链生产者都在 864 任务目录里（`build_program.py` 2921 B、`render_preview.py` 1799 B），
体量小、有 864 的正确版本、且**本来就该收编**（06 §2.1 已列 `build_program.py` 为必收编第一项）。
→ **把这两个文件从批 2 提前到批 1**，批 2 只剩 `map_captions.py` + `capture_frames.py` + 帧轴 + 字幕门。

同时把 `voice_index.py`（864，1383 B）从「06 未列入」提到批 1：
**09 §2.8 判定 G-C2 必须拆三件（门本体 / 索引脚本 / 署名模板），缺②时①对新任务静默失效——
静默失效比 FAIL 更危险。** 所以索引生产者必须与门同批。

### 1.3 具体改哪些文件（一行一条）

| # | 文件 | 改什么 |
|---|---|---|
| 1 | `skills\naraka-highlight-studio\scripts\episode_geometry.py` | 新增 `COVERAGE_TOLERANCE_SECONDS = 0.25`（**唯一容差真源，无 timeline 覆盖字段**）与 `coverage_gaps(document, episodes) -> list[tuple[float,float,float]]`：合并 `episode 原始范围 ∪ deleted_intervals` 后与 `[0, source_duration]` 求差，返回 `(gap_start, gap_end, gap_len)` 列表。模块 docstring 追加一句：容差 0.25 是**预防性下限**，不是回归结果（41 份实测 worst_gap=0.000） |
| 2 | `skills\naraka-highlight-studio\scripts\qa_gate.py` | ① `load_timeline()` 增加返回 `(document, episodes, deleted_intervals)`；② 新增 `gate_coverage_complete(document, episodes, deleted)` → **FAIL**（有 `source_duration` 且存在 gap > tol）/ **WARN**（无 `source_duration`）；③ 新增 `gate_deleted_voice_audit(deleted, voice_index, audit_records)` → 缺席审查门：**命中 strong 词且无署名裁决记录 = FAIL，有记录一律 PASS 不看结论**；④ 新增 `gate_deleted_audit_evidence_present` → 默认 WARN，`--automation-mode` 升 FAIL；⑤ 新增 CLI `--voice-index` / `--deleted-audit`（可重复）/ `--automation-mode`；⑥ 三门插在 `if episodes:` 块**首行**（先判漏战再判重叠）；⑦ 模块 docstring 写入 04 §4 那条铁律：**FAIL 的唯一合法理由是「该有的纸没落盘」，绝不是「机器认为这里有战斗」** |
| 3 | `scripts\read_episode_bounds.ps1` | 加 `coverage_complete` **判空 + 自算**（约 18 行）：顶层 `coverage_complete -ne $true` 直接 `[FAIL] exit 1`；且**自己算一遍覆盖**（合并区间游走，比 `source_duration`，tol 0.25）——**不许只信顶层那个字段**。这是唯一不可逆伤害（4K 成片）发生的一格 |
| 4 | `scripts\test_insegment_holes.sh` | 新增 fixture：**同一份 hostile JSON 喂给 Python 与 PowerShell 两侧，断言两侧对覆盖的判定逐字一致**。这是 Python/PowerShell 双实现的防漂移回归（沿用该文件既有模式） |
| 5 | `scripts\build_program.py`（**新建，从 `123\21.864…\reports\tools\build_program.py` 搬**） | ① `sys.path.insert(0, r"C:\Project\…")` → `Path(__file__).resolve().parents[1] / "skills" / …`；② 裸 `sys.argv[1:4]` → `argparse`；③ 合流 861 的 `fix_paths.py` 为 `--fix-probe-paths`；④ **写 `program_map.json` 前调用 `qa_gate.py --automation-mode`，有 FAIL 则 exit 2，一个字节都不写**（README 风格：`recomputed` 对不上即报错，不猜哪条对） |
| 6 | `scripts\render_preview.py`（**新建，从 864 的搬**） | ① `argparse`（`--cq` / `--width` / `--height` 默认值**不得来自 864 单局观测**，FM-19）；② **渲染前必须存在同目录 `qa_gate` 报告且 `fail==0`**，缺则 `exit 2` 并打印「先跑 qa_gate」；③ 渲染后 ffprobe 自检解码 + 时长与 `PROGRAM=` 比对；④ 输出 `reports\preview_build_vN.json` 含 `gate_report` 路径与 sha1 |
| 7 | `scripts\voice_index.py`（**新建，从 864 的搬**） | `argparse`；词表外置为 `config\combat_voice_terms.json`（**理由**：`source_transcript.json` 繁简混排，09 §2.7 实测全简体词表命中 4/7、全繁体只命中 2/7）；输出 `schema: naraka-voice-index/v1` + 每条 `combat_hits` / `loot_hits` / `glyph_profile` |
| 8 | `config\oneprompt_flags.json`（**新建**） | `{"coverage_gate": false, "deleted_voice_audit": false, "automation_mode": false}` —— **稳定前默认 off**。条文里**不许写死「某门是 WARN」**，只写「按开关判定」 |
| 9 | `scripts\test_whole_battle_gates.sh` | 从 8 个 fixture 扩到 **13 个**（新增 5 个，见 §1.4） |
| 10 | `scripts\check_task_hygiene.ps1` | 加一条 INFO：`timeline\*-island-*.json` 残留提示（island 已被 `coverage_complete` 门取代，不需要独立门） |
| 11 | `skills\naraka-highlight-studio\SKILL.md` | ① L57 `twelve QA gates` → `twenty QA gates`（17 + 3 新门 = 20；**必须同批改，否则又是一份错的真源**）；② L47 后加一行 `references/one-shot-playbook.md` 指针（**指针先落，文件在批 3 建**——指向不存在的文件比没有指针更坏，所以**这一行推迟到批 3**，本批只改门数）；③ Required workflow 第 9 步加一句：预览必须由 `scripts\render_preview.py` 产出，且它会拒绝无门禁报告的输入 |
| 12 | `skills\naraka-highlight-studio\references\complete-combat-roughcut.md` | 记录 `coverage_complete` 的定义与 tol=0.25 的理由（预防性下限），供下一任 Agent 查 |
| 13 | `docs\lessons\POOL.md` | 「⚠ 已被 08 号 Agent 实测推翻」节**新增一条**：`frame_calibration.md` 的 `+28 帧` 应为 **`+29 帧`，且该常数随输出 fps 变**（`fps=1 → +29`，`fps=2 → +14`；09 §1 #8 实测四点全部字节级命中 n=29）。**L-052 的错误结论已入库，必须当场打上「已被实测推翻」，否则批 2 建的正确脚本会被下一任 Agent 绕过** |

### 1.4 回归用例（`test_whole_battle_gates.sh` 新增 5 个，缺一不算落地）

| # | fixture | 期望 | 为什么必须有 |
|---|---|---|---|
| **F9** | 864 v6 原样 | `coverage_complete` **PASS** | 阳性对照（FM-14：没有阳性对照 = 把「没人查」变成「报了绿」，后者更危险） |
| **F10** | 删 `combat_009`（233.45 s）、**不补** `deleted_intervals` | `coverage_complete` **FAIL** | **证伪用例**。今天它是 `pass:true` |
| **F11** | 删 `combat_009`、**补** `deleted_intervals`、改 `program_seconds_total`（= `hostile_del`） | `coverage_complete` **PASS**（缺口已声明，正确）但 `deleted_voice_audit` **FAIL**（`[894, 1127.45)` 内 33 条 cue / 7 条 strong 命中，无署名记录） | **整套设计的核心自证**：单靠覆盖门不够，正是 G-C2 把它抓住。必须在 CI 里跑 |
| **F12** | F11 + 一份 `deleted_audit_v1.md`（结论写「无战斗」也算） | `deleted_voice_audit` **PASS** | 证明它是**缺席审查门**不是「缺席战斗门」，对正确的自动化零误报 |
| **F13** | 顶 `coverage_complete:false` 或缺该字段的 island 形态 JSON | `read_episode_bounds.ps1` **exit≠0** | 03 §A.4 第 4 闸；也是不可逆伤害那一格的护栏 |

外加 `test_insegment_holes.sh` 的双实现一致性用例（§1.3 #4）。

### 1.5 验证标准（可执行）

```powershell
# ① 13 个 fixture 全过（F10/F11 是核心，必须实跑）
& 'C:\Program Files\Git\bin\bash.exe' 'C:\Project\永劫无间\scripts\test_whole_battle_gates.sh'
#    期望末行：RESULT: PASS
& 'C:\Program Files\Git\bin\bash.exe' 'C:\Project\永劫无间\scripts\test_insegment_holes.sh'

# ② 41 份历史时间线回放 —— 判据是「coverage_complete 自己零 FAIL」，不是「全绿」
#    （今天已有 28 份因 no_zero_gap_pseudo_cuts 红着，见 §0.2）
#    期望：coverage_complete 新增 FAIL 数 = 0；deleted_voice_audit 在 automation_mode 下新增 FAIL 数 = 已知且逐条指名

# ③ 门数自检：改动后实测 checks 数必须等于 SKILL.md 里写的数
& 'C:\Project\永劫无间\.video-tools\venv\Scripts\python.exe' `
  'C:\Project\永劫无间\skills\naraka-highlight-studio\scripts\qa_gate.py' `
  'C:\Project\永劫无间\docs\lessons\examples\864_v6_combat_episodes.json' `
  --output "$env:TEMP\gate_count.json"
#    期望：checks = 20（17 + coverage_complete + deleted_voice_audit + deleted_audit_evidence_present）
#    且与 SKILL.md L57 的数字逐字一致

# ④ 开关两组都跑：coverage_gate=false 时 coverage_complete 必须降 WARN 且代码路径被走到
#    （on/off 两组都必须进回归，否则回退路径没人走过）

# ⑤ 渲染链拒绝无门禁输入：删掉 qa_gate 报告后跑 render_preview.py → 必须 exit 2，一个字节都没渲

# ⑥ 离线图片预算：本批零看图。批 2 才有（见 §2.5）
```

**验收判据的诚实写法**：这一批**不能用「41 份全绿」验收**。正确判据是
「`coverage_complete` 在 41 份上零 FAIL，且 F10/F11 两个证伪用例变红」。
若有人把它写成「全绿」，这一批会被一个**与本批无关的既存缺陷**（28 份 `no_zero_gap_pseudo_cuts`）
永久卡住，然后被误判成「这批坏了」→ 按 §1.6 回退 → 白做。

### 1.6 回退点

- tag `oneprompt/b1`；开关 `coverage_gate=false` / `deleted_voice_audit=false` → 三门降 WARN，**代码留着当 `measured` 输出**（不删）。
- 收编的三个脚本：`git revert` 即回到「旧脚本在任务目录原地」的状态，**不破坏任何历史任务**。
- 回退后必须跑一次只读回放：`test_whole_battle_gates.sh`（原有 8 个 fixture）+ 41 份 `coverage_complete` 零 FAIL。
- **回退判据（07 R1/R2）**：① 交付被用户否决且否决理由落在覆盖门射程内 → 1 次即降 WARN 并重新设计，**不是加更多门**；② 新门 2 局内造成 ≥1 次假 FAIL 且定位 >30 min → 降 WARN。
- **这一批坏掉的方向是安全的**（只加严，坏掉 = DEGRADED，不会错交付）。全套五批里只有它具备这个性质。

### 1.7 是否需要用户点头

**否**（只加 FAIL 条件、不放宽、不改交付格式、不改任何角色职责；收编脚本只读输入、幂等、三路求和不一致就报错）。
**但需通知 2 件事**：① 回跑 41 份后若 `coverage_complete` 有任何一条 FAIL，那是「发现了一个已交付成片的漏战」，
性质从「加个门」升级为「要开一轮复审」——**必须提前说，不能等门禁报红再解释**；
② 预览链现在会**拒绝**没有门禁报告的输入，也就是说过去能渲出来的某些预览现在渲不出来（这是收紧，不是故障）。

---

## 2. 批 2 · 把「23 个共享脚本全在读、却没有一个在写」补上 + 拔掉一个已入库的错结论

### 2.1 批次目标（一句话）

补上剩余两个生产者脚本，**并把帧轴标定从「复制一个已知错误」换成「每局执行的断言」**。

### 2.2 具体改哪些文件

| # | 文件 | 改什么 |
|---|---|---|
| 1 | `scripts\map_captions.py`（新建，从 **864 那份 5095 B** 搬，**不是 861 的 `map_captions_v2.py` 19596 B**） | 只把 `sys.argv` 换成 `argparse`；合流 864 的 `fix_srt_gaps.py` 为 `--fix-gaps`；`--max-cps` 由转写语速 p95 推导，**不得写死 864 的观测值**（FM-19）；`stats.json` 必须输出丢弃率。**逻辑一行不动**——它是 5 份里唯一正确的一份（09 §2.1 已确认字节数张冠李戴） |
| 2 | `scripts\capture_frames.py`（新建，无成品） | 四模式：`strip` / `point` / `proxy` / **`calibrate`**。硬约束：`--input` 必须显式传（脚本不猜）；`--len ≥ --step + 1` 不足即 `[FAIL]`（保证邻段可见，防切在段界上）；**文件名即真源秒** `t<真源秒6位毫秒>__<src\|proxy>_<源帧号9位>`，真秒取自标定结果，**不是 `-ss` 参数值** |
| 3 | `--mode calibrate` 的实现 | 基准**必须与被测路径无关**：用帧号 / 容器 PTS（`showinfo` 的 `pts_time`、`-copyts`、或已知帧数反推），**不得用「`-ss T` 抽的帧」当基准与编号帧算 PSNR**——那是循环论证（864 L-052 的病根）。判据是 **`best_mae == 0.000`**；次优 MAE 只作可辨识度报告，< 1.0 输出 `LOW_CONFIDENCE` 而非 FAIL（**不要用「次优 > 3×」当判据**，08 §6.5 实测静态画面上会误杀一次完全正确的标定） |
| 4 | `skills\naraka-highlight-studio\scripts\qa_gate.py` | 加 `subtitle_bodies_are_text` **双边断言**：正文必须**等于**权威源 `transcript.json` 某条 cue 的文本（规范化后相等）**且**非纯数字。**不得照搬 864 `freeze_kit.py` L126 的单边版**——它逮不住「正文被换成另一段非数字文字」（06 §2.2.1） |
| 5 | `skills\naraka-highlight-studio\scripts\qa_gate.py` | 加 `episode_head_engagement`（G-C3），**前置 `frame_axis.verdict == CONFIRMED`，否则整门 SKIP + WARN**（09 §1 #8）。FAIL 阈值钉在 `off ≤ 0.0`（0.5%），`≤0.5` 仅 WARN（16/404 场次落在 0.5 内，含 859 已验收的 `combat_009`），且 FAIL 条件是「缺 `head_adjudication` 记录」不是「off 小」 |
| 6 | `scripts\check_task_hygiene.ps1` | 加 BOM 扫描（`scripts\*.ps1` 含非 ASCII 但无 UTF-8 BOM 即 WARN，理由见 AGENTS §1） |
| 7 | `AGENTS.md` | 新增一条硬规矩：**任务目录里的脚本被复用第二次必须收编进 `scripts\`**（06 §6.3 背书）。**这条必须先写，它管住 FM-20（收编后旧脚本仍在原地，新会话仍会拿到旧的）** |
| 8 | `123\21.864…\reports\frame_calibration.md` | **加一行勘误**：映射结论的偏移是 **+29 帧且随输出 fps 变**，原文的误差自证是循环论证。**这份文件是历史证据，正文不改，勘误加在末尾** |

### 2.3 验证标准

```powershell
# ① 五份历史时间线（855 / 859 / 860 / 861 / 864）重跑 build_program.py，
#    program_seconds_total 与历史答案一致 —— 不是「864 那份通过」
#    注意：build_program.py 在批 1 已收编，这里只是加 fixture 覆盖
# ② L-046 真/假 SRT fixture 重跑 map_captions.py → stats.count 一致且无一条 cue 跨切
#    （真/假两份：864 的 captions\21-review-v1.srt 是「正文=序号」事故的现场）
# ③ 帧轴：≥2 素材 × ≥4 探针 → best_mae == 0.000 且四点偏移帧级一致
# ④ FM-18 fixture：981.8 s 素材按 1152.233 s 规划 → 必须 FAIL，不得渲 11 段
# ⑤ G-C3 在 frame_axis.verdict != CONFIRMED 的 fixture 上必须 SKIP + WARN，不得 FAIL
#    （07 FM-16 的防护）
```

### 2.4 回退点

- tag `oneprompt/b2`；**删三个文件即可**（旧脚本本来就在原地，不破坏任何历史任务）。
- 开关：`automation_mode=false` → G-C3 整门 SKIP。`subtitle_bodies_are_text` 是纯增益，坏掉只是少抓一类错。
- 帧轴标定若 LOW_CONFIDENCE：**不是回退理由，是降级理由**——按 07 C6 打 `DEGRADED` 并在缺口节点名。

### 2.5 是否需要用户点头 / 图片预算

**点头：否。**
**图片预算**：本批验证会真的抽帧。**动手前先跑**
`scripts\check_image_budget.ps1 -ImageDir <帧目录> -AlreadySeen <历史已看数>` 打印分轮计划，
**单轮新增 ≤ 10 张、累计 ≤ 50 张**（AGENTS §9）。
帧轴验证**只看联系表**（一表计 1 张），四探针 × 2 素材 = 8 张联系表 = 8 张图，安全。

---

## 3. 批 3 · 提示词纯新增（只做加法）+ 让编排剧本真的能被找到

### 3.1 批次目标（一句话）

把 05 的 P1 / P2 / P5 三块**纯新增**文本落进提示词，并新建 `references\one-shot-playbook.md` + **两处指针**。

### 3.2 具体改哪些文件

| # | 文件 | 改什么 |
|---|---|---|
| 1 | `docs\粗剪提示词.md` | 插 **P1**（派工形态与回退声明），锚点：L91 `═══ 派工时必须包含 ═══` 之前 |
| 2 | `docs\粗剪提示词.md` | 插 **P2**（台账），锚点：L123 之后 / L125 `═══ 不可违反 ═══` 之前。**表头就 11 列**（`路 \| 区间(源秒) \| 类型 \| 状态 \| 派工时间 \| 心跳 \| 回收时间 \| 尝试 \| 父路 \| 报告路径 \| 下一步`），**只列名字、不列个数**（09 §1 #5：02 的小标题写「12 列」、表体是 11 列；凭空写「12」就是造第三个数）。末段：「如果盘上有 `scripts\taskstate.ps1` 就靠它维护台账，不要手填，不要另建第二份表」 |
| 3 | `docs\粗剪提示词.md` | 插 **P5**（续剪健康度三查），锚点：L117 之后 / L118「版本号接着往后排」之前 |
| 4 | `docs\粗剪提示词.md` | L46–48 第 3) 步加**三行指针**：声明 `one-shot-playbook.md` 是执行顺序剧本、`roughcut-launch.md` 是规则与阈值本身，**数字一律回 `roughcut-launch` 查**。这 3 行不含任何一条步骤，是索引不是副本 |
| 5 | `skills\naraka-highlight-studio\references\one-shot-playbook.md`（**新建**） | 阶段表：PREFLIGHT → PROBE → TRANSCRIBE → PROXY → SCENE → FRAMES → DISPATCH → SCAN → MERGE_PARTIAL → RENDER_PREVIEW → SELF_AUDIT → ADVERSARIAL → ACCEPT → FREEZE_GATE → REWORK ⟲ → DELIVER_MASTER → CLEANUP → DONE。每阶段写**进入条件**与**卡住时的下一跳**，每跳指向 `roughcut-launch §X`。**零数字阈值** |
| 6 | `skills\naraka-highlight-studio\SKILL.md` | L47 之后加 playbook 指针行（**与 #4 同批**——L39–47 是白名单式路由表，开头写 `only`，没列的文件等于不存在） |
| 7 | `AGENTS.md` §8 | 指向剧本时说清分工：**规则变更和顺序变更频率不同，不要塞进同一文件**（848/861/864 三局反复调过规则，顺序却稳定） |

### 3.3 验证标准（五条 grep，全过才算落地）

```powershell
# 1) 编排词仍然 0 命中（编排没被塞进提示词）
Select-String 'docs\粗剪提示词.md' -Pattern '扫描员|修线员|复验员|单写者|segNb'
# 2) 阈值仍然 0 命中（提示词没造第二份真源）
Select-String 'docs\粗剪提示词.md' -Pattern '\d+\s*(轮|路上限|秒/路)'
# 3) 中断语仍然 0 命中（不打断用户）★ 最看重的一条：把用户那句硬约束变成可回归的测试
Select-String 'docs\粗剪提示词.md' -Pattern '向我确认|问问我|要不要我|请确认'
# 4) 剧本零数字阈值
Select-String 'skills\naraka-highlight-studio\references\one-shot-playbook.md' -Pattern '\d+\s*(秒|轮|路|张|分钟)'
# 5) 剧本可发现：两处指针都在
Select-String 'skills\naraka-highlight-studio\SKILL.md','docs\粗剪提示词.md' -Pattern 'one-shot-playbook'
```

### 3.4 回退点 / 点头

- tag `oneprompt/b3`；**纯散文，整段删，5 分钟。全项目最容易撤的一批。**
- **点头：否**（改的是提示词散文，而提示词本来就是用户的东西；且方向是**更不打扰**）。
- **这一批有一个不可替代的作用**：P2 的「两形态二选一（脚本不在就手填）」是**批 5 的回退锚点**——
  批 5 随时可关，因为流程那时已经能靠手填跑。
- **坏掉的后果**：最坏是 Agent 照着一个不存在的 playbook 走 → **P5 三查是它唯一有牙齿的部分**
  （能发现「已冻结但 E 盘无成片」这类静默断裂）。

---

## 4. 批 4 · 唯一的语义替换（整套方案里风险最高的一批）

### 4.1 批次目标（一句话）

改动既有条文语义：把「自己看片」改成「有人看片」、加收敛纪律、加已知缺口节、加缺料不停机预授权、
**并把冻结门 `streak≥2` 的降级档补上**（09 §1 #7：不补这条，85% 就只是修辞）。

### 4.2 具体改哪些文件

| # | 文件 | 改什么 |
|---|---|---|
| 1 | `docs\粗剪提示词.md` | **替换 L163–165**（唯一改动既有语义的一处）为 **P6**：① 义务保留（§3.7 G2/G4 的真实要求，删不得），但执行者默认是**派出去的那一路**；② **回灌禁令**——子 Agent 只能回文字报告 + 绝对路径，**禁止把抽帧/联系表/缩略图回灌进主对话**（L128 写了 50 张但没写回灌上限，这是真实漏洞）；③ 无派工能力时的回退规格（节目轴每 30 秒一张联系表，跑 `check_image_budget.ps1`，**额度优先于看完**，不够就把剩余段落写进已知缺口） |
| 2 | `docs\粗剪提示词.md` | 插 **P3**（收敛阶梯，**零数字**，全部指向 `§2.5`），锚点：`═══ 自主权 ═══` 段内 L171 之后。含「**服务重启、会话丢失、外部故障一样算用掉一次尝试**」 |
| 3 | `docs\粗剪提示词.md` | 插 **P4**（本轮即终态 + 已知缺口必列），锚点 1：`最后只报这些` 6 条之后作第 7 条；锚点 2：`交付标准` 段内 L162 之后加一行 |
| 4 | `docs\粗剪提示词.md` | 插 **P7**（缺料不停机 + 申报），锚点：`自主权` 段内 P3 那两条之后 |
| 5 | `skills\naraka-highlight-studio\references\roughcut-launch.md` | **§2.5 拆两个字段**（09 §1 #4）：`lane.report_deadline_rounds`（默认 **3** 次回收，看门狗读它）与 `lane.attempt`（硬上限 **2**，重派读它）。**不是二选一**——3 轮是「报告回来几次算超时」（扫描侧），2 是「同一路被重派几次」（编排侧），两个量纲。同时补「外部事故计入尝试」 |
| 6 | `skills\naraka-highlight-studio\references\roughcut-launch.md` | **§3.7 冻结门**：默认**仍是 `streak ≥ 2`，一个字不动**；**只在「降级交付」这一档允许 `streak ≥ 1`**，且该档必须同时打上 `DEGRADED` 标记并写进交付那一行 |
| 7 | `skills\naraka-highlight-studio\references\roughcut-launch.md` | **§3.7 加 G0 = `coverage_complete`，六门 AND**。这是**纯加严**：五门原样保留，一个字不删（与 `merge_log_g.md §2.2` 的合入纪律一致） |
| 8 | `skills\naraka-highlight-studio\references\deliverables-and-qa.md` | Freeze gate 2.0 节同步：六门 AND + 降级档 `streak≥1` + `DEGRADED` 标记要求。**生命周期表里 island / `preview\wip\` 两行删掉**（wip 不做，留着会让两文件互相矛盾） |
| 9 | `scripts\taskstate.ps1`（新建，**只做 `lane-add` / `lane-hb` / `lane-done` 三个子命令 + `images_seen` 记账**） | 供 P6 的「有人看过」提供机器检查点：`images` 子命令转发 `check_image_budget.ps1`，`lane-done -Images N` 落盘。**这是批 5 的最小前置切片**，只 3 个动词，不含状态机 |
| 10 | `skills\naraka-highlight-studio\references\complete-combat-roughcut.md` | §8.2 那条经验收纳机制的「汇总入口」指向 `docs\lessons\POOL.md` 的新一行 |

### 4.3 验证标准

```powershell
# ① 「自己看一遍/自己看片」0 命中
Select-String 'docs\粗剪提示词.md' -Pattern '自己看一遍|自己看片'
# ② 中断语 0 命中（同 §3.3 第 3 条）
# ③ **必须实跑一局真素材**，否则这一批不算验过
# ④ 实跑后检查每路 images_seen 是否真被填；「本版看片 N 段、共 M 张」这一行是否出现在交付报告里
#    —— M 异常低 = 有路在假看；M 异常高 = 50 张门要出事
# ⑤ 检查 §2.5 的两个字段真的分开了：台账里 attempt 与 report_deadline_rounds 是两个值，不是同一个数
```

**关于 `images_seen` 门的诚实说明**：08 前置 8 用「863 有 6/14 路一张图都没看」当依据，
**09 §2.4 已把这降级为待核实传闻**（14 份 seg 报告全部声明非零看图；归因脚本已随清理删除）。
**因此这条门不许用那个数字当依据**，只许用 FM-06/FM-07 的机制论证，验收判据只能是「字段真被填」。

### 4.4 回退点 / 点头

- tag `oneprompt/b4`；还原 L163–165（05 号给了逐字原文，**回退 ≈ 5 分钟**）+ 撤 §2.5/§3.7 的三处加法。
- **点头：否**，但这是五条线里风险最高的一批——它同时授权重写（FM-01）、取消「自己看片」（FM-06）、
  引入用户唯一的信息通道（FM-05）。**所以它必须在批 1+2 之后**：门在、工具在，它写下的任何东西才有人兜。

---

## 5. 批 5 · 状态机（顶层 **27** 个键，104 这个数从条文里删掉）

### 5.1 批次目标（一句话）

把「状态在人脑和散文里」变成「状态在一个脚本可读的真源里」，分 4 个小批上，
**每加一个字段必须指名「哪个触发器或哪条 verify 在读它」，指不出名就不许加**。

### 5.2 具体改哪些文件

| # | 文件 | 改什么 |
|---|---|---|
| 1 | `config\taskstate_schema.json`（**新建，字段清单的唯一真源**） | 投影列名 / `verify` 检查 / 台账模板**全部从它生成**，任何地方不得手写列名 |
| 2 | `scripts\taskstate.ps1` | 补齐 02 §6.1 的全部子命令：`init` / `resume`（固定 12 行输出）/ `verify` / `set` / `version` / `watchdog -Once\|-Start\|-Stop\|-Status` / `cleanup-check` |
| 3 | `scripts\taskstate.ps1` | **顶层 27 个键**（09 §1 #6：02 §2.1 标题写「26 个」、表体 27 行）。**「104」这个数从所有条文里删掉**——它是四份文件互相抄出来的统计量，不是契约 |
| 4 | `scripts\taskstate.ps1` | **台账是状态机的自动投影**（09 §1 #5 + 用户关键约束）。`reports\dispatch_ledger.md` 由 `lane-add/hb/done` 自动重生成，**列封闭 11 列**。`verify` 判投影列名 ≠ schema 列名 → **exit 2（不是 WARN）** |
| 5 | `scripts\taskstate.ps1` | **超时的两个字段真的分开**：`lane.report_deadline_rounds`（默认 3）喂 T2-DEADLINE 的看门狗；`lane.attempt`（硬上限 2）喂重派阶梯。T2 公式 `clamp(3 × p50(本波已回收时延), 60, 240)` 分钟，**且须本波已回收 ≥ ceil(0.5 × wave_size) 才允许开火** |
| 6 | `scripts\taskstate.ps1` | **`audit` 三态出口**（07 §3.2）：`reports\trust_audit_<序号>_v<N>.json` + `.md`，退出码 `0=DELIVERABLE / 3=DEGRADED / 4=WITHHELD`。7 项 CHECK 全部零图、只读、盘上可算：C1 无在途路 / C2 有人看过片子 / C3 冻结依据唯一且可解码 / C4 覆盖与裁决 / C5 无未校准产物 / C6 帧轴置信度 / C7 四级漏斗守恒 |
| 7 | `scripts\taskstate.ps1` | **`WITHHELD` 必须自带续跑 + 强制降级**（08 前置 6）：落盘后流程**继续跑**（看门狗不停、换路不停）→ 到 `T_witHold`（对齐 watchdog 的 `[60,240]` clamp）仍未转绿 → **强制**降为 `DEGRADED` 交付并写明「因超时降级」。**永远不存在「停在不交」这个终态**；同一局 `WITHHELD` > 2 次即强制降级 |
| 8 | `scripts\taskstate.ps1` | **`audit` 跑两次**（07 §3.3 ③）：冻结前一次（可 DEGRADED，不可 WITHHELD）→ 交付前一次（可 WITHHELD）。理由：中间的 REWORK 是新的不可信来源，**只审计一次 = 审计了一个已经不存在的版本** |
| 9 | `scripts\taskstate.ps1` | `audit` **不可被否决**（只能申诉，申诉写入报告且不改变判定）；**读不到一律当红（fail-closed），不许 fail-open**；把输入完整性（读了多少文件、哪些读不到、`delivery_state.json` 是否可解析、ffprobe 是否可用）写进结果——**审计必须能被审计** |
| 10 | `scripts\cleanup_after_master.ps1` | 在 L104 `[BLOCKED] no delivered master` **之前**插入两行状态护栏：**非 `DELIVERED` 态禁止删除 `cache\`**（860 教训：resume 实现随 `cache\` 一起没了） |
| 11 | `docs\粗剪提示词.md` | **整段删 P2**（台账手填形态），换成「台账由 `scripts\taskstate.ps1` 维护，以它的输出为准」。**是删不是改**——脚本会自己生成投影，提示词再手抄一遍就是第二份副本 |
| 12 | `docs\粗剪提示词.md` | 加 `render.auto_start_authorized` 授权位说明（**默认 false**，需用户点头后才可为 true） |
| 13 | `docs\lessons\POOL.md` | 回填：05 的 7 条提示词补丁各自的「吸收去向」列 + 状态改 `已吸收`（AGENTS §8.2 硬规矩：没写去向的不算吸收）；教训列以原文标题加粗开头（那是脚本判断是否已吸收的机器锚点） |

### 5.3 验证标准（**全部离线回放，不花实跑**）

```powershell
# ① 把 861 的历史台账 mtime 与报告 mtime 喂给 watchdog → 必须报出那 4 路 overdue
#    （seg23 / seg29 / bridge2 / bridge4，实际回收 09-30 03:05）
#    且 864 必须零误杀（02 §3.3 已回测：861 p50 24.6 → deadline 73.8 min，最慢健康路 53.6 min；
#                     864 p50 72.2 → deadline 216.6 min，最慢 144.1 min）
# ② 对 9 个历史任务目录（13–21，12.848 已被用户删除）跑 resume → 期望 STATE=MISSING，**不得 FAIL**
# ③ 「状态比盘上事实更乐观」的用例必须往保守方向落：**状态只许降级，不许升级**
# ④ 投影列名 ≠ schema 列名 → exit 2
# ⑤ audit 三态：造 DELIVERABLE / DEGRADED / WITHHELD 三个 fixture 各跑一次；WITHHELD 到 T_witHold 后必须自动转 DEGRADED
# ⑥ audit 跑两次的时点：REWORK 之后的那一次必须重新判定，不得复用冻结前那次的结论
```

### 5.4 回退点 / 点头

- tag `oneprompt/b5a` / `b5b` / `b5c` / `b5d`，各小批独立。
- 关开关 = `audit_delivery=false` / `watchdog_bg=false`。
- **因为批 3 的 P2「两形态二选一」已先落地，脚本不在时流程仍能跑 → 批 5 天然可回退**（倒序撤的第 4 位）。
- **坏掉的后果**：`resume` 失败 → **必须降级到 P2 手填形态，不许停机**。新增必经步骤越多，一次改错全盘死。
- **点头：5c 需要一次**（见 §6.2 的 N2）。

---

## 6. 需要用户点头的项（**3 项**，逐项写清）

### 6.1 N1 · `roughcut-launch.md §2.5` 的重试语义拆两个字段

- **改什么**：把现在的一句「约定轮次默认 3 轮（T0 台账写明）」拆成 `lane.report_deadline_rounds`（默认 3）与 `lane.attempt`（硬上限 2），并补「外部事故计入尝试」。
- **为什么算扩大范围**：改的是**用户自己立的条文语义**。现在的后果差别很实：861 有 3 路被服务端重启吞掉，指挥实际拖到次日 03:05，**多等 7.5 h**；把「外部事故计入尝试」写进去，就等于承认那次等待消耗了一次机会。
- **如果不同意**：不改条文，watchdog 的 T2 只能读「3 轮」这一个数，`attempt` 就没有机器真源——重派纪律退回纯散文（FM-12 的「无限重试」口子留着）。**批 5a 的其余 12 个字段不受影响，仍可上。**

### 6.2 N2 · `watchdog -Start` 后台常驻 + `render.auto_start_authorized`

- **改什么**：允许一个后台进程在用户离开后继续巡检，并允许它在满足冻结门时自动开渲。
- **为什么算扩大范围**：**对外可见 + 不可逆**——它会在用户不在场时向 `E:\Cujian导出` 写 1.4–2.6 GB，并触发收尾清理脚本删任务目录产物。
- **如果不同意**：`watchdog -Once` 单次巡检仍然可用（由 Agent 在每次工具调用时跑一次，收益小但不越界），`auto_start_authorized` 保持 false，4K 仍然只由用户明说「输出 4K 成片」触发。**其余四批全部不受影响。**

### 6.3 N3 · 冻结门 `streak ≥ 1` 的降级交付档

- **改什么**：默认仍是 `streak ≥ 2`，**只在「降级交付」这一档允许 `streak ≥ 1`**，且必须打 `DEGRADED` 标记。
- **为什么算扩大范围**：它**放宽**了 `roughcut-launch §3.7` 与 `deliverables-and-qa.md` 里用户自己设的送审门槛。07 FM-04 论证得很硬：`streak≥1` 当默认会把「一帧假信号」升格成冻结依据（864 的三个豁免全部有效且用户一次接受，但那是三个随机变量同时成立的一次样本）。
- **如果不同意**：**85% 这个数字会掉下来**，而且是掉在它唯一的支撑上（09 §1 #7：「这一条不做，01 的 90% 就是修辞」）。用户就要接受「一次交付」在多数局上做不到，得等两版零新增。**其余四批完全不受影响。**

### 6.4 需要**通知**（不是点头）的 2 项

| # | 项 | 为什么只是通知 |
|---|---|---|
| R1 | 覆盖门落地后回跑 9 个历史任务目录 / 41 份时间线 | 预期 `coverage_complete` 零 FAIL（我已独立验过 41/41，worst_gap = 0.000）。**若某份 FAIL，那是「发现了一个已交付成片的漏战」，性质从「加个门」升级为「要开一轮复审」**——必须提前说，不能等门禁报红再解释 |
| R2 | ETA 心跳默认发 | 心跳不含任何可播放产物、不含结论、不可回复交互 → 它是**通知不是请示**，不违反「不要分段汇报」（汇报有结论，心跳没有）。判据可 grep。**但它确实是新增的用户可见面**，应一次性告知并允许一键关。07 §6.5 说「只问一次，且这次的答案是关掉」——**这一点要改：不许问，默认发，用户回「不用」才关。问本身就是打断。** |

### 6.5 已被 09 消掉的点头项

**08 的 N2（新增「预览员」角色 + 改 `§2.3/§2.6/§2.8` 的 partial 禁令）不再需要点头**——因为 wip 整批不做，那三条条文一个字不动。

---

## 7. 如果只能先做一批：**批 1**，而且是它里面的 **1a**

### 7.1 最小可验证的一批（1a）

**目标**：只做「让漏战变红」这一件事，其余全部不动。

| 改什么 | 文件 | 行数量级 |
|---|---|---|
| 覆盖计算 | `episode_geometry.py` | ~25 行 |
| 覆盖门 | `qa_gate.py` | ~30 行 |
| 不可逆那一格的护栏 | `read_episode_bounds.ps1` | ~18 行 |
| 双实现防漂移 | `test_insegment_holes.sh` | ~30 行 |
| 证伪用例 | `test_whole_battle_gates.sh` 加 F9/F10/F11 | ~40 行 |

**不做**：G-C2（缺席审查门）、G-C4、三个脚本收编、`voice_index.py`、开关文件、任何提示词改动。

### 7.2 做完之后怎么知道它有没有用（**一条可证伪的判据**）

> **判据：把 `docs\lessons\examples\864_v6_combat_episodes.json` 里的 `combat_009`（源 894.0–1127.45，233.45 s = 全片节目时长 35%）删掉，
> 门禁必须从今天的 `pass:true` 变成 FAIL。**
>
> 我已实测今天它是 `pass:true fail:0 status=FROZEN_CANDIDATE`——**删掉全片三分之一的战斗，门禁给的是「冻结候选」。**
> 若 1a 做完它仍然绿，**这一批就没用**，不管测试脚本是不是 PASS。

配套的三条判据：

| # | 判据 | 期望 | 不达标怎么办 |
|---|---|---|---|
| 1 | F10（删一场、不登记） | `coverage_complete` **FAIL** | 没红 = 实现错了，不是门太松 |
| 2 | 41 份历史时间线上 `coverage_complete` 自己 | **零 FAIL**（worst_gap 实测 0.000） | 有 FAIL = 门严于真相，是**误报**，先降 WARN 再查 |
| 3 | 原有 8 个 fixture | 全过 | 回归破了 = 撤 |

### 7.3 1a 之后还剩什么（诚实清单）

1a 堵住的是**「未声明的缺口」**。它**堵不住**：声明本身是否诚实（09 §5.1 实测 G-C1+G-C2 联合仍漏 3/7）、
无台词战斗、场尾未走完、两场该分被合成、battle 内部顺序错乱。**这五类至今无判据，只能靠看片。**
**而 `qa_gate.py` 今天在交付链路上根本不会被调用**（唯一调用点是 `scripts\test_whole_battle_gates.sh` L27，一个回归测试脚本；
4K master 走 `seg_render_master.sh` → `read_episode_bounds.ps1` 不调 qa_gate；720p 预览走任务目录自己的脚本也不调）
——**1a 顺手补上的 `read_episode_bounds.ps1` 覆盖检查，是这一批里唯一真正进入交付链路的东西。**
预览链的机器强制要等 1b（收编 `build_program.py` / `render_preview.py`）。

---

## 8. 我发现的规格缺口（照着 01–09 做会做错的地方，8 条）

> 每条都给出「缺口在哪」+「补法」。**其中 G1/G2/G4 会直接改变批 1 的验收标准或代码量**。

### G1 · **回放基线是 28/41 红，不是 7/18**（09 §5.1 旁证的数字与实测不符）

我实测 41 份时间线，**28 份 FAIL，全部是 `no_zero_gap_pseudo_cuts`**（849 v8 / 855 v5,v6 / 858 v1–v3 / 859 v4,v5 / 860 v1–v7 / 861 v1,v2 / 863 v1–v6 / archive 864 v1–v5）。
09 说的是「18 份里 7 份红」，我的是「41 份里 28 份红」——分母被砍了一半，分子算错了四倍。

**补法**：批 1 验证标准 ② 必须写成「**`coverage_complete` 自己零新增 FAIL**」，
并把「28 份既存 `no_zero_gap_pseudo_cuts` 红」作为**已知既存缺陷登记在批 1 的 notes 里**，明确不归本批。
**否则这一批会被一个与它无关的既存缺陷永久卡住，然后被误判成「这批坏了」→ 回退 → 白做。**
另：09 §5.2 写「v6 需 1 条记录（`[0,181)`）」，我用 04 自己的 strong 词表重算是 **3 条**（`[0,181)` 5 / `[266.5,320.27)` 1 / `[685,718.5)` 1）。**条文用 3。**

### G2 · **`read_episode_bounds.ps1` 需要 PowerShell 侧的覆盖实现，且必须双侧 diff 测**（没人写这一格）

08/04 都说「复用 `episode_geometry`」——那只覆盖 Python 侧。但 `read_episode_bounds.ps1` 是**独立的 PowerShell 实现**（4K 链路刻意 Python-free），
它**必须自己算一遍覆盖**，否则这道门在不可逆那一格就是空的。
而项目里已经有一个现成的防漂移模式：`test_insegment_holes.sh` 就是为「同一公式两份实现」建的。
**照 01–09 照做会得到的结局是：Python 侧说 PASS、PowerShell 侧什么都没查，两边静默分家——这正是 861 的病（一个正确的 1090.5 s 渲染被判 FAIL）。**
**补法**：批 1 清单 #4（`test_insegment_holes.sh` 加一致性 fixture）**是必做项，不是可选**。

### G3 · **「机器生成已知缺口节」不能在批 1**（09 §5.2 第 4 项的批次归属有依赖倒置）

09 把「FM-05 的已知缺口节机器生成」归到批 1。但它要读 `seams[]` / `deleted_intervals[]` / 冻结态，
而这些的真源是 `delivery_state.json`——**那是批 5 才有的东西**。
**补法**：批 1 落一个**独立最小生成器** `scripts\gap_report.py`，只吃「时间线 JSON + qa_gate 报告」，
产出缺口节的三向对齐（方向 A 每个 seam 必被点名 / 方向 B 每条缺口必绑一个真实存在于 `deleted_intervals[]` 的机检锚点 / 方向 C 写「无」但 JSON 里有缝 → 判红）；
批 5 再由 `taskstate.ps1 audit` 接管并扩到 7 项 CHECK。**两者的关系必须在批 1 的 notes 里写清，否则批 5 会出现两份缺口节。**

### G4 · **wip 删掉之后，两处条文必须同步删行，否则两文件互相矛盾**

08 批 6 被 09 判「不做」，但 03 §A.5 已经把 island JSON 与 `preview\wip\` 两行写进了
`deliverables-and-qa.md` 的目录布局表和生命周期表。**只做 09 的裁决、不删这两行，
下一任 Agent 读到的就是「工作路径铁律里有 wip 目录，但没有任何条文解释它能干什么」。**
**补法**：批 1 或批 3 的清单里各加一行「删 `deliverables-and-qa.md` 的 island / `preview\wip\` 两行」
（我放在 §4.2 #8，与 §3.7 的冻结门改动同批）。

### G5 · **`images_seen` 门失去了它唯一的支撑数字，验收判据必须换掉**

08 前置 8 的论证是「863 有 6/14 路一张图都没看」。**09 §2.4 已把这降级为待核实传闻**
（14 份 seg 报告全部声明非零看图；归因脚本 `frame_pick.ps1` / `pull_frames.ps1` 已随清理删除；06 的「144/90 BOM」今天只有 11 个纯 ASCII 文件，不可复现）。
**照 08 写验收标准会得到一条无法验证的门。**
**补法**：这条门的验收判据只能是「每路 `images_seen` 真被填 + 交付报告有「本版看片 N 段、共 M 张」这一行」，
**不得引用任何历史比例数字**。且它必须与批 4 #9 的 `taskstate.ps1 lane-done -Images` **同批**（我已在 §4.2 #9 把它拆出来）。

### G6 · **9 个历史任务目录的台账不许补填**

批 3 的 P2 要求台账填真实派工/回收时刻。但 861 的台账 L151 是第二天事后补记的，863/864 连派工时间都没有——
**回填它们 = 改写历史证据**，`recycle_fill_rate` 会算出 0.0，然后被误读成「台账不可信」。
**补法**：P2 的适用范围明写「**新建与续剪的任务目录**」；历史目录一律 `STATE=MISSING`，**不得 FAIL、不得回填**
（05 §3.2 已识别，我把它升为批 5 的验收 ②）。

### G7 · **「用户拿到的第一行」没有归属批次**

08 §8 说「真正的交付物是那一行结论，不是那个 mp4」；07 §3.4 给了它的形状。**但五批里没有任何一批认领「产出这一行」**——
而它恰恰是整套改造里**唯一对用户诚实的东西**，也是唯一必须机器生成的东西（Agent 手写的这一行在用户不在场时没有任何理由认为是诚实的）。
**补法**：批 1 落 `scripts\gap_report.py`（见 G3），批 5 由 `trust_audit.md` 第一行接管。**两处都必须在 notes 里点名「这一行的真源是谁」。**

### G8 · **实施会话自己的看图预算没人算过**

AGENTS §9 是上游硬红线，**每轮持久有效**。批 2 的帧轴验证（≥2 素材 × ≥4 探针）如果按 06 §3.2 的 7 个探针点逐点看全分辨率帧，
再加批 4 的实跑一局，**很容易在「实施会话」这一层就撞线**——而撞线的后果不是报错，是**整个会话作废**（已有两个会话因此报废）。
**补法**：每一批的验证清单里都要写死「看图前先跑 `check_image_budget.ps1`，只看联系表，一表计 1 张」。
批 1 与批 3 零看图；批 2 约 8 张；批 4 的实跑必须先出预算表再派看图路。

---

## 9. 给拍板者：一屏版

```
批数        5 批（原 6 批，wip 整批删除 —— 09 §1 #1，用户侧收益恒等于 0 且收益未测）

批1  门 + 接线 + 预览链收编（同一个 commit，绝不拆）
     coverage_complete(FAIL) / deleted_voice_audit(FAIL) / deleted_audit_evidence_present
     + read_episode_bounds.ps1 覆盖自算 + 双实现 diff 测
     + build_program.py / render_preview.py / voice_index.py 收编并内建门禁调用
     + SKILL.md L57 twelve→twenty + POOL L-052 打「已被实测推翻」
     13 个 fixture；41 份回放（判据=coverage 自己零 FAIL，基线已有 28 份因别的门红着）
批2  map_captions + capture_frames + 帧轴基准整个换掉 + 字幕正文双边断言 + G-C3（前置 CONFIRMED）
批3  提示词纯新增 P1/P2/P5 + one-shot-playbook.md + 两处指针（可发现性）
批4  语义替换 P6/P3/P4/P7 + §2.5 拆两字段 + 冻结门降级档 + images_seen
批5  状态机 27 键（104 这个数删掉）+ 台账自动投影 + watchdog + audit 三态 + WITHHELD 强制降级

最小可验证   1a = 只做覆盖门（~140 行，不收编任何脚本）
怎么知道有用 删掉 864 v6 的 combat_009（233.45 s = 全片 35%）→ 今天 pass:true，1a 做完必须 FAIL。
             没红 = 这一批没用，不管测试脚本是不是 PASS。

要点头      3 项：N1 §2.5 拆两个字段 / N2 watchdog 后台常驻 + 自动开渲（对外可见+不可逆）
                 / N3 冻结门 streak≥1 降级档（放宽用户自己设的门槛；不做则 85% 掉下来）
             通知 2 项：41 份回放结果 / ETA 心跳默认发
             已消掉：08 的 N2（wip 不做 ⇒ 不用改 §2.3/§2.6/§2.8 的 partial 禁令）

回退        每批一个 tag + config\oneprompt_flags.json 一个布尔；开关必须 on/off 两组回归都覆盖。
            倒序撤：wip(已删) → 新门降 WARN → 提示词语义替换 → 状态机关开关 → 收编脚本最后撤且通常不撤。
            判据：连续 2 局更慢或交付被否决即撤当批（不是整套）。

我发现的缺口  G1 回放基线是 28/41 红不是 7/18（写错验收标准会白做）
              G2 read_episode_bounds.ps1 要自己算覆盖 + 双侧 diff 测（没人写这一格）
              G3 机器生成缺口节不能在批 1（依赖倒置）
              G4 wip 删了但 deliverables-and-qa.md 的两行要同步删
              G5 images_seen 门失去唯一支撑数字，验收判据必须换
              G6 9 个历史目录的台账不许补填
              G7「用户拿到的第一行」五批里无人认领
              G8 实施会话自己的看图预算没人算过

最诚实一句   这套改造里没有任何组件能发现语义层错误。它保证「不把没查过的当成查过的」，
             不保证「交的一定对」。真正的交付物是那一行结论，不是那个 mp4。
```