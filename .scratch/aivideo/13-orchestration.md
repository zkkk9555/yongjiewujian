# 13 · 多 Agent 并行编排层调研（框架能力 / 自建够不够 / 流式合并 / 成本并发）

> 调研角度：**派工—回收—换路—续跑—交付** 这一层有没有更好的做法。
> 结论先行见 §0。全部结论标注 **实测 / 文档 / 推断 / 未找到**。
> 调研日期 2026-10-05。所有框架结论均以官方文档为准，链接逐条给出。
> **未运行任何框架**（不新建 venv、不装包，符合 `AGENTS.md §2` 环境铁律），因此没有一条结论是「框架实测」——
> 凡是「实测」标注的都只指**本机 opencode 自身**与**本项目**的实测。

---

## 0. 结论先行

| # | 结论 | 标注 |
|---|---|---|
| 1 | **不换框架。** 本项目的四个病（无状态、无超时换路、不能续跑、等齐才合）**全部是编排缺失，不是执行能力缺失**。换成 Temporal/LangGraph 只会把同一个状态机用 10 万行 YAML 重写一遍。 | 推断 |
| 2 | **不换框架靠自建够不够：够，而且够得很干净。** 因为 opencode V2 **自带**了本项目缺的 6 个原语（见 §2.2），它们全在 `/api/session/*`，已实测存在于 `openapi.json`。缺的只是把它们串起来的那 ~300 行 `dispatch_watchdog.ps1`。 | 实测（API 存在）+ 推断（够用） |
| 3 | **本次调研挖到一个比"9.3 小时干等"更严重的病：opencode 数据库已经 14.30 GB，其中 12.78 GB 是图片 base64。** 每读一张联系表就往 DB 写约 4 MB，永久。这是**单次任务的隐藏成本**，也是所有后续任务的税。 | **实测** |
| 4 | 流式/增量合并：**能做，而且本项目已有设计**（岛式合并 §2.8），但**规则自相矛盾导致零使用**——partial 唯一的下游消费者明文禁止吃 partial。这不是技术问题，改一行规则的事。 | 文档（项目内规则） |
| 5 | 并行上限：**不受本机 CPU/显存限制**（推理在云端），受限于 **① 磁盘（DB 已膨胀到 14.3 GB）② 上游单请求 50 图红线 ③ 每路 4 MB 图片 base64 的上下文成本**。14 路是合理量级，不必加。 | 实测 + 推断 |
| 6 | 框架对照表（§3）的结论：**LangGraph 1.2 是唯一一个把「超时+心跳+重试+降级+续跑」五件事做在同一个框架里、且不需要额外部署服务的**。Temporal 更强但要起 server；CrewAI/Mastra/OpenAI Agents SDK 都缺"换路"语义（只能原地重试，不能换一条并行路）。 | 文档 |

**一句话**：**别换框架，把 opencode 自带的 session API 当持久层、写一个看门狗就够了；顺手先把图片 base64 那个 14 GB 的洞堵上。**

---

## 1. 本项目的四个病，重新定位

先把"病"说准，否则会拿错药。

| 症状 | 861 的实测 | 根因层 | 换框架能治吗 |
|---|---|---|---|
| 3 路被服务端重启吞掉，无人换路 | 3/14 路消失 | **缺超时判据 + 缺执行者** | 框架能给你 timeout/retry，**但换路（换一个 Agent 重做同一区间）不是框架内建语义** |
| 14 路全回收才合成 | 干等 9.3 h | **缺增量归并授权**（§4） | 框架不能替你改项目规则；规则冲突照样死结 |
| 台账缺"回收时间"列，超时算不出来 | 864 表头 5 列，无时间戳 | **状态存在散文里** | 框架的 checkpointer 就是机器可读状态——**但本项目自己写个 JSON 更快** |
| 对话中断无法续跑 | 860 的 resume 实现被清理脚本删掉 | **无持久化状态文件** | 框架给持久化；自建也给（§2） |

**关键判断（推断）**：这四条**没有一条是"框架不够强"造成的**。它们全部可以在现有 opencode 子 Agent 编排上补齐。**换框架是把「补 300 行脚本」换成「补 300 行脚本 + 引入 5 个依赖 + 起一个 server + 改写 8 个角色的派工方式」——净亏损。**

---

## 2. 自建够不够：opencode V2 已经自带了什么

### 2.1 先确认现状：项目里一个编排脚本都没有

**实测**（`Get-ChildItem C:\Project\永劫无间\scripts`）：

```
audit_coverage_judgement.py   check_image_budget.ps1      check_task_hygiene.ps1
check_task_numbering.ps1      check_video_environment.ps1 cleanup_after_master.ps1
collect_lessons.ps1           make_contact_sheet.ps1      read_episode_bounds.ps1
resolve_ffmpeg.ps1            sanitize_stray_dirs.ps1     seg_render_master.sh
test_coverage_gate.sh         test_coverage_regression.sh test_hole_render_e2e.sh
test_insegment_holes.sh       test_whole_battle_gates.sh  verify_master.sh
```

**匹配 `watchdog|resume|state|dispatch|heartbeat` 的脚本数 = 0。** 编排层完全靠主 Agent 自己在对话里记。

**实测**（864 台账表头，逐字）：

```
| 路 | 区间(源秒) | 状态 | 报告路径 | 下一步 |
```

无派工时间、无回收时间、无心跳、无 attempt。**超时换路在数学上不可计算** —— 这一点 09 号报告已判定，此处复核确认。

### 2.2 关键发现：opencode V2 的 HTTP API 已经提供了缺失的原语

**实测**：抓取 <https://opencode.ai/v2/openapi.json>（117 条路径，本机 opencode v2.0.22），逐条比对本项目需要的能力：

| 本项目缺的能力 | opencode API 原语 | 端点 | OpenAPI 原文（节选） |
|---|---|---|---|
| **机器可读状态**（替代 304 KB 台账） | 列会话 / 取会话 | `GET /api/session`、`GET /api/session/{id}` | "Retrieve sessions in the requested order" |
| **谁在途**（替代人眼数人头） | 活跃会话 | `GET /api/session/active` | "Retrieve foreground Session drains currently owned by this OpenCode process. **Sessions absent from the result are inactive.**" |
| **派工**（不占主对话） | 发消息 | `POST /api/session/{id}/prompt` | "**Durably admit one session input and schedule agent-loop execution unless resume is false.**" |
| **等一路回来**（替代干等） | 等会话空闲 | `POST /api/experimental/session/{id}/wait` | "Wait for a session agent loop to become idle." |
| **超时换路 = 中断 + 换一条** | 中断 | `POST /api/session/{id}/interrupt?resume=` | "Interrupt active execution... **When resume=true, execution resumes pending steering input**..." |
| **换路（另起一路）** | 建子会话 / fork | `POST /api/session`（`parentID`）、`POST /api/session/{id}/fork` | "A parentID creates a linked child session" / "**Fork session** — Create a child session by copying projected history before a message" |
| **事件流**（替代轮询） | 订阅事件 | `GET /api/event` | "Subscribe to native events and plugin RPC events... **Volatile by contract**" |
| **回滚到某条** | 暂存/提交回滚 | `POST /api/session/{id}/revert/stage`、`/revert/commit` | "Stage or move a **reversible session boundary**" |
| **人工介入** | 权限请求 | `GET /api/permission/request`、`POST .../reply` | 见 API 列表 |

**这 9 个原语逐条对应本项目的 4 个病。** 换句话说：**能力已经在手边，缺的是把它们编排起来的那个进程。**

### 2.3 但有两个真实的缺口，必须自己写

| 缺口 | 为什么框架原语不够 | 自建方案 |
|---|---|---|
| **心跳**（判断"在途但卡住了"） | opencode 没有暴露"这路 Agent 上次动作是什么时候"。`/api/event` 是 **volatile**（断线丢事件），不能当可靠心跳源 | 子 Agent 每完成一个判定步骤就 `追加一行 HB <ISO8601> <已看帧数>` 到台账（纯追加，兼容 §2.3「只追加不改旧行」）。看门狗读台账算 `now - 心跳 > 25min` |
| **降级阶梯**（attempt ≤ 2 后停手） | 没有任何框架内建"重试 N 次后标记 SEAM 并交人工" | 09 号报告 §2.3 的三级阶梯（派 segNb → 标 SEAM 留缝 → needs_review 结案）。框架的 retry policy 到此为止 |

### 2.4 自建够不够的最终判定

**够。** 判定依据三条：

1. **缺的能力已由 harness 提供**（§2.2，9 个端点，实测存在于 openapi.json）。
2. **缺的部分是纯逻辑，不是分布式协调**——一个 PowerShell 脚本读 JSON、算年龄、写动作单。**不需要 Temporal 那种 Event History + Replay 机制**，因为本项目没有"进程崩溃后重建内存状态"的需求：状态全在磁盘文件里，进程死了文件还在。Temporal 的核心价值（replay 恢复内存态）本项目用不上。
3. **引入框架的代价是真实的**：Temporal 要起 server（自托管 v1.30+ / Cloud）；LangGraph 要写 Python 图 + 迁移 8 个角色的派工方式；Pydantic AI 要 8 选 1 引擎决策。而本项目 `AGENTS.md §2` 明文禁止新建 venv 和装包——**换框架会直接违反项目自己的环境铁律**。

> ⚠️ **例外**：如果将来这个编排层要**脱离 opencode 独立复用**（比如给别的项目用），那时 LangGraph 1.2 才是正解（§3 对照表）。**为永劫无间一个项目换框架，不划算。**

---

## 3. 框架能力对照表

**图例**：✅ 文档明确有 ｜ ⚠️ 有但有坑（坑注明）｜ ❌ 文档未见 ｜ 🔵 需额外部署

| 框架 | 断点续跑 | 超时重试 | **超时换路**（另起一路） | 人工介入 | 中断恢复 | 部署代价 | 证据 |
|---|---|---|---|---|---|---|---|
| **LangGraph 1.2** | ✅ checkpointer（`durability="sync"/"async"/"exit"` 三档） | ✅ `RetryPolicy(max_attempts=3)` + 指数退避 + jitter | ⚠️ **靠 `error_handler` 路由到另一节点实现**（Saga 模式），非内建"换路"原语 | ✅ `interrupt()` 无限等待 + `Command(resume=)` | ✅ **Graceful shutdown**：`RunControl.request_drain()` → `GraphDrained` + 可恢复 checkpoint，同 config `invoke(None, config)` | 🟢 纯 Python 库 | [fault-tolerance](https://docs.langchain.com/oss/python/langgraph/fault-tolerance) [interrupts](https://docs.langchain.com/oss/python/langgraph/interrupts) [persistence](https://docs.langchain.com/oss/python/langgraph/persistence) |
| **Temporal** | ✅✅ **Event History + Replay**（代码 `effectively once`，崩溃后从最新状态恢复） | ✅ Activity 默认带 Retry Policy（Workflow 默认不带） | ⚠️ 同样要靠 `error_handler`/Activity 路由 | ✅ **Signals / Queries / Updates** 三种消息原语 | ✅✅ 最强：Worker 崩溃自动 replay 恢复 | 🔵 **需起 server**（自托管 v1.30+ 或 Cloud） | [workflow-execution](https://docs.temporal.io/workflow-execution) [retry-policies](https://docs.temporal.io/encyclopedia/retry-policies) [event-history](https://docs.temporal.io/encyclopedia/event-history) [message-passing](https://docs.temporal.io/encyclopedia/workflow-message-passing) |
| **Claude Agent SDK** | ⚠️ **只恢复对话历史，不恢复文件**——文档原话："Sessions persist the conversation, **not the filesystem**" | ❌ 未见 per-agent 超时/重试策略 | ❌ 无"换路"概念；有 `fork`（复制历史另起分支） | ✅ `AskUserQuestion` 在 loop 内处理 | ✅ 会话落盘，`resume=<id>` / `continue: true` | 🟢 SDK（跑 Claude Code 二进制） | [sessions](https://docs.claude.com/en/docs/agent-sdk/sessions) [subagents](https://docs.claude.com/en/docs/agent-sdk/subagents) |
| **OpenAI Agents SDK** | ⚠️ Sessions 存**会话历史**（SQLite/Redis/SQLAlchemy/Mongo/Dapr），非工作流状态 | ⚠️ 有 Run error handlers，但**不是"路"级别的超时** | ❌ 无 | ✅ `interruptions` + `to_state()` + `approve()` | ⚠️ 同 session 可续，但**不是工作流级恢复** | 🟢 Python/TS SDK | [sessions](https://openai.github.io/openai-agents-python/sessions/) [human-in-the-loop](https://openai.github.io/openai-agents-python/human_in_the_loop/) |
| **CrewAI** | ⚠️ `@persist` + `kickoff(inputs={"id":...})` 恢复 / `restore_from_state_id=` fork | ⚠️ 未在 flows 页找到显式重试装饰器文档 | ❌ 无 | ✅ `@human_feedback`（需 ≥1.8.0），LLM 把自由反馈坍缩成枚举结果 | ⚠️ 依赖 `@persist` 已落盘 | 🟢 Python 库 | [flows](https://docs.crewai.com/en/concepts/flows) |
| **Mastra** | ✅ **Snapshots**（含各步状态 + 已完成步输出 + **剩余重试次数**），持久化到 storage | ✅ 有 error handling 页 | ❌ 无 | ✅ suspend/resume + Human-in-the-Loop 页 | ✅ **Time travel**：从任意 step 重跑（`timeTravel()`） | 🟢 Node 库 + storage | [snapshots](https://mastra.ai/en/docs/workflows/snapshots) [suspend-and-resume](https://mastra.ai/en/docs/workflows/suspend-and-resume) [time-travel](https://mastra.ai/en/docs/workflows/time-travel) |
| **Inngest** | ✅ **step 级 checkpoint**：完成的 step 结果被保存，后步失败只重跑它 | ✅ step 级 | ❌ 无（只有 step retry） | ✅ `step.waitForEvent` / `waitForSignal` | ✅ | 🔵 需 Inngest 服务（可 self-host） | [steps-workflows](https://www.inngest.com/docs/features/inngest-functions/steps-workflows) |
| **Prefect** | ✅ "**Resume interrupted runs from the last successful point**" | ✅ 文档有专页 "Automatically rerun a workflow when it fails" | ❌ 无 | ✅ "Pause flows for human intervention or approval" | ✅ | 🔵 需 Prefect server | [intro](https://docs.prefect.io/v3/introduction) [retries](https://docs.prefect.io/v3/how-to-guides/workflows/retries) |
| **Airflow** | ⚠️ 有 Resumable Tasks 页，但**粒度是 task 不是 task 内部步骤** | ✅ Retry Policies + **Task Instance Heartbeat Timeout** | ❌ 无 | ✅ Sensors（等条件） | ⚠️ task 级 | 🔵 需 Airflow | [tasks](https://airflow.apache.org/docs/apache-airflow/stable/core-concepts/tasks.html) |
| **Pydantic AI（多引擎）** | ✅ 抽象出统一 durable 执行层，**8 个引擎**（Temporal/DBOS/Prefect/Restate/AWS Lambda/Kitaru/Airflow/Absurd） | ✅ 引擎各给 | ❌ 无 | ✅（引擎各给） | ✅ | 取决于引擎 | [durable-execution](https://pydantic.dev/docs/ai/capabilities/durable_execution/overview/) |

### 3.1 对照表的三条读法（这才是重点）

1. **「断点续跑」列几乎全是 ✅，但对本项目价值不大。** 原因：这些框架恢复的是**进程内存里的编排状态**（Temporal replay / LangGraph checkpoint）。**本项目的编排状态从头到尾就该写在磁盘 JSON 里**——进程死了文件还在，不需要 replay。**这一列的 ✅ 对本项目是溢出的能力。**

2. **「超时换路」列几乎全是 ❌——包括 Temporal 和 LangGraph。** 这是本次调研最重要的单条发现（**文档**，逐页核对）：
   - LangGraph 最接近的是 `error_handler`，文档明确说"**fires only after the retry policy is exhausted**"——即"重试到死才换"，**不是"卡住了就换一路并行重做"**。
   - Temporal 需要自己用 Activity 路由实现。
   - 其余全部没有。
   - **本项目的 §2.5「冻结原路 → 派 `segNb` 从断点秒重做 → 新旧择优合入」是一条业务规则（带 `resume_from` 证据复用、单写者台账、SEAM 缝语义），任何通用框架都不会内建它。** 这恰好证明：**换框架救不了这个病，因为这个病是业务语义，不是技术能力。**

3. **唯一值得记住的框架进展是 LangGraph 1.2（2026-06 前后）**，它新增的 `TimeoutPolicy(idle_timeout=...)` + `runtime.heartbeat()` 正是本项目 09 号报告设计的 T-HEARTBEAT 触发器。**但这套机制对本项目是杀鸡用牛刀**——本项目的"路"是**不可中断的子 Agent**（opencode 子 Agent 跑起来不能被外部插入心跳），而 LangGraph 的 heartbeat 是**节点内部主动调**。要用它，就得把 14 路扫描改写成 LangGraph 节点，即**放弃 opencode 子 Agent**。这是本报告反对换框架的最硬一条依据。

> **文档声称 vs 实测可用·风险提示**：本次**未运行任何框架**（遵守 `AGENTS.md §2`）。上表所有 ✅ 均来自官方文档页，**未经本机验证**。已知需警惕的三处：
> - LangGraph 的 `timeout=` **只对 async 节点生效**，sync 节点带 `timeout` 会在 compile 时被拒（文档明载）。若误把 ffmpeg 调用包成 sync 节点会直接编译失败。
> - LangGraph `interrupt()` 放在循环里会导致**指数级重放**（文档有专门警告，本项目若照搬"重试即换路"会踩到）。
> - Temporal 的 **Workflow Pause 仍是 pre-release**：Cloud 需邀请、self-hosted 需 v1.30+ 且开 `frontend.WorkflowPauseEnabled`。
> - CrewAI 文档明示：`restore_from_state_id` 找不到对应快照时**静默回退**（"falls back silently"）——这种静默降级在生产编排里是危险的。

---

## 4. 流式/增量合并：技术早就成熟，本项目卡在自己写的规则上

### 4.1 成熟模式确认

| 模式 | 成熟度 | 证据 |
|---|---|---|
| **增量归并**（每路回来即并一次，不等全齐） | ✅ 各框架原生：LangGraph superstep 语义、Inngest `step`、Mastra snapshot | 文档（§3 表） |
| **扇出并行 + 单点汇合** | ✅ 标准图模式；Pydantic AI 甚至专门做了 `DynamicWorkflow`，让模型写一段 Python 在 sandbox 里 fan-out/chaining/voting/retry，**中间结果不进父上下文** | [dynamic-workflow](https://pydantic.dev/docs/ai/harness/dynamic-workflow/) |
| **区间在线聚类**（按时间轴做可增更新的聚类） | ⚠️ **未找到**专门框架原语——这是业务算法（战斗 episode 边界判定），任何框架都不会内建 | 未找到 |
| **事件流驱动合并** | ✅ `GET /api/event`（本项目 harness 自带）+ LangGraph `stream_events(v3)` | 实测（端点存在） |

### 4.2 本项目的问题不是技术，是规则自相矛盾（文档，项目内）

09 号报告 §4.1 已判定，此处复核确认逻辑成立：

| 规则出处 | 内容 | 后果 |
|---|---|---|
| `roughcut-launch.md §2.3` | 「字幕员、渲染员、自审员**只认冻结版，不认 partial**」 | partial 无合法下游 |
| `§2.8` | 「partial 命名 `merge_decision_vN-partial-r{k}`（**永不转正**，只能被修线员重算替代；**字幕/渲染/自审禁认 partial**）」 | 同上 |
| `§2.8` | 「（合并**在途 1**、**离线岛 →**）…只有离线岛有排空价值」 | 岛式合并只在低价值场景生效 |

**推论（推断）**：一个产物若下游无人授权消费，实践中必然零产出。**这不是执行不到位，是设计上的死结。**

**最小修法（只改规则，不动代码）**：给 partial **新增一个且仅一个**合法消费者——**预览员**，产出 `preview\wip\<序号>-wip-r{k}.mp4`，并加四条护栏（带水印、按 `wip-` 前缀拒收、禁进 QA、下一版落地即删）。**收窄禁令而非放宽**：字幕员/验收员/成片渲染员仍只认冻结版。

**收益（推断，据 09 号报告 §8 时间账）**：861 的 26/29 路在 partial 阶段白等 8.42 h。partial 提前可消费后，"还在等最后 3 路"不再等于"用户看不到东西"。

---

## 5. 成本与并发：并行上限到底受什么限制

### 5.1 先纠正一个前提

**推断**：本机（8 核 / 16 线程 / 31 GB RAM / RTX 4060 Ti 8GB）**不是并行瓶颈**。Agent 推理在云端，本机只做 ffmpeg 编解码，且 NVENC 是硬件编码。**加并发不会因为本机而变慢。**

### 5.2 真正的三个瓶颈（按严重度排序）

#### 瓶颈①：磁盘 —— 已实测爆掉，且这是本次最重要的发现

**实测**（本机 opencode v2.0.22）：

```
C:\Users\Administrator\.local\share\opencode\opencode.db  =  14.30 GB
  ├ session_message.data 合计   15,249,948,372 bytes (14.20 GB)
  ├ 大于 1 MB 的消息：3,784 条，合计 12,775.7 MB (89% 的库)
  └ session 681 个（664 个是子会话），message 37,831 条
```

**根因实测**（解剖最大的一条消息 `msg_0f5dc2006001lh5efAnMcZvTL6`，16.15 MB）：

```
/content[2]/state/content[1]/uri   4,446,591 bytes  'data:image/png;base64,iVBORw0KGgo...'
/content[3]/state/content[1]/uri   4,155,642 bytes
/content[4]/state/content[1]/uri   4,059,954 bytes
/content[5]/state/content[1]/uri   4,250,726 bytes
→ base64 总量 16.1 MB = 消息的 100%
输入路径：...\21.864...\shots\seg8_sheets\sheet01_f00001.jpg
工具：read（status=completed）
```

**即：子 Agent 每 `read` 一张联系表 JPG，opencode 就把图片转成 base64 PNG、连同工具结果永久写进 SQLite。单张约 4 MB。**

官方文档印证（<https://opencode.ai/v2/docs/attachments/>，**文档**）：

> `max_base64_bytes` 默认 `5242880`（5 MiB）；`auto_resize` 默认 `true`，会**逐步尝试更小的 PNG/JPEG 编码直到满足 base64 上限**。
> "These settings apply both to supported images **attached to prompts and to images returned by the built-in read tool**."

**实测的 4 MB/张 正好顶到这个 5 MiB 上限**——说明联系表分辨率（2560×1440）太高，opencode 一直在贴着上限存。

**为什么这比 9.3 小时干等更严重**（推断）：

| 维度 | 干等 9.3 h | DB 14.3 GB |
|---|---|---|
| 影响范围 | 单次任务 | **所有后续任务**（DB 只增不减，freelist=0 说明无空间可回收） |
| 后果 | 用户等 | 备份变慢、查询变慢、**随时可能撑爆磁盘** |
| 可逆性 | 任务结束即恢复 | **不可逆**（无自动清理机制） |
| 治理 | 规则层 | **一个配置项** |

**修法（一行配置，推断 + 文档支撑）**——在项目 `opencode.json` 加：

```jsonc
{
  "$schema": "https://opencode.ai/config.json",
  "skills": ["./skills"],
  "media": {
    "image": {
      "auto_resize": true,
      "max_width": 1600,          // 2000 → 1600
      "max_height": 1600,
      "max_base64_bytes": 1048576  // 5 MiB → 1 MiB
    }
  }
}
```

**预期收益（推断）**：单张 4 MB → ≤1 MB，**新任务 DB 增量降约 75%**。联系表本来就是 12 格拼图，降分辨率对判定"有没有战斗/边界在哪"的影响远小于它对磁盘的影响。

> ⚠️ **注意与 `AGENTS.md §9` 的关系**：50 图红线是**单次请求携带的图片数**上限；`max_base64_bytes` 是**单张图片的字节数**。**两者正交，改配置不违反红线。**

> ⚠️ **存量 14.3 GB 怎么处理**：本报告**不建议**擅自删——`AGENTS.md` 与 opencode 官方都强调 session DB 是用户数据（`opencode uninstall --keep-data` 才保留 session）。**删库属破坏性动作，须用户确认。** 且需先备份。

#### 瓶颈②：上游 50 图红线（项目硬约束）

**实测（项目文档）**：`AGENTS.md §9` + `IMAGE_LIMIT.md` —— 单次请求图片总数 ≤50，累计口径；单轮新增 ≤10。

**推论（推断）**：这条**不是并行度的限制，而是"每路 Agent 一次能看多少"的限制**。14 路并行时，每路各有独立 50 图预算（不同会话），**总预算不被 14 路共享**。所以 14 路并行在这条上完全合法。

**但有一个真实约束（实测）**：单路扫 85 秒素材，`shots\segN\` 有 1237 帧（实测，864）+ 108 张联系表（实测，864，12 格/张）。**单路必须靠联系表压缩才装得进 50 图**——这与 `§2.3` 强制"看图前先跑 `check_image_budget.ps1`"一致，且说明**现行 14 路 × 85 秒的切分粒度是按 50 图红线倒推出来的，不宜盲目加密**。

#### 瓶颈③：云端限流（文档，非本机瓶颈）

**文档**（<https://platform.claude.com/docs/en/api/rate-limits>）：Start tier = 1,000 RPM / 2,000,000 ITPM；Build = 5,000 RPM / 5,000,000 ITPM。**按模型分别计算**，不同模型可同时打到各自上限。

**推断**：14 路 × 每路几分钟一次请求 ≈ 数十 RPM 量级，**远低于任何 tier 的下限**。**云端限流不是本项目的瓶颈。**

**文档**（同页，重要）：**acceleration limits** —— "usage 的**突然增加**本身就会触发 429，即使在 tier 上限之内"。原文建议："**ramp up your traffic gradually**"。

**推论**：这对"14 路后台一次全发"（§2.2 明文规定）是一个**文档级警告**。若某天把并发从 14 提到 30+，可能撞上加速限制而非 tier 上限。**记录为约束，不是当前问题。**

### 5.3 2026 年提高有效并行度的实践（可用 vs 不可用）

| 实践 | 可用性 | 依据 |
|---|---|---|
| **降低单路图片字节**（`media.image.*`） | ✅ **立即可用**，直接降 DB 增量与上下文 token | 文档（attachments）+ 实测（14.3 GB） |
| **用事件流代替轮询**（`GET /api/event`） | ✅ 可用，但**注意文档明说 volatile**——不能当可靠心跳源 | 实测（端点存在）+ 文档（"Volatile by contract"） |
| **prompt caching** | ✅ 官方明确"Cache reads as 0.1 tokens per token" | 文档（service-tiers） |
| **模型分层路由**（Haiku 跑初筛、Sonnet 跑判定） | ⚠️ **本项目不建议**——战斗判定是**质量关键**路径，`time-budget.md` 已定"视觉代偿更吃帧"，换小模型会推高看图量，反而更贵 | 推断 |
| **提并发到 30+** | ❌ **不建议**——受 50 图红线与 DB 膨胀双重约束，且可能触发 acceleration limits | 推断 + 文档 |
| **换模型提速** | 🟡 边际收益有限——本项目瓶颈是"图片进上下文的字节数"，不是 token 生成速度 | 推断 |

---

## 6. 落地建议（按依赖排序）

```
第 0 步（自做，零风险，即时收益 ~12 GB/若干任务）
        项目 opencode.json 加 media.image 限幅
        → 不改任何规则、不改任何脚本，纯配置
        ⚠️ 存量 14.3 GB 的清理/备份须用户确认后再做

第 1 步（自做，地基，其余全挂在它上面）
        reports\delivery_state.json  schema + dispatch_watchdog.ps1 + resume_task.ps1
        看门狗只用 §2.2 的 opencode 端点，不引入任何依赖
        → 立刻有：超时换路可计算、中断可续、机器可读状态

第 2 步（自做）
        台账补列：派工时间 / 心跳 / 回收时间 / attempt / 父路
        → 缺回收时间 = 超时换路在数学上不可算

第 3 步（需点头：改用户自己立过的规则）
        §2.3/§2.8 授权"预览员"吃 partial，并加四条泄漏拦截
        → 回收 8.42 h 的"等齐才合"等待

第 4 步（自做，防御）
        cleanup_after_master.ps1 加护栏：非 DELIVERED 态拒删 cache\
        → 修掉"resume 实现被自己删掉"这个死循环
```

**为什么第 0 步排最前**：它不依赖任何人点头、不改任何规则、**收益立刻体现在磁盘上**，而且它是唯一一条**不做就会持续恶化**的（DB 只增不减）。其余四步都是"修好编排"，第 0 步是"止血"。

---

## 7. 每条结论的证据等级汇总

| 结论 | 等级 |
|---|---|
| opencode API 提供 9 个编排原语（含 wait / interrupt+resume / fork / revert / event） | **实测**（`openapi.json` 117 路径逐条核对，本机 v2.0.22） |
| opencode.db 14.30 GB，89% 来自 >1MB 消息，根因是 read 图片的 base64 | **实测**（SQLite 只读查询 + JSON 逐层 walk + 正则普查） |
| 单张联系表 ≈ 4 MB base64，顶到 5 MiB 默认上限 | **实测**（4,446,591 bytes 等 4 条实测值） |
| `max_base64_bytes` 默认 5242880、`auto_resize` 默认 true、覆盖 read 工具 | **文档**（opencode attachments） |
| 项目无任何 watchdog/resume/state 脚本 | **实测**（目录列举） |
| 864 台账表头 5 列、无时间戳 | **实测**（文件逐字读取） |
| LangGraph 1.2 的 TimeoutPolicy/RetryPolicy/error_handler/drain | **文档**（fault-tolerance 页 + changelog） |
| Temporal 的 Event History/Replay、Signals/Queries/Updates、Workflow Pause 仍 pre-release | **文档**（temporal.io 多页） |
| CrewAI `restore_from_state_id` 找不到时静默回退 | **文档**（flows 页明载 "falls back silently"） |
| LangGraph interrupt 在循环里导致指数重放 | **文档**（interrupts 页专门警告） |
| **所有框架都没有内建"换路"原语** | **文档**（逐页核对，见 §3.1 第 2 条） |
| Anthropic 各 tier 限流数值、acceleration limits | **文档**（platform.claude.com） |
| 「不换框架、自建够用」 | **推断**（基于上面前 10 条 + `AGENTS.md §2` 环境铁律） |
| 「50 图红线不限制并行度」 | **推断**（各路独立会话，预算不共享） |
| 「模型分层路由对本项目净负面」 | **推断**（质量关键路径 + 视觉代偿更吃帧） |
| 框架的「断点续跑」对本项目价值不大 | **推断**（本项目状态本就在磁盘，replay 能力溢出） |

**明确的未找到**：
- **「区间在线聚类」的框架级原语** —— 未找到；判断为业务算法，不属框架职责。
- **CrewAI Flows 的显式重试装饰器文档** —— 在 flows 页未检索到 `@retry`（该页现存 `@human_feedback` 与 `@persist`）。**未找到 ≠ 不存在**，仅记录为未确认。
- **opencode 是否有官方"子 Agent 超时"配置** —— 文档未见。`agents.*.steps` 限的是**模型步数**，不是墙钟时间。这正是需要自建心跳的原因（§2.3）。