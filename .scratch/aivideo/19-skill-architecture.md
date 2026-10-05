# 19 · Skill 架构：把一套流程真正封装成「一句话 + 一套 skill」的 2026 做法

> **视角**：外部规范 + 生态 + 本项目合规审计。回答「本项目的 skill 该怎么重构」。
> **取证日**：2026-10-05 · **本报告零图片**（AGENTS §9 预算消耗 0 张）。
> **唯一写入**：本报告。未改任何项目文件。
> **上游**：`.scratch\oneprompt\{01…10}.md` 已读过 `08-final-verdict.md` 头部；本报告**不重复**它的实证，
> 只补它缺的那一层：**官方规范怎么说、生态怎么抄、以及「为什么没封装」的机械根因**。

---

## 0. 结论摘要

| # | 结论 | 依据 |
|---|---|---|
| 1 | **编排逻辑必须写进脚本，不能只写进 skill。** skill 承载**判断标准**，脚本承载**执行与状态**。 | 文档 |
| 2 | **「没封装」的机械根因找到了：skill 放在 harness 根本不扫的目录里。** `skills/` 不是 opencode 的发现路径，29 个 skill 一个都不可见。 | **实测** |
| 3 | 官方规范上限是 SKILL.md **< 500 行 / < 5000 token**。本项目 SKILL.md 105 行 —— **合规范，方向没错**。 | 文档 + 实测 |
| 4 | 官方对「长提示词」的判决很直接：**"right altitude" 是 Goldilocks zone**，两端都是失败模式。211 行提示词坐在错误那一端。 | 文档 |
| 5 | 缺的不是 evals、不是更多 references —— 是**一个可执行的 phase runner + 一个可续跑的状态文件**。 | 文档 + 生态 |
| 6 | 官方给的重构杠杆是现成的：**validation loop** + **plan-validate-execute** + **bundling reusable scripts**。 | 文档 |

**一句话架构建议**：

> 入口一句话 → 命中一个 **<150 行的编排 skill** → 它只做三件事：**按状态决定下一个 phase、调脚本、跑门禁**；
> 剪辑判断标准留在 `references/`，一切「跑多久 / 会不会死等 / 做到哪 / 怎么续」全部下沉到 `scripts/pipeline.py` + `state.json`。

---

## 1. 官方规范基线（文档）

### 1.1 Agent Skills 开放标准 —— 唯一权威规范

**来源**：<https://agentskills.io/specification>（Anthropic 明确声明规范维护在 agentskills.io，实现无关）
镜像仓库：<https://github.com/agentskills/agentskills>（`docs/specification.mdx`）

**目录结构（规范原文）**：

```
skill-name/
├── SKILL.md          # Required: metadata + instructions
├── scripts/          # Optional: executable code
├── references/       # Optional: documentation
├── assets/           # Optional: templates, resources
```

**frontmatter 只有 6 个合法字段**（`name` / `description` / `license` / `compatibility` / `metadata` / `allowed-tools`）。
多写任何一个 → 打包/上传**硬失败**，不是忽略：

```
Unexpected key(s) in SKILL.md frontmatter: argument-hint.
Allowed properties are: allowed-tools, compatibility, description, license, metadata, name
```

> **对本项目的意义**：任何「把 `disable-model-invocation` 之类塞进 frontmatter」的方案都是**不可移植**的。
> 规范 6 字段是公约数，Claude Code 私有字段只能当增强。

### 1.2 渐进式披露（progressive disclosure）—— 规范的核心原则

规范原文三级：

| 级别 | 内容 | 加载时机 | 成本 |
|---|---|---|---|
| 1 | `name` + `description` | **启动时对所有 skill 加载** | ~100 tokens/skill |
| 2 | SKILL.md 正文 | skill 被激活时 | **< 5000 tokens 推荐** |
| 3 | `scripts/` `references/` `assets/` | **按需** | 0（脚本只有 stdout 进上下文） |

规范明确两句关键约束：

- **"Keep your main `SKILL.md` under 500 lines."**
- **"Keep file references one level deep from SKILL.md."** —— 避免深层引用链。

**工程化含义（Anthropic 官方博客原文）**：
<https://www.anthropic.com/engineering/equipping-agents-for-the-real-world-with-agent-skills>（2025-10-16）

> "Agents with a filesystem and code execution tools don't need to read the entirety of a skill into their
> context window when working on a particular task. This means that the amount of context that can be bundled
> into a skill is **effectively unbounded**."

> "When Claude runs `scripts/...`, the script code itself **never enters context**. Only its output
> (which is much smaller) consumes tokens, which makes scripts far more efficient than having Claude
> generate equivalent code on the fly."

> "**When the SKILL.md becomes unwieldy, split its content into separate files and reference them.**"
> "It should be clear whether Claude should run scripts directly or read them into context as reference."

### 1.3 Claude Code 的扩展字段（比规范多，但不可移植）

**来源**：<https://code.claude.com/docs/en/skills>（本文档全文已读，含 frontmatter 全表）

对本项目有决策价值的几条：

| 字段 / 机制 | 作用 | 本项目可用性 |
|---|---|---|
| `disable-model-invocation: true` | 只能 `/name` 手动调，Claude 不能自动触发 | ❌ opencode 不支持 |
| `context: fork` + `agent:` | skill 跑在**隔离子 agent** 里，看不到主对话历史 | ❌ opencode 无等价物，须用 subagent + Task |
| `allowed-tools:` | 本轮预授权，省掉权限弹窗 | ❌ opencode 用 `permission.skill` 替代 |
| `` !`command` `` | **动态上下文注入**：加载 skill 前先跑命令，把真实输出内联进去 | ❌ opencode 不支持 |
| `hooks:` | **规则不靠模型遵守，靠钩子强制** | ❌ opencode 无 skill hooks |
| `$ARGUMENTS` / `${CLAUDE_SKILL_DIR}` | 参数注入 / skill 自身目录 | ❌ opencode 无 |
| `paths:` | 只在碰到匹配文件时才自动激活 | ❌ opencode 无 |

**`hooks` 那条值得单独强调**（文档 Troubleshooting → "Claude stops following a skill"）：

> "**Claude skipped a rule that must hold every time**: move the rule into a hook. Claude Code runs a hook
> every time its event occurs, such as before each file edit, **whether or not Claude is following the skill**."

→ **官方对「模型会忘规则」的答案是：别靠 prompt，靠钩子。**
在只有 prompt 的 harness 里，**唯一等价的强制手段就是脚本返回非零退出码**。
这直接支持本报告的主结论（编排下沉到脚本）。

### 1.4 skill 内容的生命周期 —— 一条容易踩的坑

文档 "Skill content lifecycle"：

> "Claude Code **does not re-read the skill file on later turns**, so write guidance that should apply
> throughout a task as **standing instructions** rather than one-time steps."

> "After compaction, Claude Code **can keep only the start of an invoked skill** (first 5,000 tokens),
> so **put the most important instructions near the top of SKILL.md**."

→ **对本项目的意义**：`naraka-highlight-studio\SKILL.md` 把「环境铁律」放在**第 101 行**（文件末尾），
压缩一次就可能整段丢。**P0 反模式**。

---

## 2. Skill 该放什么、不该放什么（文档）

**来源**：<https://agentskills.io/skill-creation/best-practices>

### 2.1 核心判据：只写 agent 不懂的东西

> "Add what the agent lacks, omit what it knows."
> "Ask yourself about each piece of content: **'Would the agent get this wrong without this instruction?'**
> If the answer is no, cut it."

→ 本项目 211 行提示词里，**大量内容是 agent 本来就会的**（怎么调 ffmpeg、怎么用 whisper、什么是 VBR）。
真正「agent 不懂」的是：路径纪律、中文 `.ps1` 必须 UTF-8 BOM、看图 50 张硬红线、成片唯一归属 E 盘。

### 2.2 精确度要匹配脆弱度（这条直接回答「编排该写多死」）

> "**Give the agent freedom** when multiple approaches are valid… explaining *why* can be more effective
> than rigid directives."
> "**Be prescriptive** when operations are fragile, consistency matters, or a specific sequence must be followed."

官方给的两端示例：

```markdown
<!-- 灵活：描述要看什么 -->
## Code review process
1. Check all database queries for SQL injection …

<!--  prescriptive：脆弱操作必须死板 -->
## Database migration
Run exactly this sequence:
```bash
python scripts/migrate.py --verify --backup
```
Do not modify the command or add additional flags.
```

**→ 本项目的映射**（这是本报告最重要的一张映射表）：

| 内容 | 脆弱度 | 该放哪 |
|---|---|---|
| 「一场完整战斗不许挖洞、不许切断」 | 判断标准，模型要权衡 | **skill 正文**（且要给 why） |
| 「跑多久算超时、换哪条路、什么时候 partial 收尾」 | 确定性，可枚举 | **脚本** |
| 「战斗窗内不许挖洞」这条能否机器判 | 二值 | **脚本**（`qa_gate.py` 已经做了 17 扇门） |
| 「这段到底算不算这场战斗的因果链」 | 判断，模型才知道 | **skill / references** |
| 「成片只放 E:\Cujian导出」 | 确定性 + 破坏性 | **脚本**（`cleanup_after_master.ps1` 已做对） |

### 2.3 给默认值，不要给菜单

> "When multiple tools or approaches could work, **pick a default** and mention alternatives briefly
> rather than presenting them as equal options."

→ `naraka-highlight-studio\SKILL.md` 的 **Modes 一节列了 6 个模式**（`high_energy` / `complete_combat_roughcut` /
`cinematic` / `team_save` / `teaching` / `comedy`），其中 4 个在实际任务里**从没被用过**。
这是典型「菜单」而非「默认值」。**未找到**这些模式的实测使用记录 —— 建议只留 2 个（`complete_combat_roughcut`
默认 + `high_energy`），其余删掉或降级为 references 里的段落。

### 2.4 教方法，不教答案

> "A skill should teach the agent *how to approach* a class of problems, not *what to produce* for a
> specific instance."

→ 这一条**本项目做得最好**。`complete-combat-roughcut.md` 通篇是判据（「判断依据是它在不在这场战斗的因果链里」）
而不是硬编码片段。**合规，不要动。**

### 2.5 官方给的四个可抄结构（按对本项目的适配度排序）

| 结构 | 官方原文要点 | 本项目适配度 |
|---|---|---|
| **Validation loops** | "do the work, run a validator, fix, **repeat until validation passes**" | ★★★★★ `qa_gate.py` 已有 17 门，缺的是「不通过就重跑」的**循环** |
| **Plan-validate-execute** | 中间产物用结构化格式 → **脚本对源真值校验** → 才执行 | ★★★★★ 缺「帧轴标定」这一步（见 §6） |
| **Checklists** | "helps the agent track progress and avoid skipping steps, especially when steps have **dependencies or validation gates**" | ★★★★☆ 直接对应 phase runner |
| **Gotchas sections** | "environment-specific facts that **defy reasonable assumptions**"；「每次你纠正模型，都把纠正写进 gotchas」 | ★★★★☆ 中文 BOM / 看图上限 / 乱码目录三条都该在这 |

### 2.6 什么时候该写脚本 —— 官方给的判据（关键）

> "When iterating on a skill, compare the agent's execution traces across test cases. **If you notice the
> agent independently reinventing the same logic each run** — building charts, parsing a specific format,
> validating output — **that's a signal to write a tested script once and bundle it in `scripts/`**."

**→ 这就是「编排该写进 skill 还是脚本」的官方答案，且是数据驱动的：**
不是看「这段逻辑复杂不复杂」，而是看「**模型是不是每次都在重新发明同一套东西**」。

本项目的 `map_captions.py` 有 **4 份副本**（实测，见 `08-final-verdict.md` §0 第 25 行），
`build_program.py` 有 **3 份副本** —— 这是「模型每次重新发明」的铁证，
按官方判据**必须**收编成 `scripts/` 里的一个脚本。

### 2.7 脚本的 agent-friendly 设计契约（官方原文，几乎是逐条 checklist）

**来源**：<https://agentskills.io/skill-creation/using-scripts>

| 要求 | 官方措辞 | 本项目现状（实测） |
|---|---|---|
| **禁止交互** | "a hard requirement… Agents operate in non-interactive shells… A script that blocks on interactive input will hang indefinitely" | ✅ 未见交互 |
| **`--help` 是 agent 学接口的主途径** | "The `--help` output is the **primary way** an agent learns your script's interface" | ✅ 8 个脚本都用 argparse |
| **结构化输出** | 优先 JSON/CSV/TSV 而非对齐文本 | ✅ timeline 是 JSON |
| **数据与诊断分离** | "structured data to **stdout**, progress/warnings to **stderr**" | ⚠️ 未逐个核实 |
| **幂等** | "Agents may retry commands. **'Create if not exists' is safer than 'create and fail on duplicate.'**" | ❌ **缺**（续跑的地基） |
| **退出码要有区分度** | "Use **distinct exit codes** for different failure types… and **document them in `--help`**" | ⚠️ `qa_gate.py` 只有 `return 0 if failed == 0 else 1` |
| **dry-run** | "For destructive or stateful operations, a `--dry-run` flag lets the agent preview" | ❌ `cleanup_after_master.ps1` 无 dry-run |
| **输出体积可预测** | "harnesses automatically truncate tool output beyond a threshold… default to a summary or a **reasonable limit**, and support flags like `--offset`" | ❌ **缺** |

**最后两条对本项目尤其致命**：
本项目 `qa_gate.py` 736 行 / 34 KB。一次运行若把 17 扇门的完整 JSON 打到 stdout，
撞上 harness 截断阈值 → **agent 拿到残缺 JSON 且不报错**。
生态里的 `video-layer-skill` 把这个坑叫出来并做了对策：

> "**Inlining large context into a sub-agent's prompt silently truncates at Claude Code's Read-tool ceiling.
> The sub-agent gets partial data and returns garbage with no error.**"
> 对策 —— **brief-on-disk + SHA256**：编排器把结构化 brief 写到磁盘，只传**路径 + SHA256 + 行数**，
> 子 agent **先校验 hash** 再读。**静默截断变成显式失败。**

→ 这条必须进本项目：`qa_gate.py` 应输出**摘要到 stdout + 全量 JSON 到文件**，
并在 `--help` 里写清退出码。**（实测 `qa_gate.py` 目前是 `return 0/1` 两值。）**

---

## 3. 2026 的转向：从 prompt engineering 到 context engineering

**来源**：<https://www.anthropic.com/engineering/effective-context-engineering-for-ai-agents>（2025-09-29）

### 3.1 定性

> "After a few years of prompt engineering being the focus of attention… a new term has come to prominence:
> **context engineering**. Building with language models is becoming **less about finding the right words and
> phrases for your prompts**, and more about answering the broader question of
> **'what configuration of context is most likely to generate our model's desired behavior?'**"

### 3.2 官方对「长提示词」的直接判决 —— Goldilocks zone

> "The right altitude is the **Goldilocks zone** between two common failure modes. At one extreme, we see
> engineers **hardcoding complex, brittle logic in their prompts to elicit exact agentic behavior**.
> This approach creates fragility… At the other extreme, engineers sometimes provide vague, high-level
> guidance that fails to give the LLM concrete signals."

**→ 这是对本项目 211 行提示词最贴切的一句批评。**
那 211 行里的剪辑定义（L58–89）是**判断标准**，属于正确的「altitude」；
但围绕它的**编排规则**（超时、换路、partial、并发扫描）如果继续用自然语言写，就落在
**"hardcoding complex, brittle logic in their prompts"** 那一端。

### 3.3 官方对「把所有东西写进提示词」的判决

> "teams will often stuff a laundry list of edge cases into a prompt in an attempt to articulate every
> possible rule… **We do not recommend this.** Instead, we recommend working to curate a set of
> diverse, **canonical examples** that effectively portray the expected behavior."

> "One of the most common failure modes we see is **bloated tool sets that cover too much functionality or
> lead to ambiguous decision points** about which tool to use. If a human engineer can't definitively say
> which tool should be used in a given situation, an AI agent can't be expected to do better."

**→ 映射到本项目**：现有 8 个脚本里 `analyze_bgm.py` / `map_events_to_beats.py` / `export_edit_timeline.py`
在**默认的 `complete_combat_roughcut` 路径上根本不会被调用**（该模式默认无 BGM）。
按官方判据这是「bloated tool set」—— **该模式应该只暴露它真正用的 3 个脚本**。

### 3.4 长时程任务的三件套（官方给的解法，不是「把提示词写长」）

| 技术 | 官方描述 | 本项目对应 |
|---|---|---|
| **Compaction** | 摘要压缩后重开上下文窗口 | opencode 内置 |
| **Structured note-taking** | "agent regularly writes notes persisted **to memory outside the context window**… lets the agent track progress across complex tasks, maintaining critical context and dependencies that would otherwise be lost across dozens of tool calls" | ❌ **缺 `delivery_state.json`**（`08` 号已指出） |
| **Sub-agent architectures** | "Each subagent might explore extensively, using tens of thousands of tokens or more, but **returns only a condensed, distilled summary** (often 1,000-2,000 tokens)" | ⚠️ opencode 有 subagent，本项目 0 使用 |

**「structured note-taking」这一条对「续跑」是正解**：
续跑不该靠「重读 303 KB 台账」（`08` 号实测：人读 20 min），而该靠一个**几百 token 的 state 文件**。

---

## 4. opencode 的 skill 机制 —— 与 Anthropic 差异很大（本项目的主战场）

**来源**：<https://opencode.ai/docs/skills/>（Last updated: **Oct 3, 2026** — 本报告取证时最新）

### 4.1 发现路径（文档）

opencode 搜索这 6 个位置：

```
.opencode/skills/<name>/SKILL.md          (项目)
~/.config/opencode/skills/<name>/SKILL.md (全局)
.claude/skills/<name>/SKILL.md            (项目，Claude 兼容)
~/.claude/skills/<name>/SKILL.md          (全局)
.agents/skills/<name>/SKILL.md            (项目，agent 兼容)
~/.agents/skills/<name>/SKILL.md          (全局)
```

**裸 `skills/` 不在其中。**

### 4.2 frontmatter（文档）

opencode **只认 5 个字段**：`name`(必填) / `description`(必填) / `license` / `compatibility` / `metadata`。
「Unknown frontmatter fields are ignored.」

**注意这里与 Claude Code 的差异方向相反**：
Claude Code 上写私有字段是**增强**；opencode 上写私有字段是**静默丢弃**。
即 `disable-model-invocation` / `context: fork` / `allowed-tools` 在 opencode 上**写了等于没写，且不报错**。
→ **这正是必须守住规范 6 字段的原因**：只有 6 字段在两边都安全。

名字校验：`^[a-z0-9]+(-[a-z0-9]+)*$`，1–64 字符，**必须与父目录名一致**。
`description` 1–1024 字符。

### 4.3 权限（文档）

```json
{ "permission": { "skill": { "*": "allow", "pr-review": "allow",
                              "internal-*": "deny", "experimental-*": "ask" } } }
```

支持通配。可按 agent 覆盖（自定义 agent 写在 frontmatter `permission.skill`，
内置 agent 写在 `opencode.json` 的 `agent.<name>.permission.skill`）。

### 4.4 本项目实测：29 个 skill 一个都不可见 🔴

**实测证据链**：

1. 磁盘实况：`skills\` 下有 **29 个 skill 目录**（含 `naraka-highlight-studio`、`autopilot`、`tdd`、`code-review`…）。
2. `.opencode\` / `.claude\` / `.agents\` **三个目录都不存在**（`Test-Path` 全 False）。
3. 全项目**没有任何 `opencode.json`**（递归搜 `opencode.json*` → 0 命中）。
4. `AGENTS.md` 自己也承认了 workaround：
   > 「如果自动技能列表中没有显示它，直接按上面的项目路径读取即可。」
5. **本会话自己的 `<available_skills>` 只列出 `opencode` 和 `report` 两个 skill** ——
   29 个项目 skill 一个都没出现。

**→ 这就是「流程没有真正被封装，只是被描述了」的机械根因。**

因果链非常清楚：

```
skill 放在 skills\        →  harness 从不扫描        →  skill 永不出现在 available_skills
        ↓
模型无法自主触发 skill    →  每次必须人手贴 211 行提示词
        ↓
提示词 L46 只能写「读 C:\…\skills\naraka-highlight-studio\SKILL.md」  ← 提示词被迫当**加载器**
        ↓
真正的编排规则没地方放（opencode 无 hooks、无动态注入）→ 只能继续塞进提示词 → 提示词越来越长
        ↓
211 行 = 剪辑规格书 + 加载器 + 半套编排，而且实测编排词 17/17 全 0 命中
```

**重要推论**：`08-final-verdict.md` 把问题定位为「缺的是编排，不是提示词长度」——
**方向正确，但漏了最底层的这一层**：编排之所以没地方放，
是因为 skill **压根没被注册**，模型只能靠一段散文来模拟「加载一个 skill」这个动作。
**先修注册，编排才有承载体。**

### 4.5 opencode 的替代杠杆（没有 X 的时候用什么）

| Anthropic 机制 | opencode 对应物 | 来源 |
|---|---|---|
| `context: fork` 隔离子 agent | `.opencode/agents/<name>.md` + `mode: subagent`，主 agent 用 Task 工具派 | `/docs/agents/` |
| skill 权限 | `permission.skill` | `/docs/skills/` |
| 禁用某 agent 用 skill | frontmatter `tools: { skill: false }` | `/docs/skills/` |
| 自定义工具（可包装脚本） | `.opencode/tools/<name>.ts`，`tool()` helper + Zod | `/docs/custom-tools/` |
| 事件钩子 | ❌ **无等价物** → 只能靠脚本退出码 | — |

**自定义工具这一条值得注意**（文档原文）：

> "Tools are defined as **TypeScript** or **JavaScript** files. However, the tool definition can invoke
> scripts written in **any language**… **The filename becomes the tool name.**"
> "Use `context.directory` for the session working directory."

→ **「一句话」的最优形态可能不是 skill，而是 `.opencode/tools/naraka_roughcut.ts`**：
模型只需说 `naraka_roughcut({ material: "E:\\…", mode: "complete_combat_roughcut" })`，
一次调用就把整条链跑完 —— **真正的原子操作，不必暴露给模型 8 个脚本和一堆 references**。
这正面命中官方说的 "bloated tool sets… ambiguous decision points"。
**（推断：本项目目前 0 custom tools，是最大的一块未开采地。）**

---

## 5. 生态参考：复杂工作流的完整例子

### 5.1 官方仓库

**<https://github.com/anthropics/skills>**（179.7k star / 21.2k fork，取证日实读）
- 分类：Creative & Design、Development & Technical、Enterprise & Communication、Document Skills
- `spec/` 目录 = Agent Skills 规范；`template/` = 模板
- 内置 `/skill-creator` 插件：自动跑 eval 循环（`evals/evals.json` 格式），
  含 **description 命中率调优**、**盲测 A/B 版本对比**、HTML 评审报告

### 5.2 视频/复杂工作流可抄的四个（按可抄度排序）

#### ① `Alexander-Kz/video-layer-skill` —— ★★★★★ **最贴本项目**

**定位**：「Production multi-agent Claude Code skill — 把一段配音 MP3 变成一条完整白板解说视频」。
**规模**：~7,400 行 Python / 23 个脚本 + **14 个 sub-agent prompt 文件**。日均生产在用。

**四条核心做法**（每条都直接对应本项目缺口）：

| 做法 | 官方/作者原文 | 对应本项目 |
|---|---|---|
| **Director 模式** | "The Claude Code instance acts as a **Director** — it orchestrates sub-agents and runs scripts, but **never writes the creative content itself**. Each creative role is a separate sub-agent with its own prompt." | 编排 skill 只调脚本/派 agent，不写剪辑判断 |
| **brief-on-disk + SHA256** | 见 §2.7 —— 防静默截断 | `qa_gate` 输出摘要+落盘+hash |
| **可续跑状态** | "**`pipeline_state.json` tracks the current phase and which assets exist. Restart-from-crash just re-runs the orchestrator: it regenerates only what's missing.**" | **本项目最该抄的一条** |
| **gated two-wave** | Wave 1 只生成序列首帧 → vision agent 检 → **闸门过了**才 Wave 2 | 对应本项目「先 720p 预览 → 审片 → 才 4K」 |

#### ② `browser-use/video-use` —— ★★★★★ 剪辑域最专业

**结构**（可直接抄目录形状）：

```
<source files, untouched>
└── edit/
    ├── project.md          ← memory；每次会话追加
    ├── takes_packed.md     ← 词级时间戳转录，editor 唯一主读物
    ├── edl.json            ← 剪辑决策（机器可校验）
    ├── animations/slot_<id>/   ← 每个动画一个 sub-agent
    ├── transcripts/<name>.json
    ├── clips_graded/
    ├── master.srt
    ├── verify/             ← 调试帧
    ├── preview.mp4
    └── final.mp4
```

**四条原文规则**：

1. **并行铁律**：
   > "Parallel sub-agents for multiple animations. **Never sequential.** Spawn N at once via the `Agent` tool;
   > total wall time ≈ slowest one."
   → 直接对上 `08` 号实测的「子Agent / 并行 = 0 命中」。

2. **渲染物自审（关键，且和本项目 §8.1 教训完全一致）**：
   > "**Self-eval (before showing the user). Run `timeline_view` on the rendered output (not the sources)
   > at every cut boundary (±1.5s window).**"
   → 这正是本项目 864「门禁全绿但用户仍否决」的解法方向：**自审必须针对渲染物，不针对源**。

3. **只保留一个派生物**：
   > "The **only** derived artifact that earns its keep is a packed phrase-level transcript
   > (`takes_packed.md`). Everything else … you derive at decision time."
   > 强调理由：`takes_packed.md` 给出 **1/10 the tokens of raw JSON** 的词边界精度。
   → 本项目 `shots\`（可上千张）+ `cache\` 的取舍判据。

4. **只转录一次**："**Never re-transcribe.**"

#### ③ `chenyuxiaojin/video-agent-skills` —— ★★★★ 编排形状

11 个 skill，**producer 是纯编排器**：
> "`video-agent-producer` | Director / orchestrator. Accepts a topic, breaks it into sub-tasks,
> **dispatches all other agents in order, manages 4 human checkpoints and checkpoint recovery.**
> | `project.json` + final deliverable package"

**「一个 producer + N 个单一职责 skill + project.json 状态 + checkpoint recovery」** ——
这正是本项目缺的形状。注意它**也有** checkpoint 恢复，与 ① 的 `pipeline_state.json` 同构。

#### ④ `appergb/ClipSkills` —— ★★★ 设计原则值得抄

> "**决策逻辑（怎么剪、为什么、怎么判质量）与软件操作（用什么剪）完全分离**，
> 且每个剪辑 app 跑在自己的 sub-agent 里以避免上下文污染。"
> "**红线：skill 绝不编造软件能力** —— 工具在运行时被发现，参数跟官方文档。"

→ 「决策 / 执行分离」正是 §2.2 那张映射表的另一种表述。
「绝不编造能力」对应本项目 ffmpeg 路径解析铁律（不要硬编码）。

#### ⑤ `bsisduck/video-analyzer-skill` —— ★★ 分析侧参考

- **自适应 tier**：按时长自动定抽帧率（本项目 50 张预算问题的同类解法）
- **并行 subagent**：grid / key-frame / audio 三路同时派
- **脚本报错**：非 ffmpeg 经验（`references/ffmpeg-commands.md` "gotchas"）
- 遵循 Agent Skills 开放标准

### 5.3 未找到 / 存疑

- **「The Complete Guide to Building Skills for Claude」（2026-01）** —— 多个二手源引用，
  **未找到**可直读的官方原文。**标为未验证**，本报告未据其下任何结论。
- **没找到**任何公开的、专门针对「多阶段视频剪辑 + 人工审片 + 可续跑」的官方参考实现。
  生态里最接近的是 ① 和 ③，但两者都是**生成式视频**（AI 出画），
  **不是本项目的「从已有素材里剪」**。**这是本项目的真实空白 —— 也就是它的差异化位置。**

---

## 6. 本项目合规审计（全部实测）

### 6.1 规模与形状

| 项 | 实测值 | 规范要求 | 判定 |
|---|---|---|---|
| `SKILL.md` | **105 行 / 9.9 KB** | < 500 行 / < 5000 token | ✅ **优秀，余量巨大** |
| references 层级 | 一层深（`references/x.md`） | one level deep | ✅ |
| reference 最大文件 | `complete-combat-roughcut.md` **392 行 / 42.8 KB** | 建议 | ⚠️ 见 6.3 |
| scripts | 8 个，736 行最大 | 无上限 | ✅ |
| frontmatter 字段 | `name` / `description` / `metadata` | 规范 6 字段内 | ✅ **可移植** |
| `name` vs 目录名 | `naraka-highlight-studio` == 目录名 | 必须一致 | ✅ |
| `description` 长度 | 未超 1024 | ≤ 1024 | ✅ |

### 6.2 🔴 阻断项

| # | 问题 | 证据 | 后果 |
|---|---|---|---|
| **B1** | **skill 目录不可发现** | 无 `.opencode/`/`.claude/`/`.agents/`；无 `opencode.json`；本会话 `available_skills` 无它 | 每次必须手贴 211 行；模型无法自主触发 |
| **B2** | **编排逻辑 0 实现** | `Select-String` 逐词：`子Agent`/`并行`/`扫描员`/`超时`/`换路`/`partial`/`schema`/`幂等`/`续跑`/`checkpoint`/`状态机` **全部 0**（`台账` 1 命中，语义不同） | 「跑多久 / 死等 / 续跑」全靠模型即兴发挥 |
| **B3** | **无 evals** | 无 `evals/evals.json` | 改 skill 无从判断是变好还是变坏（官方唯一的迭代闭环缺失） |
| **B4** | **无幂等 / 无续跑状态** | 全项目无 `delivery_state.json` / `pipeline_state.json`（`08` 号实测 `taskstate.ps1` 不存在） | 崩了只能重来；303 KB 台账人读 20 min |

### 6.3 ⚠️ 应修项

| # | 问题 | 证据 | 修法 |
|---|---|---|---|
| M1 | 392 行 reference 无目录 | 首 12 行是 `# 标题` / `## 目标` / 代码块，**无 TOC** | 官方建议 >100 行的 reference 加目录 |
| M2 | 铁律在 SKILL.md **末尾**（L101–105） | 压缩后 compaction 只保留前 5000 token | **铁律移到 L10 之前** |
| M3 | Modes 列 6 个，多数无使用记录 | SKILL.md L30–37 | 只留 2 个默认 + 2 个备选 |
| M4 | 默认模式不用 BGM，但暴露 3 个 BGM 脚本 | `analyze_bgm.py`/`map_events_to_beats.py`/`export_edit_timeline.py` | 按官方 "bloated tool set" 判据收窄 |
| M5 | `qa_gate.py` 只有 0/1 退出码 | `return 0 if failed == 0 else 1` | 官方要求 distinct exit codes + `--help` 记录 |
| M6 | `qa_gate.py` 可能撞输出截断 | 736 行 / 34 KB，一次运行 | 摘要→stdout，全量→文件，**传 hash 不传内容** |
| M7 | 测试 runner 在 skill 外 | `scripts/test_whole_battle_gates.sh`，而 fixtures 在 `skills/…/tests/` | skill 要可移植，runner 应进 skill |
| M8 | 成品脚本散落 4 个任务目录 | `map_captions.py` 4 份 / `build_program.py` 3 份（`08` 号实测） | 官方判据：重复发明 → 收编进 `scripts/` |

### 6.4 ✅ 已达标，不要动

- **判据式写作**：`complete-combat-roughcut.md` 给因果链判据而非硬编码片段 —— 完全符合「favor procedures over declarations」。
- **薄提示词原则**：`粗剪提示词.md` 设计原则第 1 条明写「不复述 skill，避免第二份副本」—— 方向完全正确，只是**没做到**。
- **脚本化的破坏性操作**：`cleanup_after_master.ps1` 带交付闸门（找不到成片就 `[BLOCKED]` 零字节不删）——
  这就是官方说的「规则靠钩子/退出码强制」的等价物，**架构上是对的**。
- **路径纪律运行时解析**：`resolve_ffmpeg.ps1` + `check_video_environment.ps1` —— 就是官方说的「Prefer scripts for deterministic operations」。
- **看图预算 50 张硬红线**：这是最该写进 **gotchas** 的一条（“defy reasonable assumptions”），当前在 AGENTS.md 而非 skill。

---

## 7. 重构方案

### 7.1 目标形态

```
用户一句话 / 一个 custom tool 调用
        ↓
  ①  注册层：skill 放进 harness 扫得到的目录          ← 修 B1（先做，一行 git mv）
        ↓
  ②  入口层：naraka-roughcut/SKILL.md  ≤150 行
        只做三件事：选 phase → 调脚本 → 跑门禁 → 报缺口
        ↓
  ③  执行层：scripts/pipeline.py（编排）+ 12 个阶段脚本（确定性）
        持有 pipeline_state.json → 幂等 / 续跑 / 超时 / 换路 / partial
        ↓
  ④  判断层：references/*.md（剪辑判据，只读）
        ↓
  ⑤  证据层：qa_gate → 摘要(stdout) + 全量(JSON 文件) + 退出码
        ↓
  ⑥  验收集：evals/evals.json（2–3 个真实素材回归）
```

### 7.2 三条硬分工原则

| 层 | 只放 | 绝不放 | 判据 |
|---|---|---|---|
| **skill 正文** | 判断标准、**why**、不可违反的 gotchas、什么时候读哪个 reference | 超时秒数、退出码、文件清单、脚本调用序列 | 模型需要**权衡**的 |
| **references** | 长判据、模式说明、逐条证据规则 | 任何「先做 A 再做 B」的强制序列 | **只在特定分支需要**的 |
| **scripts** | 一切确定性：跑什么、跑多久、失败了怎么办、状态存哪、怎么续 | 需要理解画面/因果链的判断 | 模型**每次都在重新发明**的 |

### 7.3 提示词该多长 → **目标是 0 行**

**这是本报告最重要的一条建议。**

一旦 B1 修好，`naraka-roughcut` 出现在 `<available_skills>` 里，
用户在 opencode 里只需说：

> 「用 naraka-roughcut 剪 E:\PR导出\xxx.mp4，完整战斗粗剪」

`description` 字段承载触发条件（规范：description 是**主要触发机制**，「when to use」必须写在里面）。
`粗剪提示词.md` **退化成一份 `install.md` / `README`**（讲怎么装、怎么手工调用、为什么这么设计），
**不再是每局的启动载荷**。

**若暂不修 B1**（保守回退）：提示词只留 3 件事，**目标 ≤ 15 行** ——
① 素材路径 ② 调用哪条 skill ③ 铁律里最易违反的 1–2 条（看图 50 张）。
其余全部指向 skill。**「薄」这件事，项目自己在设计原则第 1 条已经定了，只是没执行。**

### 7.4 幂等性与续跑怎么进 skill（照抄 `video-layer-skill`）

**`scripts/pipeline.py` + `reports/pipeline_state.json`**：

```json
{
  "schema": 1,
  "task": "861.xxx", "phase": "render_preview", "round": 2,
  "phase_state": {
    "analyze":      { "status": "done", "sha256": "…", "finished_at": "…" },
    "timeline":     { "status": "done", "sha256": "…" },
    "qa_gate":      { "status": "fail", "fail_gates": ["no_holes_in_battle"],
                      "report": "reports/qa_864_v6.json", "sha256": "…" },
    "render_preview": { "status": "pending" }
  },
  "budget": { "started_at": "…", "deadline_h": 7.5, "wall_spent_s": 12043 },
  "next_action": "fix_timeline_then_revalidate"
}
```

四条设计规则（全部来自官方 + 生态）：

1. **幂等 = create-if-not-exists**（官方原文）。`pipeline.py` 重跑时按 `phase_state` 跳过已 `done` 且
   `sha256` 未变的阶段 —— **这就是 ① 的 "restart-from-crash just re-runs the orchestrator"**。
2. **状态文件必须小到能整份进上下文**（structured note-taking 原理）。
   替代 303 KB 台账：台账留作**证据**，`pipeline_state.json` 才是**续跑依据**。
3. **超时/换路/partial 全部是脚本内的函数，不是 prompt 里的句子。**
   `08` 号已回测 T2 自适应公式命中 7.5h 死等、零误杀 —— **把它从文档搬进 `pipeline.py`。**
4. **换路必须有记录**：每次 fallback 写 `reports/ledger_vN.md`（三态台账已在 `roughcut-launch.md` 有设计，
   缺的只是**写它的那个程序**）。

### 7.5 具体文件树提案

```
skills/naraka-highlight-studio/            ← 保持在盘上（唯一正本）
│
├─ .opencode/skills/naraka-roughcut/       ← 【新】注册层：入口 skill（≤150 行）
│  ├─ SKILL.md                            ← 三件事 + gotchas + reference 路由
│  └─ evals/evals.json                     ← 【新】2–3 条真实素材回归
│
├─ scripts/
│  ├─ pipeline.py                          ← 【新】编排 + 幂等 + 续跑 + 超时 + 换路
│  ├─ ingest/  (analyze_bgm→保留, map_events_to_beats→保留, export_edit_timeline→保留)
│  ├─ build_program.py                     ← 【新】收编（现 3 份副本）
│  ├─ map_captions.py                      ← 【新】收编（现 4 份副本）
│  ├─ frame_axis.py                        ← 【新】帧轴标定（帧号/PTS，不用 ffmpeg -ss 猜）
│  ├─ qa_gate.py                           ← 改：摘要 stdout + 全量落盘 + 区分退出码
│  └─ test_whole_battle_gates.sh           ← 【移】从 scripts\ 移进来（可移植）
│
├─ references/                             ← 判据层，基本不动
│  ├─ complete-combat-roughcut.md          ← 加 TOC（392 行）
│  ├─ roughcut-launch.md                   ← 编排规则移出到 pipeline.py 后瘦身后
│  └─ …
└─ agents/                                 ← 【新】opencode subagent（导演/扫描员/验收）
   ├─ director.md      mode: subagent, 调度 + 派发，不自己写判断
   ├─ scanner.md       mode: subagent, 抽帧 + 看图（受 50 张预算约束）
   └─ auditor.md       mode: subagent, 删除段审计（§8.1 新增角色）
```

### 7.6 落地顺序（按 ROI）

| 步 | 动作 | 成本 | 收益 | 风险 |
|---|---|---|---|---|
| **1** | `git mv skills .opencode/skills`（或加 `.claude/skills` 软链） | **1 条命令** | 29 个 skill 全部可发现；模型自主触发 | 需同步改 `AGENTS.md` 里的 4 处路径 |
| **2** | SKILL.md 铁律从 L101 移到 L10 前 | 10 分钟 | 抗 compaction | 无 |
| **3** | `qa_gate.py` 改「摘要 stdout + 全量落盘 + 退出码分级」 | 1 小时 | 消除静默截断 | 无（纯增量） |
| **4** | `evals/evals.json` 3 条 + 收编 `map_captions`/`build_program` | 半天 | 有回归网；消除 7 份副本 | 收编需逐份比对 |
| **5** | `scripts/pipeline.py` + `pipeline_state.json` | 2–3 天 | 幂等 / 续跑 / 超时 / 换路 | 最大工程量；先只做 preview 路径 |
| **6** | `.opencode/tools/naraka_roughcut.ts` | 1 天 | 「一句话」变成一次原子调用 | 依赖步 5 |
| **7** | `粗剪提示词.md` → `install.md`，正文清空 | 30 分钟 | 消除第二份副本的漂移源 | 需确认用户接受 |

**步 1 是杠杆率最高的一步，且是纯机械操作。**

---

## 8. 三条不该做的事

1. **不要继续往 `粗剪提示词.md` 里加编排规则。**
   官方判决：把复杂脆弱逻辑硬编进 prompt 会「create fragility and increases maintenance complexity」。
   加进去只会让 B2 更难解。
2. **不要把 `naraka-highlight-studio` 拆成 11 个 skill（照抄 `video-agent-skills`）。**
   官方明确警告「Skills scoped too narrowly force multiple skills to load for a single task,
   **risking overhead and conflicting instructions**」。本项目 6 个 modes 已经是「拆过头」的早期症状。
   **抄它的 producer 形状，不抄它的 skill 数量。**
3. **不要把 `hooks` 当成可用杠杆。** opencode 没有。opencode 上唯一能强制「每次都必须」的手段
   是**脚本的非零退出码**——所以门禁必须在脚本里，不能在 SKILL.md 的第 80 行。

---

## 9. 证据分级汇总

| 结论 | 分级 |
|---|---|
| Agent Skills 规范三级披露、<500 行/<5000 token、6 字段、one-level-deep | **文档**（agentskills.io/specification 原文） |
| skill 该放什么/不该放什么、prescriptive vs freedom、bundle scripts 判据 | **文档**（agentskills.io/skill-creation/best-practices） |
| 脚本 agent-friendly 契约（幂等/退出码/dry-run/输出可预测） | **文档**（agentskills.io/skill-creation/using-scripts） |
| context engineering、Goldilocks zone、note-taking、subagent | **文档**（Anthropic engineering blog 2025-09-29） |
| Claude Code 扩展字段、生命周期、compaction 前 5000 token、hooks 强制 | **文档**（code.claude.com/docs/en/skills） |
| evals 闭环、assertions、benchmark delta | **文档**（agentskills.io/skill-creation/evaluating-skills） |
| opencode 发现路径 6 处、只认 5 字段、permission.skill | **文档**（opencode.ai/docs/skills，Oct 3 2026） |
| opencode subagent / custom tools | **文档**（opencode.ai/docs/agents、/custom-tools） |
| **本项目 skill 不被 opencode 发现** | **实测**（无 3 目录、无 opencode.json、本会话 available_skills 无它） |
| **编排词 17/17 全 0 命中** | **实测**（逐词 Select-String） |
| SKILL.md 105 行、各 reference 行数、脚本数与行数 | **实测**（ReadAllLines） |
| `qa_gate.py` 只有 0/1 退出码；8 脚本均用 argparse | **实测**（grep） |
| 392 行 reference 无 TOC | **实测**（首 12 行） |
| `map_captions.py` 4 份 / `build_program.py` 3 份副本 | **实测**（引 `08-final-verdict.md` §0，本轮未重数） |
| 6 个 modes 多为闲置 | **推断**（未找到使用记录，非确证） |
| 「一句话」最优形态是 custom tool 而非 skill | **推断**（有官方工具集膨胀判据支持，未实测） |
| `pipeline_state.json` 字段设计 | **推断**（结构来自 `video-layer-skill` + 本项目 T2 公式，字段名自拟） |
| 「The Complete Guide to Building Skills」(2026-01) 内容 | **未找到**一手原文，未据其下任何结论 |
| 专门针对「已有素材剪辑 + 审片 + 续跑」的公开参考实现 | **未找到**（生态均为生成式视频） |

**本报告零图片**，AGENTS §9 预算消耗 0 张。