# 20 · VLM 在 FPS / 游戏画面上判读「有没有在交战中」的公开评测调研

调研日期 2026-10-05 ｜ 调研人：aivideo 子会话（角度：模型看图这条路的天花板）
标注体系：**实测**（本项目/论文实测数字）｜**文档**（论文或官方页面明写）｜**推断**（我据证据外推）｜**未找到**（搜过，确认没有）

---

## 0. 一句话结论（先看这个）

> **有公开评测，而且结论对本项目不利但有用**：最强模型在 FPS 电竞画面上的准确率天花板是 **~71%**（GPT-5 @ EgoEsportsQA），人类 80.5%（@GameplayQA）/ 72%（@FPS-Bench）。
> 更要紧的是：**零样本 VLM 连「现在是不是在交战中」这个粗粒度二分类都做不好** —— GameVibe 实验里零样本 ~57%，低于「猜多数类」的 67.2% 平凡基线。
> 天花板不在「分辨率不够」，在**语言先验短路**（模型看的是「这帧红不红、刺不刺激」，不是「这局有没有在打」）。

---

## 1. 有没有针对 FPS / 游戏画面的 VLM 评测？—— **有，7 个以上，都近两年**

| 名称 | 时间 | 规模 | 覆盖游戏 | 与本项目判据的距离 | 链接 |
|---|---|---|---|---|---|
| **EgoEsportsQA** | 2026-04 | 1745 QA / 364 clip / 7.5h | CS2、Valorant、OW2 | **最近**：FPS 第一人称、电竞、信息密集 UI | [arXiv 2604.12320](https://arxiv.org/abs/2604.12320) |
| **GameplayQA** | 2026-03 | 2365 QA / 100 视频 / 9 游戏 | CS2 / BF / Apex / … | **最近**：多视角同步、密集标签（1.22 标签/秒）、专门诊断幻觉 | [arXiv 2603.24329](https://arxiv.org/abs/2603.24329) |
| **Do VLMs Understand Human Engagement in Games?** | 2026-03 | 9 款 FPS × 59 个 1 秒窗 | CS:GO 系列、Apex、BF42… | **判据几乎同构**：High/Low engagement = 「在激烈交战」vs「菜单/空场景」 | [arXiv 2603.18480](https://arxiv.org/abs/2603.18480) |
| **FPS-Bench** | CVPR 2026 | 1000+ QA，高帧率 | 通用（含高速运动） | 回答「抽帧能不能省」 | [CVPR2026](https://openaccess.thecvf.com/content/CVPR2026/papers/Choudhury_FPS-Bench_A_Benchmark_for_High_Frame-Rate_Video_Understanding_CVPR_2026_paper.pdf) |
| **CUBench / CombatVLA** | ICCV 2025 | 914 QA（Black Myth / Sekiro） | 3D ARPG 战斗 | **战斗理解**基准，直接问「敌人血量高不高」「当前是什么状态」 | [arXiv 2503.09527](https://arxiv.org/abs/2503.09527) |
| **Can LLMs Capture Video Game Engagement?** | 2025-02 | GameVibe 80 分钟 / 20 款 FPS | 20 款 FPS | 第一个系统性问「LLM 能不能标 FPS 交战强度变化」 | [arXiv 2502.04379](https://arxiv.org/abs/2502.04379) |
| **Gameplay Highlights Generation**（AMD） | 2025-05 | 自建 kill/death 事件集 | 多个 FPS | **唯一 >90% 的结果**，但是**微调后**的 X-CLIP | [arXiv 2505.07721](https://arxiv.org/abs/2505.07721) |
| 辅助类：MVBench / Video-MME（esports 子类）/ lmgame-Bench / GameVibe / Sunain Gameplay 数据集 | — | — | — | 通用基准或数据集，非游戏专用判据 | — |

**「永劫无间」专门的 VLM 评测/数据集：未找到。**（搜了英文与中文关键词，naraka + benchmark / gameplay dataset / VLM，无相关成果。项目里那份 19 号素材不存在于公开评测集。）

---

## 2. 主流模型在游戏画面上的已知弱点（有量化）

### 2.1 总体天花板

**文档**，EgoEsportsQA Table 2（1fps、720p、四选一）：

| 模型 | 感知层 | 推理层 | 总分 |
|---|---|---|---|
| GPT-5 | 74.36 | 67.98 | **71.58** |
| Doubao-Seed-1.8 | 65.62 | 55.91 | 61.38 |
| Gemini 3 Flash | 56.66 | 40.81 | 49.74 |
| Claude-Sonnet-4.5 | 55.34 | 47.24 | 51.81 |
| Qwen3-VL-8B | 55.54 | 43.44 | 50.26 |
| InternVL-3.5-8B | 39.88 | 35.17 | 37.82 |
| LLaVA-OneVision-7B | 34.18 | 32.68 | 33.52 |
| 随机猜 | 25 | 25 | 25 |

三个要命的读法：

1. **最好的模型 71.58%，也就是说四选一里每四题错一题多。** 拿它做「这一秒在不在交战」的裁决，误判率约 30%。
2. **开源小模型基本在随机线上下。** Qwen3-VL-8B（50.26）≈ Gemini 3 Flash，比 Gemini 2.5 Pro 低 20 分。本项目能跑得起的本地模型全在这一档。
3. **纯文本（不看图）24.47% ≈ 随机 25%** —— 作者特意做了 anti-leakage 处理，保证不能靠游戏知识猜。这一条同时说明：**这类判据必须真的看图，不能指望模型"懂游戏"**。

### 2.2 三个已被量化的失效模式

**(a) 面板 / 结算屏 = 「不激烈」—— 这就是本项目的「把战斗中开面板读成面板段」**（**文档**，arXiv 2603.18480 §5.3 Failure Mode 3）

> "VLMs cannot distinguish active gameplay from post-match screens. Scoreboards showing close victories are high-engagement moments for human annotators, but VLMs classify them as 'static, no active gameplay' and predict Low."

CS:GO Office 上 **20 个 false negative 里 18 个**属于这一类。

**这一条直接命中本项目的核心事故模式（961/863/864 三次「面板段挖掉整场战斗」）。** 也就是说：本项目踩的坑不是本项目特有的低级错误，是当前 SOTA 模型上被公开测量到的系统性偏差（18/20 = 90% 的漏判都长这样）。

**(b) 「红色 = 激烈」的视觉强度偏见**（**文档**，同文 §5.1）

> CSGO18 上 VLM 预测与「视觉强度」（饱和度/边缘密度/亮度方差/红通道强度）的相关 r=0.432 (p<0.001)，**而人类标注与视觉强度无相关（r=−0.193, p=0.143）**。

作者结论：VLM 做的是**视觉强度分类**，不是交战判读。模型看到红色 HUD（敌方血条、红色方向雪佛龙、红色状态横幅、红色振刀徽章）就判 High。

**这在机制上就是本项目 9 类误读源里「红色/血量样式」为什么排第一。** 视觉强度指标里明确包含**红通道强度**——模型对红色的响应是训练出来的通用先验，不是逐游戏学的。

**(c) 其他 agent 的身份归属最差**（**文档**，GameplayQA Table 4）

| 实体类别 | 全模型均值 |
|---|---|
| World-Object（世界物体） | **62.0**（最好） |
| Self-Action（自己动作） | 56.5 |
| Self-State（自己状态） | 61.0 |
| **Other-Action（他人动作）** | **54.0**（最差） |
| **Other-State（他人状态）** | **55.4** |

作者结论：MLLM 在多人场景里难以归属 agent。**「那是谁」判不准，是公开测量过的最弱一档。**

**(d) 时间一致性几乎为零**（**文档**，arXiv 2603.18480 §5.4）

| 指标 | VLM 预测 | 人类标注 |
|---|---|---|
| 相邻窗翻转率（CSGO18） | **0.310** | 0.017（VLM 高 18 倍） |
| lag-1 自相关（CSGO18） | 0.275 | 0.950 |

**同一段素材相邻两秒，VLM 可能一帧判 High 一帧判 Low。** 本项目若用 VLM 输出直接切边界，边界会在 ±数秒内抖动。

**(e) 空间/时序推理的通用瓶颈**（**文档**）Fu et al. *Hidden in plain sight*（[arXiv 2506.08008](https://arxiv.org/abs/2506.08008)）：VLM 在视觉中心任务上大幅低于直接读视觉编码器，**掉到接近随机**（对应任务降 45.5%，深度估计降 21.7%）；且**给一张纯黑图，VLM 的答案分布与给真图几乎一样**——它本来就在用语言先验答题。

补充（[arXiv 2604.02486](https://arxiv.org/abs/2604.02486)，2026-08）：这个 gap 的机制是**语义锚定**——视觉实体能被命名时，模型跳过像素比较直接走语言；不能命名时，模型编造描述反而把推理搞坏（Qwen3VL-2B 在「未知形状」上 CoT 反而掉 19.4 分）。

**对本项目的直接含义**：**「敌方红血条」「伤害数字 37」「击杀播报」这些是模型里有现成名字的语义锚，会触发最强语言先验、最容易误判。** 这解释了为什么这 9 类是最高频误读源——它们恰好落在模型最自信的那条通路上。

---

## 3. HUD / 小字识别的量化下限：分辨率

### 3.1 有公开评测，两组互相矛盾的结论，**必须按任务类型分开看**

**（A）任务依赖 UI 数字时，分辨率是硬约束**（**文档**，EgoEsportsQA Table 5，Gemini 3 Flash，1fps）

| 输入分辨率 | 感知 | 推理 | 总分 |
|---|---|---|---|
| 256×144 | 30.52 | 30.05 | **30.32** |
| 640×360 | 47.41 | 36.48 | **42.64** |
| **1280×720** | 56.66 | 40.81 | **49.74** |
| 1920×1080 | 50.76 | 36.48 | **44.53** |

原文归因：**144p / 360p 崩塌是 "severe UI blindness where crucial numbers and minimap icons become entirely illegible"** —— 与本项目「联系表/低分辨率读不出来的东西不许当结论」完全同型。

⚠ **两个反直觉的点，本项目必须知道**：
- **1080p 比 720p 差 5.2 分**。作者归因于固定上下文预算下的 token 压缩 / 空间切片 / 位置编码错配。
- 这跟本项目「成片用 4K 母版」不矛盾：**成片渲染 ≠ 分析输入**。分析喂 4K 全帧可能比喂 1280×720 更差。

**（B）任务依赖运动时，分辨率无关**（**文档**，FPS-Bench 补充材料 Fig.1）

> "Figure 1b shows that the accuracy does not degrade with lower resolution. These results provide strong evidence that FPS-Bench's difficulty is due to the inherent difficulty of high-frame-rate understanding rather than low-resolution samples."

**结论（推断）**：**「读小字 HUD」和「看高速运动」是两个正交的失效通道。** 拿 640/915px 那套阈值去套运动判据是错的，反之亦然。

### 3.2 与本项目实测对照

**实测**（本项目 `.scratch/imgbudget2/10-final-verdict.md`）：敌方红血条 ~8px 高 → 需 **640px**；伤害数字 ~18–24px → 需 **768px**；击杀播报横幅 ~14px → 需 **915px**；4×4 联系表折算 392×220 **实测失败**，2×2 @960 折算 784×441 **实测通过**。失败区间被双向夹在 ~441px。

**实测**（L-044）：640px 联系表 **5/5 路全错**。

**对照结论（推断）**：本项目的 640 / 768 / 915 与 EgoEsportsQA 的 360(→42.64) / 720(→49.74) 拐点**落在同一区间**，且本项目用实测夹逼把它收得更紧（~441px 是硬失败线）。**这不是巧合，是同一个"字高 ≥ 4px 才能渲染"约束的两个独立测量。** 本项目那条 960px 规格站得住，有外部背书了。

---

## 4. 「有没有在交战中」这个判据：必须看序列，且序列不能长

### 4.1 序列是必需的（**文档**，GameplayQA Table 5，GPT-5-mini 退化消融）

| 输入条件 | 全部分数 |
|---|---|
| 完整视频 | 62.7 |
| **打乱帧序** | 54.8（掉 7.9） |
| **只给 1 张随机帧** | 41.7（掉 21.0） |
| 完全不给视频 | 29.4（掉 33.3） |

即：**序列提供约 +21 分，单帧提供约 +12 分，语言先验约 +29 分（相对无图）。** 「省抽帧」在 L2 推理任务上直接砍掉三分之一的可得分。

### 4.2 但序列也不能长（**文档**，EgoEsportsQA Table 6）

| 时间上下文窗口 | 总分 |
|---|---|
| Local（只在锚定区间内，平均 10.2 秒） | 55.59 |
| **Expanded（±5 秒余量）** | **56.28（最好）** |
| Global（整段视频） | **49.74（最差）** |

原文：「Irrelevant frames introduce visual noise, which disperses the model's attention and impairs accurate temporal grounding.」

### 4.3 抽帧率也不是越高越好（**文档**，EgoEsportsQA Table 4）

| 抽帧率 | 感知 | 推理 | 总分 |
|---|---|---|---|
| 0.5 fps | 49.24 | 38.58 | 44.58 |
| **1.0 fps** | 56.66 | 40.81 | **49.74（最好）** |
| 2.0 fps | 46.19 | 39.11 | 43.09 |

2fps **反而比 1fps 差 6.6 分**，归因 "contextual overload and attention dilution"。

**但这跟 FPS-Bench 冲突**（**文档**，FPS-Bench）：其基准平均 minFPS = **6.8 FPS**（下限阈值 4 FPS），远高于 EgoEsportsQA 的 1fps 最优。VLM 在 FPS-Bench 上只有 **30%**，人类 **72%**。

**调和（推断）**：EgoEsportsQA 的 1fps 是「当前模型架构下能承受的最优抽帧」，FPS-Bench 的 6.8 minFPS 是「人类判断这类高速事件所需的最低帧率」。**两者说的不是同一件事：前者是模型的可用上限，后者是任务的信息下限。** 落在 1 fps 的抽帧，对「持续存在的交战状态」够用；对「瞬时的一次击杀/受击」必然漏。

**⇒ 对本项目的具体判据拆分（推断）：**
- 「**在不在交战**」= 持续状态 → 1 fps + 局部 ±5 秒窗口，够用。
- 「**这一秒有没有击杀/受击**」= 瞬时事件 → 需要 ≥7 fps，单帧必漏。项目当前 1fps 抽帧在这类判据上**系统性漏报**。

---

## 5. 三条路对比：看图 vs 听声 vs 看数字

### 5.1 「三类零看图判据都定不了『那是谁』」——**核实结果：结论成立，且有公开证据**

**文档**（GameplayQA Table 4）：
- World-Object 62.0 / Self-State 61.0 / Self-Action 56.5 / **Other-State 55.4 / Other-Action 54.0**

其他 agent 的动作与状态归属是全部类别里最差的两项，比世界物体低 7–8 分，比「自己的状态」低 6 分。作者归因：MLLM struggle with other agent attribution in multi-agent scenes。

**文档**（EgoEsportsQA，模块化微调实验 Table 7）：只用**虚拟**第一人称数据微调 Qwen3-VL-8B 后：
- 推理分 42.00 → 45.67（有提升）
- 但 MVBench 的 Egocentric Navigation（真实世界）33.50 → 36.00

作者的推论很关键：**"egocentric reasoning logic is somewhat transferable, while visual perception remains domain-dependent."** 第一人称的**逻辑结构**可迁移，**视觉感知**不能。

**⇒ 核实结论（文档支持）**：项目那条「零看图判据都是定位器/验收器、不是裁决器，定不了『那是谁』」**成立，且被独立测量过**。数值/结构/文本判据能把「第几秒、变了没、想干啥」定下来，是因为这些是**世界/自身**层面的量；而「那是谁」落在 **Other-Agent** 那一格，恰恰是全场最弱的一格。

**补充一层（推断）**：但它弱的方式很具体——不是完全看不见人，是**看见一个人形但定不了身份**。配合 arXiv 2604.02486 的语义锚定结论：**「敌方红血条上的名字」如果有名字，模型能读；「这是不是同一批人里的那一个」模型定不了。** 本项目 864 归档里反复出现的「名牌到底是队友『吃什么饭.』还是敌人」正是这一格。

### 5.2 听声音这条路：公开证据最薄，但方向对

**文档**（BattleSound, Sensors 2023, [doi 10.3390/s23020770](https://www.mdpi.com/1424-8220/23/2/770)）：PUBG 真实对局音频，两任务 0.5 秒标注粒度——
- 武器声事件检测（WSED）准确率 **>90%**
- 语音活动检测（VCAD）准确率 **>90%**
- 摘要：「in extremely noisy environments」

**文档**（BGG dataset, IEEE CoG 2022, [arXiv 2210.05917](https://arxiv.org/abs/2210.05917)）：从 PUBG 游戏内采集 2195 个枪声样本，37 种枪械、5 个方向、6 个距离，验证「能判断枪声类型与方位」。

**文档**（EgoEsportsQA Table 3，Gemini 3 Flash）：

| 模态 | 感知 | 推理 | 总分 |
|---|---|---|---|
| 仅文本 | 24.01 | 25.07 | 24.47 |
| 文本+视觉 | 56.66 | 40.81 | 49.47 |
| 文本+视觉+**音频** | 57.27 | **49.74** | **53.98** |

**加音频让感知几乎不动（56.66→57.27），但推理涨了 8.9 分（40.81→49.74）。** 作者归因：FPS 里的听觉线索（脚步方位、技能语音）承载了「看不见的隐藏状态」，是高层战术推理必需的信息。

**⇒（推断）音频的价值恰好落在本项目最缺的那格。** 本项目现在把音频主要当「转写人声」用（找交战词），但证据表明它的更大价值是**推理补盲**：视觉给「看得见的敌人」，音频给「画外/视野外的敌人」。

**但必须说清楚（未找到 / 局限）**：
- 「用音频单独判『在不在交战中』」的公开评测：**未找到**。BattleSound 是**专用小 CNN 微调**，不是通用音频 LLM，也不是端到端「交战状态」判据。
- 通用音频大模型的**时间定位能力很差**（**文档**，[arXiv 2511.11039](https://arxiv.org/abs/2511.11039)）：Qwen2-Audio 零样本的边界 F1 仅 **6.7 / 9.8**，作者结论「struggles to accurately link temporal locations with acoustic semantics」。**⇒ 音频可以判「有没有」，很难判「第几秒」。** 这正好呼应本项目的 `engage_start`（第几秒接战）极度难定的历史。

### 5.3 看数字（OCR / 像素）：本项目已在用，且外部背书最扎实

EgoEsportsQA 自己的数据管线就是**用 Qwen3-VL-8B 定位关键 UI 元素（计时器/计分板/击杀信息）+ EasyOCR 提文字**来做切段（§3.1 Stage 2）——**即：连做这个 benchmark 的研究者，在需要精确秒级标注时也是走「定位 UI + OCR」，不是靠 VLM 「看画面感觉」**。这是对本项目现有技术路线的第三方背书。

**文档**（EgoEsportsQA 自己也记录了 OCR 方案的一个失败模式）：seg20 那类「顶部播报」必须从 y=0 起扫，裁切窗设错会整条切在窗外 → 零结果播报的**伪阴性**。这与本项目 864 归档里「回查顶部播报的裁切窗必须从 y=0 起」**是同一个 bug，同一条教训，两个团队各踩一次。**

---

## 6. 天花板在哪，需要什么兜底

### 6.1 天花板（推断，基于上述公开数字）

| 层级 | 能做 | 不能做 | 依据 |
|---|---|---|---|
| **粗粒度「这帧有没有激烈交火」** | 可用（~57–70%），但**低于平凡基线的风险真实存在** | 不可作为唯一裁决 | GameVibe 57% vs 多数类 67.2% |
| **「这是不是面板段」** | ❌ 不可靠，18/20 漏判同型 | 必须外部规则兜底 | 2603.18480 §5.3 |
| **「敌方是不是队友」/「那是谁」** | ❌ 最弱一档 | 只能用名牌色/编号槽位等结构判据 | GameplayQA OA 54.0 / OS 55.4 |
| **「第几秒接战」** | ❌ 单帧/稀疏帧会偏 20 秒 | 需逐秒 + 局部窗口 | 本项目 864 实测 ±20s；EgoEsportsQA Global 窗口最差 |
| **「有没有击杀/受击」（瞬时）** | 零样本 ❌；**专用微调模型可以 >90%** | 零样本路线放弃 | FPS-Bench 30% vs 人类 72%；AMD X-CLIP 微调 >90% |

**一句话天花板：当前零样本 VLM 在「这秒有没有在交战」这个判据上，可靠性上限约 57%–71%，且低于「猜多数类」的情形已经实测出现。它不能当裁决器，只能当「值得多看一眼的地方」的排序器。**

### 6.2 兜底方案（按性价比排序）

1. **保留项目现有的非 VLM 硬判据**（像素计数 / OCR / 数值 / 结构），不引入 VLM 做裁决。理由：GameplayQA 的 Other-Agent 数字说明，VLM 在身份归属上比结构化判据更弱；项目的结构化判据（ann2 红像素计数、plate_red、名牌槽位编号、局内时钟）在这件事上**没有已知更差的替代品**。
2. **VLM 只用于「生成候选 + 排序」，且必须双路互证**。EgoEsportsQA §5.2 说人类专家标注共识是必须的；项目已有多路对抗审制度，方向一致。
3. **分析输入锁 1280×720 / 1fps / 局部 ±5 秒窗口**。理由：EgoEsportsQA 实测这是当前架构的最优点（49.74），而 1080p 与 2fps 都更差。这与项目「初筛 320 → 判定 640 → 定点 960」的三级规格不冲突：320 用来定位、960 用来定点取证，**但不要把 960 帧当批量的默认分析输入**。
4. **专项做一件公开评测没做的事：本地「交战 vs 非交战」小样本评测集**。理由：公开评测全是 CS/Val/OW/ARPG，**永劫无间零覆盖（未找到）**；且公开数字全部是「别人的游戏」，跨游戏迁移性论文明确说「视觉感知 domain-dependent」。
5. **不要指望「多给点上下文」变好**。EgoEsportsQA 全局窗口最差、FPS-Bench 6.8minFPS 是任务需求不是模型能力——这两条说明：**当前架构下，上下文不是解药。**
6. **音频当互补位而不是替代位**。EgoEsportsQA 加音频 +4.2 总分 / +8.9 推理分，值得做；但音频 LLM 时间定位 F1 只有 ~10（2511.11039），**不能用来定 `engage_start`**。

---

## 7. 明确标注「未找到」的三件事

1. **永劫无间（或任何第三人称武侠 BR）的 VLM 评测/数据集：未找到。** 所有公开 FPS 评测都是 CS2/Valorant/OW2/Apex/BF/PUBG/ARPG。
2. **「只看几帧就能判断在不在交战中」的公开量化研究：未找到专门研究。** 最接近的替代证据是 GameVibe 实验里**只给 1 秒窗 16 帧**仍只有 57%（且低于多数类基线）——即：**在 1 fps 抽帧下这个判据都不成立，不必再考虑更激进的省帧方案。**
3. **「用通用音频大模型判 FPS 交战状态」的公开评测：未找到。** 只有专用微调小模型（BattleSound WSED/VCAD >90%）和「音频作为 VLM 附加模态的增益」（EgoEsportsQA）。

---

## 8. 与本项目已有结论的对照表

| 本项目结论 | 外部证据 | 判定 |
|---|---|---|
| 红/血量样式是最高频误读源 | 视觉强度偏见 r=0.432 含红通道强度（2603.18480 §5.1） | **外部支持** |
| 面板 ≠ 待清除 UI，按因果链判 | 「VLMs cannot distinguish active gameplay from post-match screens」，18/20 FN 同型 | **外部强力支持** |
| 640px 联系表 5/5 全错 | 360p → severe UI blindness（EgoEsportsQA） | **外部支持** |
| 红血条 640 / 伤害数字 768 / 横幅 915 | 720p 为拐点，1080p 反降 | **支持，且提示别用 4K 做分析输入** |
| 「零看图判据定不了那是谁」 | Other-Action 54.0 / Other-State 55.4（全场最差两项） | **外部支持** |
| 抽帧能不能省 | 1fps 最优、2fps 更差；全局窗口最差 | **不能省，但也不能更多** |
| 「瞬时事件」类判据（击杀/受击） | FPS-Bench：minFPS 6.8，VLM 30% vs 人类 72% | **1fps 系统性漏报，已知** |
| 音频目前只当转写用 | 音频 +8.9 推理分（隐藏状态推理） | **建议升级为推理补盲** |
| 「弹匣曲线不是零图判据」 | — | 本次调研范围外 |

---

## 9. 全部链接

- EgoEsportsQA（2026-04）https://arxiv.org/abs/2604.12320
- GameplayQA（2026-03）https://arxiv.org/abs/2603.24329
- Do VLMs Understand Human Engagement in Games?（2026-03）https://arxiv.org/abs/2603.18480
- Can LLMs Capture Video Game Engagement?（2025-02）https://arxiv.org/abs/2502.04379
- FPS-Bench（CVPR 2026）https://openaccess.thecvf.com/content/CVPR2026/papers/Choudhury_FPS-Bench_A_Benchmark_for_High_Frame-Rate_Video_Understanding_CVPR_2026_paper.pdf
- CUBench / CombatVLA（ICCV 2025）https://arxiv.org/abs/2503.09527
- Gameplay Highlights Generation（AMD, 2025-05）https://arxiv.org/abs/2505.07721
- Hidden in plain sight: VLMs overlook their visual representations https://arxiv.org/abs/2506.08008
- VLMs Need Words: Ignore Visual Detail In Favor of Semantic Anchors（2026-08）https://arxiv.org/abs/2604.02486
- Listening Between the Frames（LALM 时间定位弱）https://arxiv.org/abs/2511.11039
- BattleSound（游戏音频基准）https://www.mdpi.com/1424-8220/23/2/770
- BGG in-game gunshot dataset https://arxiv.org/abs/2210.05917
- Video-MME（含 esports 子类）https://arxiv.org/abs/2405.21075
- MVBench https://arxiv.org/abs/2311.17005
- lmgame-Bench（ICLR 2026）https://arxiv.org/abs/2505.15146