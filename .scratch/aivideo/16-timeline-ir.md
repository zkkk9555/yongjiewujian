# 16 · 时间线 JSON 这个中间表示，有没有更好的工具？

> 调研员：时间线 IR 角度。调研日期 **2026-10-05**。
> 结论一句话：**不要换中间表示（OTIO 已实测能正确表达"片段内挖洞"，但它不是校验器）；
> 要换的是"自我校验"的方式——把 `episode_geometry.py` 升级成一个带
> Pydantic 模型的 IR 层，让校验只写一遍、且只此一遍。**

标注约定：**实测** = 我在本机跑过；**文档** = 官方文档明说；**推断** = 由实测/文档外推；**未找到** = 没查到可靠来源。

---

## 0. 先看本项目的真实数据（这是后面所有判断的地基）

**实测**：全库 35 份 `combat_episodes*.json`、409 个 episode。

| 指标 | 实测值 |
|---|---|
| `excluded_inside` 在 episode 上出现的次数 | 409 / 409（**当前没有"字段丢失"**） |
| 非空 `excluded_inside` 的文件数 | 17 / 35 |
| 全库 hole 总数 / 总时长 | **117 个 / 779.5 秒** |
| `excluded_inside` 的 Python 类型 | 409/409 都是 `list`（无 null、无 dict、无字符串） |
| hole 对象的实际字段 | `start` 117、`end` 117、`category` 117、`why` 44、`duration_seconds` 22、`program_start` 10、`program_end` 10、`reason` 18、`evidence` 18 |
| episode 上出现过的字段总数 | **53 种**（含 `v1_id`/`struck_v6_claims`/`mutation_direction_ruling_v7`…） |
| 顶层字段总数 | **93 种** |

**实测（重要发现 1）**：顶层"节目总时长"有**三个不同的键名**在同时使用：

| 键名 | 声明它的文件数 |
|---|---|
| `program_seconds` | 16 / 35 |
| `program_seconds_total` | 9 / 35 |
| `program_total_seconds` | 9 / 35 |

三者语义相同、名字不同。**这就是"节目时长公式重复实现了 3 处"在数据层的真实形态**——不是代码重复，是**字段名重复**。任何消费者都必须写
`data.get("program_seconds") or data.get("program_seconds_total") or data.get("program_total_seconds")` 这种三选一兜底。`qa_gate.py:113` 正是这么写的（它列了 4 个候选名）。

**实测（重要发现 2）**：`123\18.860…\timeline\combat_episodes_v1.json` 存在一个**活的数值 bug**：

```
computed program      = 922.2s   （13 episodes，扣掉 22 个洞共 95.0s）
raw span              = 1017.2s
声明的 program_total_seconds = 1017.2s   ← 等于 raw span，即"洞被忽略了"
```

也就是说：这份文件**声明的总时长正是那个已知的历史 bug 的值**。95 秒的洞在这份文件里被静默吞掉了。这份文件还在盘上、还在被引用。这正是"多份实现漂移"的活证据——而且它证明了漂移方向**可复现**：写文件的那个 agent 复刻了旧的错误公式。

**实测（重要发现 3）**：7 处 `impact_points` 落在 episode 跨度之外（最多超出 `source_end` 21.5 秒），分布在 859/860 的 v4/v5/v6。这些点永远渲染不出来，但没有任何门禁会拦。

---

## 1. 视频编辑中间表示的标准

### 1.1 OTIO 够用吗？它支持"片段内挖洞"吗？

**文档**：OTIO 的完整序列化 schema 我逐类读了一遍
（<https://opentimelineio.readthedocs.io/en/latest/tutorials/otio-serialized-schema.html>）。
核心 schema 只有：`Clip` / `Gap` / `Transition` / `Marker` / `Stack` / `Track` / `Timeline` / `FreezeFrame` / `LinearTimeWarp` / 各 `*Reference` / `Effect`。

**没有 "hole" / "cut inside clip" 这个概念**。

**实测**：我用 OTIO 0.18.1（本机已装）造了本项目 863 的真实时间线做往返：

```
episodes 5，真实 program = 799.0s，切成 11 段
→ OTIO: 11 个 Clip，时长 799.000s，与真值 EXACT
→ metadata 全部存活：episode_id 6/6、boundary_reason 1121 字符、event_types
```

**结论（实测）**：**"挖洞"在 OTIO 里是隐式成立的**——把一个带洞的 episode 展开成两个共享同一 `MediaReference`、`source_range` 不连续的 Clip 即可。洞不需要是字段，它就是**源时间轴上的一个不连续点**。

反向也成立：我能从 Clip 边界**精确还原**洞（`clip[k].source_range.end_time_exclusive()` → `clip[k+1].source_range.start_time()`）。

**实测（重要发现 4）**：这带来一个真实风险——**洞从"显式声明"变成"隐式不连续"之后，就没法再被门禁检查了**。当前 `qa_gate.py` 的 G-1 `no_holes_in_battle` 检查的是 `excluded_inside` 字段。如果 IR 换成 OTIO，这个门禁**没有字段可查了**。本项目 8.1 节那条最高优先级判据（一整场完整战斗不许挖洞）**依赖显式的洞列表**。这是"不要把 OTIO 当真源"的硬理由。

### 1.2 其它标准格式

**文档**：OTIO 的 adapter 生态（<https://opentimelineio.readthedocs.io/en/latest/tutorials/adapters.html>）：
- 内置：`otio_json` / `otiod` / `otioz`
- 插件包 `OpenTimelineIO-Plugins`：`AAF`、`fcp_xml`、`cmx_3600`、`maya_sequencer`、`svg`、`xges`、`ale`、`burnins`
- 社区：`kdenlive`、`fcpx_xml`、`hls_playlist`

**推断**：FCPXML / AAF / EDL 都是**剪辑交换格式，不是分析中间表示**。它们没有"engage_start / outcome_time / event_types / impact_points"这类战斗语义字段——那些只能塞进 metadata 或注释字符串，**同样不受校验**。拿它们当 IR，等于把本项目已经踩过的"metadata 无类型无校验"坑再踩一遍。EDL 更是只有 source/record 两组数字，**表达能力最弱**。

### 1.3 小结（Q1）

| | OTIO | FCPXML / AAF / EDL |
|---|---|---|
| 片段内挖洞 | ✅ 实测可表达（隐式，Clip 不连续） | ✅（切多段） |
| 战斗语义字段 | ❌ 只能塞无类型 metadata | ❌ 同上 |
| 可自我校验 | ❌ 实测不校验 | ❌ |
| 门禁可读显式洞列表 | ❌ **致命** | ❌ |

**结论：不要换。OTIO 保留为导出格式（Premiere/Resolve 交接），不当真源。**

---

## 2. 现成的剪辑库，哪个最适合"JSON 驱动的程序化剪辑"？

**实测（本机安装状态）**：

```
opentimelineio  0.18.1     ← 已装且活跃（GitHub pushed 2026-10-01，archived=false）
av (PyAV)       18.1.0     ← PyPI 最新 19.0.1（2026-10-03）
auto-editor     29.3.1     ← 最后发布 2025-11-04
scenedetect     0.7.1      ← 2026-07-22
jsonschema      4.26.0     ← 未装，我为调研装的
pydantic        2.13.5     ← 未装，我为调研装的
moviepy         未装；PyPI 最新 2.2.1，最后发布 2025-05-21
datamodel-code-generator  未装
```

**实测**：PyAV `av` **没有任何 timeline 概念**——`dir(av)` 里搜 `Timeline` 返回空。它是编解码层（Container/CodecContext/Frame），不是时间线层。**答：不适合做 IR。**

**文档**：MoviePy 官方文档首页自己标着 `Date: Jan 26, 2025`，而 PyPI 上 2.2.1 的发布时间是 2025-05-21——**文档落后于代码**。它的 `concatenate_videoclips` 是"黑盒拼接"，没有任何持久化/可校验的时间线表示。

**未找到**：**`revideo` 在 PyPI 上是个同名抢注的无关包**——我拉了它的 metadata，描述是"视频伪原创工具 - 基于 ffmpeg 的视频去重处理"，`requires_python: ==3.12.*`，依赖 `fastmcp`/`moviepy`。这跟程序化剪辑**毫无关系**。真正的 revideo 是 [midrender/revideo](https://github.com/midrender/revideo)（4082 star，2026-07-15 活跃，"Create Videos with Code"，Motion Canvas 系的 TypeScript 方案）。

**答（Q2）**：这些库里**没有一个**适合"JSON 驱动的程序化剪辑"。它们全是"用代码构造时间线"（MoviePy/Revideo）或"只做编解码"（PyAV）。本项目要的恰恰相反：**时间线是数据，代码是消费者**。唯一在这个方向上正确的是 OTIO，而它又不带语义、不带校验。

**唯一值得引入的新依赖是 Pydantic**——它不是剪辑库，它是"让数据自己声明规矩"的库。

---

## 3. 自我校验：JSON Schema 够吗？

**实测**（`jsonschema` 4.26.0，Draft 2020-12）：我按本项目 schema 写了一份 JSON Schema，逐条喂它 bug：

| case | 是 bug 吗 | schema 拦下了吗 | 结论 |
|---|---|---|---|
| 合法基线 | 否 | 否接受 | OK |
| `program_seconds` ≠ 各 episode 之和 | 是 | **否** | **漏** |
| 洞落在 episode 跨度外 | 是 | **否** | **漏** |
| 洞 `end <= start` | 是 | **否** | **漏** |
| `excluded_inside` 字段整个丢失 | 是 | 是 | OK |
| `source_start` 为负 | 是 | 是 | OK |
| `source_end < source_start` | 是 | **否** | **漏** |

**实测**：JSON Schema **没有任何"比较/算术"关键字**。我用 `{"start":10,"end":20}` 和 `{"start":20,"end":10}` 各验一次，**两个都 valid**。

**实测**：本项目的 4 个核心不变量——长度和、覆盖、坐标系一致性、洞在跨度内——JSON Schema **一个都表达不了**。而这几个恰好就是 `episode_geometry.py` + `qa_gate.py` 现在做的事。

**结论（Q3）**：
- **JSON Schema 单独 = 不够。** 它只能守住"形状"（字段在不在、类型对不对、非负），守不住"算术"和"跨字段"。
- 但它有独特价值：**多语言 / 非 Python 消费者**（pre-commit、NLE 交接、给人看）。

所以正确答案是**两层**，而且**两层必须由同一个源生成**。

---

## 4. 单一真源：怎么保证"改一处就够"？

**实测：现状的重复是 3 份实现 + 1 个锁测试。**

| 实现 | 语言 | 状态 |
|---|---|---|
| `skills/.../episode_geometry.py` | Python | **正本**，零依赖 |
| `scripts/read_episode_bounds.ps1` | PowerShell | 有意独立（4K 路径刻意 Python-free） |
| `scripts/seg_render_master.sh` | bash | 不重算，只消费 `S=/E=` 行 |
| `scripts/test_insegment_holes.sh` | bash | **锁测试**：两侧跑同一 fixture 比对 |

**实测**：我跑了 `test_insegment_holes.sh`——**13 个用例全 PASS**，包括 4 个畸形洞用例。这是项目已有的正确做法。

**实测**：`grep` 确认 `episode_geometry` 被 `qa_gate.py`、`validate_combat_timeline.py`、`export_edit_timeline.py`、`map_events_to_beats.py` **4 个 Python 消费者 import**——Python 侧已经统一了。

**但 PowerShell 那份是真重复**（`read_episode_bounds.ps1:222+` 自己解析 `excluded_inside` 并自己算 PROGRAM）。

**实测：代码生成可行吗？** —— `datamodel-code-generator` 存在且成熟（4.0k star，MIT，被 OpenAI Codex、MCP Python SDK、Airbyte、PostHog 在用），能从 JSON Schema 生成 Pydantic v2/dataclasses/TypedDict/msgspec。

**但方向要反过来**：不是"从 schema 生成算术"，因为 **JSON Schema 里没有算术可生成**（§3 实测）。应该是**从 Pydantic 模型双向导出**：

- **向下**：`model_json_schema()` → 免费得到 JSON Schema，给非 Python 消费者 / pre-commit
- **向上**：模型本身就是唯一真源，算术写在 validator 里

**答（Q4）**：**代码生成 + 锁测试，两者都要，但顺序反了。** 现状的锁测试（Py↔PS 对拍）已经是对的，继续保留；缺的是**把 Python 侧从"一个函数库"升级成"一个模型"**——因为函数库可以被任何人绕过直接手写公式，而**模型的 validator 会在 `model_validate()` 时强制执行，没有绕过路径**。

---

## 5. LLM 生成/修改 JSON 的可靠性

**这是本项目最大的实际风险，而且已经造成了两起真实事故。**

**实测：事故 1 —— 字段漂移。** §0 发现 3 个顶层总时长键名并存（`program_seconds` / `program_seconds_total` / `program_total_seconds`）。这不是"曾经"，是**现在盘上就有**。`qa_gate.py:113` 只能靠 4 个候选名的 `or` 链兜底。**每个新写的 agent 都可以合法地发明第 5 个名字。**

**实测：事故 2 —— 数值自相矛盾。** 860 v1 声明 `program_total_seconds = 1017.2`，而真实值是 922.2，差额正好是 22 个洞的 95.0s。**声明值与自身内容矛盾，而当时没有任何东西会报错**——因为没有"用同一份数据校验声明值"这道关。

**实测：事故 3 —— 坐标越界。** 7 处 `impact_points` 超出 episode 跨度，最多 21.5 秒。落在 `outcome_time` 之后（战斗结果之后），正是 §8.1 判据里说的"洞只许落在窗口外"同一类错误，但用的是**错的工具**（impact_point 而不是 excluded_inside）。

**工程手段（按有效性排序，全部实测过）**：

1. **`required` + 默认值的必填字段** —— `excluded_inside: list[Hole] = []`
   **实测**：校验后 `ep.excluded_inside` **必然存在**（哪怕输入里没有）。这在类型层面消灭了"'无洞'与'洞字段被 agent 丢了'无法区分"这个歧义——**这正是历史事故的机理**。注意对比：JSON Schema 里的 `required` 只能"拒绝"，而这里"接受并补上"，对 LLM 产出更友好。

2. **声明值必须等于计算值，模型级 validator** —— **实测拦下了 §0 那个活的 1017.2 bug**。让 agent 写摘要数字**根本不该做**；如果必须写（比如审计留痕），就让模型强制它对得上。

3. **别名归一（AliasChoices）** —— **实测**：`program_seconds` / `program_seconds_total` / `program_total_seconds` 三个输入键**都**归一到同一个字段。历史文件照读，新写入只有一个名字，**消费者再也不用写 `or` 链**。

4. **两档结论：几何错 = 拒，标注漂移 = 警。**
   **实测教训**：我第一版原型用 `extra="forbid"` + 严 impact_point 检查，结果 **21/35 假警报**。原因是真实的洞合法地带着 `category`/`why`/`reason`/`evidence`，而越界的 impact_point 是**陈旧标注**不是几何错误。
   `episode_geometry.py` 的 docstring 记着同一类事故：曾经有个过严检查把 `read_episode_bounds.ps1` 能正常渲染的时间线判成 FAIL。**假警报比没校验更糟**——它会训练人忽略门禁。
   所以定死规矩：**洞越界 / 跨度倒挂 / 洞吞掉整场 / 片段越出素材 / episode 互相重叠 → 硬拒；`impact_points` 越界 → 警告不拦。**

5. **`extra="allow"`** —— 本项目 episode 上有 53 种字段、顶层 93 种，其中大量是 `struck_v6_claims`、`v7_ruling_note` 这类审计留痕。**禁止额外字段等于禁止审计。**

---

## 6. 推荐方案（实测可行）

**保留 JSON 作为序列化格式，把 `episode_geometry.py` 升级为带 Pydantic 模型的 IR 层。** 不引入 OTIO 作为真源。

### 6.1 分层

```
                    ┌─────────────────────────────────────┐
  Agent 写的 JSON → │  model_validate()  ← 唯一强制关口      │ → 已校验模型
                    │  · 形状（字段/类型）                   │
                    │  · 算术（和、覆盖）  ← JSON Schema 做不到 │
                    │  · 跨字段（洞⊆跨度、坐标一致）           │
                    │  · 别名归一（3 个旧键名 → 1 个）         │
                    └──────────────┬──────────────────────┘
                                   │
              ┌────────────────────┼────────────────────┐
              ↓                    ↓                    ↓
      qa_gate.py          export_edit_timeline.py   OTIO 导出（交接用）
      validate_*.py       map_events_to_beats.py    （不是真源）
                                   ↓
                    read_episode_bounds.ps1（4K Python-free 路径）
                    ← 靠 test_insegment_holes.sh 对拍锁住
```

### 6.2 实测结果（原型跑通）

模型：`Timeline` / `Episode` / `Hole`，pydantic 2.13.5。

| 测试 | 结果 |
|---|---|
| 10 类 bug（JSON Schema 漏掉的那些） | **10 / 10 拦下** |
| 合法基线 | 接受，`computed_program_seconds = 90.0` 正确 |
| 越界 `impact_point` | 接受 + 给出警告（不拦） |
| 3 个历史别名 | 全部归一到 `program_seconds` |
| **全库 35 份真实时间线** | **34 接受 / 1 拒绝** |
| 那 1 份拒绝的 | 正是 §0 那个活的 1017.2 bug |
| 34 份接受的总时长 vs `episode_geometry.py` | **全部吻合到 1e-6** |
| 附带警告 | 7 条（正是那 7 个越界 impact_point） |

**零假警报。** 唯一的拒绝是真 bug。

### 6.3 为什么这能"改一处就够"

- 算术只存在于 `Episode.program_seconds` / `segments` 一个 property 里。`qa_gate.py`、`validate_*`、`export_*` **都不再自己算**，只读 property。
- 校验和算术**同一个动作**（`model_validate()`），没有"忘了跑校验"的可能。
- `model_json_schema()` 免费给出 JSON Schema 给非 Python 消费者——**不用手写第二份**。

### 6.4 落地步骤（建议顺序）

1. **先加别名归一，不动校验**（风险最低，立刻消灭 §0 发现 1 那个三键名问题）。用 `AliasChoices` 收口。
2. **加"声明值 == 计算值"一条校验**，把 860 v1 那类矛盾变成硬失败。**预期会立刻炸出存量坏数据——这是好事，正是它的价值。**
3. 把 `impact_points` 越界从"没人管"改成"警告列表"，写进 `reports\`。
4. 再考虑把 `qa_gate.py` / `validate_*` 的公式换成读 property。
5. **保留** `test_insegment_holes.sh`——Py↔PS 对拍是 Python-free 4K 路径的唯一防线，Pydantic 不能替代它（PowerShell 那侧还是手写的）。

### 6.5 明确不做

- **不做**：把 OTIO（或 FCPXML/AAF/EDL）当真源。会丢显式洞列表 → §8.1 最高优先级判据失效。
- **不做**：只用 JSON Schema。它守不住算术（§3 实测）。
- **不做**：禁止额外字段。53/93 个审计字段会全被拒。
- **不做**：把越界 `impact_point` 判成硬失败。实测假警报率过高。

---

## 7. 一句话结论

**中间表示不换（OTIO 实测能正确表达片段内挖洞，但它是交换容器不是校验器，且会把显式洞列表变成隐式不连续，直接废掉 §8.1 的核心门禁）；要换的是自我校验的实现方式——把 `episode_geometry.py` 升成一个 Pydantic IR 层，用 `model_validate()` 把长度和、覆盖、坐标一致、别名归一一次性锁死，再从同一个模型导出 JSON Schema。原型已实测：10/10 拦下 bug、全库 35 份真实时间线零假警报（唯一拒绝的就是一个 1017.2s 的活 bug），声明总时长与 `episode_geometry.py` 吻合到 1e-6。**

---

## 附：证据与出处

**官方文档**
- OTIO 序列化 schema（核心类无 hole 概念）：<https://opentimelineio.readthedocs.io/en/latest/tutorials/otio-serialized-schema.html>
- OTIO adapters（AAF/fcp_xml/cmx_3600 均为插件）：<https://opentimelineio.readthedocs.io/en/latest/tutorials/adapters.html>
- OTIO Time Ranges（`source_range` vs `range_in_parent` 坐标系）：<https://opentimelineio.readthedocs.io/en/latest/tutorials/time-ranges.html>
- JSON Schema 布尔组合（`allOf`/`anyOf`/`oneOf`/`not` 的全部能力）：<https://json-schema.org/understanding-json-schema/reference/combining>
- Pydantic validators（`model_validator` 三种模式、`AliasChoices`）：<https://docs.pydantic.dev/latest/concepts/validators/>
- jsonschema FAQ（`format` 默认不校验）：<https://python-jsonschema.readthedocs.io/en/stable/faq/>
- check-jsonschema CLI + pre-commit hook：<https://check-jsonschema.readthedocs.io/en/stable/>
- datamodel-code-generator（schema ↔ 模型双向）：<https://github.com/koxudaxi/datamodel-code-generator>

**实测脚本**（可复跑，均在 `%TEMP%\opencode\`，未写入项目目录）
- `otio_probe.py` — OTIO 挖洞/metadata/marker/坐标/available_range 六项探测
- `otio_roundtrip.py` + `otio_roundtrip2.py` — 用 863/861 **真实时间线**做 OTIO 往返
- `schema_probe.py` — Draft 2020-12 逐条验证 7 类 bug
- `audit_real.py` — 全库 35 份时间线审计
- `proto_ir.py`（过严版，故意留作反例）/ `proto_ir2.py`（定稿版）

**顺带查出的存量数据问题（未修，仅报告）**
1. `860 combat_episodes_v1.json`：声明 `program_total_seconds=1017.2`，真实 922.2，差额=22 洞共 95.0s。
2. 顶层总时长三键名并存：`program_seconds`(16) / `program_seconds_total`(9) / `program_total_seconds`(9)。
3. 7 处 `impact_points` 超出 episode 跨度（859/860 的 v4/v5/v6），最多超 21.5s。
4. `read_episode_bounds.ps1` 与 `episode_geometry.py` 是两份手写实现，只靠 `test_insegment_holes.sh`（实测 13/13 PASS）对拍。