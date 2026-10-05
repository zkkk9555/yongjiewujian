# 12 · 从「一堆时间戳+文本」自动切出「候选片段」，有没有成熟方法？

调研日期 **2026-10-05** · 调研人：aivideo 子会话（角度：候选片段自动抽取 / 合并去重）
标注约定：**实测**（本机跑过或本项目数据实测）｜**文档**（论文/官方页面明写）｜**推断**（据证据外推）｜**未找到**（搜过，确认没有）

---

## 0. 一句话结论

> **有成熟方法，而且成熟的那部分恰好不是「合并裁定」而是「候选生成」。**
> 2026 年最可抄的是 **REZE**（arXiv:2608.04480）：**clip 级 Yes/No 的 logits → 逐秒分数曲线 → 确定性算法切区间**
> （均值中心化 + Kadane 最大子段 / Otsu 多区间）。**免训练、聚合环节完全确定性、模型不产生时间戳。**
> 但它有两个对本项目致命/关键的限定：
> ① **只给"检测"不给"边界"**——论文原话是 *detects most sub-clip moments; what a single clip-level score cannot supply is their sub-clip boundary*（≤10s 的片段 mAP 只有 **5.39**）；
> ② 它依赖的 VLM 判据在本项目姊妹报告 20 里已被实测为弱项。
> **结论：自动化「14 路读图判断有没有战斗」这一层，保留「合并裁定」这一层。**

---

## 1. 先把本项目的真实数据摆出来（后面所有判断的地基）

### 1.1 864 合并这一步的输入形态 **实测**

`123\21.864…\timeline\combat_episodes_v3.json` 头部：

```
"generated_from": [ "reports/seg1_scan_report.md", … "reports/seg14_scan_report.md" ]
```

14 份扫描报告的产物**已经是机器可读的**（`seg7_scan_report.md` 实测）：

| 报告里的东西 | 形态 | 合并时能不能直接用 |
|---|---|---|
| 段结论 | `有战斗 / 无战斗 / needs_review` | 能，三态 |
| episode 表 | `source_start / source_end / engage_start / outcome_time / event_types / confidence` | **能，纯数字** |
| 段内阶段分解表 | 源秒 / 阶段 / 依据 / 处置 | 能，且这是最有价值的 |
| `deleted_inside` | `start / end / category / 证据` | 能 |
| 边界证据 | 「≥2 独立信号」的自然语言 | **不能，这正是要自动化的部分** |

**实测**：合并之所以慢，**不是因为缺结构**——结构是齐的。慢在两件事：

1. **跨段边界的语义裁决**。`seg7_scan_report.md` 原文：「**最要紧的一条：510.0 不是段边界，是交战正酣处**」——seg6/seg7 的分片线切在一场仗中间。
2. **间隙的性质判断**。`complete-combat-roughcut.md` R3 判据表明确写「**不要用『间隙 ≤ N 秒就并入』这种纯计时判据，逐帧核实间隙里到底在干什么**」，并把 864 六版返工归因于此。

**推断**：所以「自动合并」的可自动化边界很清楚——**区间并/拆/延本身可以确定性做；「间隙里在干什么」是那个必须保留判断的部分，而它恰好可以用一条分数曲线去逼近**（见 §5）。

### 1.2 全库已标注数据（这是本报告最重要的一条实测）

**实测**：脚本扫全部 `123/*/timeline/combat_episodes*.json`，每任务取最高版本：

| 任务 | 版本 | 素材时长 | 战斗内时长 | 占比 | episodes |
|---|---|---|---|---|---|
| 13.849 | v8 | 2399s | 1174s | 49% | 13 |
| 14.854 | v6 | 1094s | 732s | 67% | 12 |
| 15.855 | v6 | 1154s | 761s | 66% | 17 |
| 16.858 | v3 | 1112s | 729s | 66% | 8 |
| 17.859 | v5 | 2399s | 900s | 37% | 20 |
| 18.860 | v7 | 2398s | 1196s | 50% | 15 |
| 19.861 | v9 | 2399s | 1125s | 47% | 14 |
| 20.863 | v6 | 1122s | 679s | 61% | 6 |
| 21.864 | v3 | 1152s | 799s | 69% | 5 |
| **合计** | | **4.23 h** | **2.25 h（8095s / 15230s = 53%）** | | **109** |

另有 **117 条 `excluded_inside`**（洞）标注。

**按 3 秒 clip 切分：2698 个正样本 + 2378 个负样本。**

**推断**：这就是 §4 那条路线（微调一个小 CLIP 系分类器）所需的**全部训练数据，而且已经躺在盘上、标签是用户审过片的最终版**。同类工作里 X-CLIP 那篇报告 >90% 准确率只用了自建数据集；本项目的 5076 个 clip 属于同一游戏、同一 UI、同一镜头风格，**域内程度远高于任何论文基准**。

---

## 2. Q1 · 转写 + 音频活动 + 视觉变化 → 自动候选边界，有成熟做法吗？

**有，但没有一个统一叫「unstructured to structured video」的端到端管线；成熟的是三类零件。**

### 2.1 视觉侧：把「场景变化检测」从像素差升级成语义差

| 方法 | 时间 | 做法 | 对本项目 |
|---|---|---|---|
| **STITCH** — *Training-Free Temporal Abstraction for General Video Understanding* | 2026-08（NeurIPS 2026 投稿） | 冻结 video-text backbone 嵌入短窗，**检测嵌入序列的变化**切成语义 chunk；chunk 算一次、跨任务复用。在通用事件边界检测、语言 moment retrieval、长视频抽帧三个任务上都与专用方法相当 | **文档**。它直接对标本项目 PySceneDetect 的位置：同样是"切边界"，但切的是语义边界而非像素边界。**未找到公开实现** |
| ConsensusTAS | 2026-08 | label-free 自监督，**利用候选分割之间的内部一致性**；GTEA F1@10 73.08 / Breakfast 64.33 / Assembly101 F1@50 33.50，**可 CPU 跑** | **文档**。「候选分割取共识」这个思路对本项目的 14 路合并有直接映射 |

- STITCH：https://arxiv.org/abs/2608.27929
- ConsensusTAS：https://arxiv.org/abs/2608.24043

### 2.2 音频侧：一句必须记住的实测数字

**DCASE 2026 Challenge Task 6 = Audio Moment Retrieval from Long Audio**（https://arxiv.org/abs/2609.12484）

- 任务定义：给几分钟长录音 + 一句自由文本 query，检索出匹配的 (start, end) 时刻。
- **基线 R1@0.7 = 13.56%**；21 支队伍 59 个系统，**前三名 R1@0.7 = 48.59%（约 3.5×）**。
- 前三名能赢的两个共同手段：**confidence score calibration** 与 **跨时间分辨率特征做 ensemble**。

**推断（重要，别被论文数字误导）**：这是**有监督、专门训练**的系统在**评测集**上的成绩。48% 的 R1@0.7 意味着**即使专门训过，一半以上的时刻定位是错的**。这条对本项目的意义是——**任何声称「音频活动 + ASR 就能切准边界」的说法都要打折**；本项目现有做法（`analysis\audio_activity.json` 54 KB、`combat_voice_index.json` 26 KB 当筛选信号）是**正确定位**，不要指望它替代画面判读。

配套基准：CASTELLA（https://arxiv.org/abs/2511.15131），人类标注的音频 AMR 基准，论文明确说此前 AMR 只在**合成数据**上训过。

### 2.3 Q1 小结

**推断**：融合是成熟做法，但**融合的位置应该是"打分"而不是"下判决"**。ASR / 音频活动 / 场景变化三者各自产出一条 noisy 曲线，融合成一个 `s(t)`，然后由确定性算法切——这条路线有论文、有实测数字；让 LLM 直接吐时间戳则没有（见 §6.3 REZE 的 D 段诊断）。

---

## 3. Q2 · Video Moment Retrieval：能不能用「交战中」当 query 找所有战斗片段？

### 3.1 这个问题在 2026 年确实被正式命名了，而且就是本项目的形状

**这是本次调研最关键的发现。** 传统 VMR 假设「一句 query 对应一个片段」，而本项目要的恰恰是「一句 query 对应**一堆**片段」。这个问题 2026 年有两个独立团队正式命名并各给了基准：

| 名称 | 出处 | 定义 | 域 |
|---|---|---|---|
| **GMR / Soccer-GMR** | https://arxiv.org/abs/2605.02623 （2026-05-04）<br>代码+数据：https://github.com/dymm9977/generalized-moment-retrieval | 检索**相关时刻的完整集合**，或**预测空集**；基准含真实负样本 query 与正样本 query；指标分别覆盖 null-set 拒绝 / 正样本定位 / 端到端 | **足球**（体育转播、连续对抗）——**与永劫同属"连续对抗类体育"，是最接近的域** |
| **FlashMMR / QV-M²** | NeurIPS 2025 poster：https://neurips.cc/virtual/2025/poster/118798<br>代码：https://github.com/Zhuo-Cao/QV-M2 （实测 stars=9，pushed 2025-11-28） | Multi-Moment Retrieval：一句 query 对应多个时刻；数据集 QV-M² 含 2212 标注 / 6384 片段；多时刻**后验校验模块**——先做受约束的时间微调，再用校验模块重评候选，低置信提案被剪掉 | YouTube 高光 |

**推断**：GMR 的"**或预测空集**"这一半对本项目价值最大——本项目每份素材确实存在"整局没有像样战斗"的可能，需要一个能说"**这一段没找到任何战斗**"的机制，而不只是"没找到就是没找到"。

**注意 FlashMMR 的可用性边界（实测）**：README 明确要求**下载 QVHighlights 视频与 query 特征、下载 checkpoints、在 `data/MR.py` 上跑 `FlashMMR/inference.py`**——**它是在 QVHighlights 上训练过的判别式模型，不能零样本用于永劫**。论文自己也说 retrain 了 6 个既有 MR 方法才拿到这个结果。**结论：可读方法，不可直接跑。**

### 3.2 ⭐ REZE：本项目唯一真正可以直接照抄的算法

**REZE: Recognition-Based Zero-Shot Extraction for Video Temporal Grounding** — Boyang Li, Chenhui Gou, Jianfei Cai，2026-08-05
https://arxiv.org/abs/2608.04480 ｜HTML 全文：https://arxiv.org/html/2608.04480v1 ｜ **未找到公开实现（GitHub 搜 "REZE temporal grounding" 无结果）**

**为什么它对**：它**恰好绕开了本项目的两个病**。

- 病一：让 VLM 直接吐 `start/end` → 结果强依赖模型，跨模型差异巨大。
- 病二：把时间聚合交给模型 → 无法调试、无法复现。

REZE 的三步（**文档**，以下全部是论文 §3.2/§3.3 与附录 A 的原话级描述）：

**① 切 clip + 要一个连续分数，不要一个判决**

clip = 短窗口 `F_i`（论文主实验 τ=3s，每 clip 6 帧）。不问模型「从几秒到几秒」，只问**二值验证题**：「这个 clip 里有没有 <query>？」然后

> 直接读 next-token 的 logits：`p_i = exp(ℓ_Yes) / (exp(ℓ_Yes) + exp(ℓ_No))`

论文明确说这样做的两个理由：
> "read the logits directly also avoids asking the VLM to generate a numerical score. Moreover, keeping `p_i` continuous **preserves confidence differences that hard thresholding would remove**."

→ **这条对本项目极其重要**：§9 的 50 张红线说明本项目被迫做二值化判断，而 REZE 的证据是二值化会主动扔掉置信差。

**② clip 分 → 逐秒曲线 s(t)**

每个整秒拿到覆盖它的那个 clip 的分数，**恢复时间顺序**，作为三种输出的共同输入。

**③ 外部确定性聚合（模型完全不参与）**

*单区间*：先**均值中心化**
```
s'(t) = s(t) − (1/⌊D⌋) Σ_u s(u)
```
> "Mean-centring prevents the non-negative curve from favouring the entire video."

再用 **Kadane 最大子段算法**找使 `Σ_{t_s}^{t_e−1} s'(t)` 最大的半开区间 `[t_s*, t_e*)`。

*多区间*：**固定** σ=3s 高斯平滑（**不是随时长缩放**），再用 **Otsu 法**从这条曲线自身分布里定阈值 θ，高于 θ 的连续区 = 排序后的候选区间。

### 3.3 REZE 的实测数字（全部**文档**，来自论文表格）

**聚合算法消融（Table 3A，Charades-STA train，mIoU，只换 extractor，复用同一批已存分数曲线）**

| extractor | mIoU |
|---|---|
| **均值平移 + 最大子段（论文采用）** | **53.49** |
| 累积和扫描 | 53.41 |
| 标准化累积和 | 53.21 |
| 中位数平移 + 最大子段 | 45.24 |
| 60/70/80 分位阈值 | 47.35 / 46.48 / 42.89 |
| 自适应 mean + k·σ（k=0.3/0.5/1） | 45.44 / 44.45 / 39.02 |

> "threshold-based extractors trail by 6 to 14 points, indicating that **the important design choice is to accumulate evidence relative to the video mean**."

→ **这条直接反驳本项目的一个既有隐含做法**：`complete-combat-roughcut.md` R3 明确否决「间隙 ≤ N 秒」这类阈值计时判据。REZE 用数据说明：**阈值化之所以输，是因为丢掉了"相对全片均值积累证据"这件事**。两者是同一个洞察的两种表述。

**多区间聚合消融（Table 3B，QVHighlights val，MR mAP）**

| 配置 | mAP |
|---|---|
| 均值阈值，σ=⌊D⌋/15（随时长缩放） | **20.76（灾难性）** |
| 均值阈值，σ=3s | 36.77 |
| 均值阈值，σ=2s | 39.74 |
| **Otsu 阈值，σ=3s（论文采用）** | **42.46** |

→ **踩坑警告**：平滑带宽**随时长缩放会崩**（1152s 的永劫素材会走进最差那档）。必须固定秒数。

**主结果**：QVHighlights training-free MR mAP **38.23 → 40.32**；HD **44.18 mAP / 73.41 HIT@1**，其中 HIT@1 **超过全部全监督 SoTA**。跨 7 个 backbone / 3 个家族，**在 Charades-STA 与 QVHighlights 上每一次可用对比都优于 Direct timestamp generation**。

### 3.4 ⭐⭐ REZE 最关键的一条限制（决定本项目该怎么用它）

论文附录 C 小节标题就叫 **"Short moments are detected, not delimited."**

| 指标 | 数值 |
|---|---|
| GT ≤ 10s 的片段，MR mAP | **5.39** |
| GT 中等 / 较长两组，MR mAP | 47.82 / 46.50 |
| 45 个"全部 GT 窗口 <10s"的 query，覆盖 GT 的 clip vs 同片非 GT clip 的 **per-query AUROC** | **0.84 – 0.87**（4 个 backbone 一致） |
| 同 query 的 GT/非GT 分数中位比 | 2.2× – 22.9× |
| 326 个 **≤2s** 的 GT 窗口（比 3s clip 还短）的 per-window AUROC | **0.71 – 0.76**，**72–82%** 的窗口分数高于本片非 GT clip |

论文原话：
> "The verifier therefore **detects most sub-clip moments; what a single clip-level score cannot supply is their sub-clip boundary**."

**推断（本报告的核心判断）**：这张表说明——

- **检测（这一秒在不在打）可以做得很准，AUROC 0.84–0.87；**
- **边界（从哪一秒开始、到哪一秒结束）单靠 clip 级分数做不到，误差下限就是 ±τ。**

对本项目的直接含义：**REZE 类方法应该当"候选生成器"，不该当"时间线生成器"。** 它替代的正是 14 路报告里"这一段有没有战斗"那个判断；`engage_start` / `outcome_time` 仍然要靠别的手段定（§7 给了两个）。

### 3.5 其余 VMR 方法的可移植性判据

| 方法 | 时间 | 关键做法 | 能否直接用于永劫 |
|---|---|---|---|
| **Self-SiMS** — Mitigating Modality and Language-Style Gaps for Zero-Shot VMR | **ECCV 2026** https://arxiv.org/abs/2607.19027 | **自相似度**替代 query-video 相似度：只用视频内部关系生成候选，避免语言风格鸿沟；再加 query-aware MLLM 推理阶段 | **文档**。思路值得抄：**永劫的战斗/舔包/跑图判据对任何自然语言 query 都该成立**，说明打分不该依赖 query 措辞 |
| ViLL-E / VeRVE | https://arxiv.org/abs/2601.12193 | 共享 MLLM backbone 生成视觉/文本 embedding，LoRA 在 700K 配对样本上训；**不额外训练即可零样本 moment retrieval** | 有 checkpoint 路线，但需 700K 级算力 |
| Moment-GPT | **AAAI 2025** https://arxiv.org/abs/2501.07972 | tuning-free 冻结 MLLM；LLaMA-3 先改写 query 消除语言偏差 → MiniGPT-v2 自适应生成候选 span → VideoChatGPT + span scorer 选段 | 论文自陈 query 改写是关键步骤——**推断**：中文战斗术语 + 固定 query 时这步收益不大 |
| MarkIt | https://arxiv.org/abs/2604.25886 | training-free 视觉标记，plug-and-play，不改 Vid-LLM 权重 | 未深查 |
| OpenVMR | https://arxiv.org/abs/2605.29812 | **开放集 VMR：用 normalizing flow 区分 ID/OOD query，OOD 直接拒答** | **推断**：这正是 GMR「或预测空集」的判别式版本，可作"本片无战斗"的拒答器 |
| TF-CADE | https://doi.org/10.48550/arxiv.2608.17422 | 零样本 Temporal Action **Detection**，前景集中的 text-video 对齐 | 零样本 TAL，方向对口 |
| EviDETR | https://arxiv.org/abs/2609.30724 | 联合 MR + HD；**MR2HD 用 confidence-weighted multi-scale aggregation** 把 span 级证据搬到 clip 级 | **文档**。"置信度加权多尺度聚合"正是 §5 要找的东西之一 |

**未找到**：永劫 / 第一人称吃鸡 / 武侠 ARPG 专门训练的 VMR 模型。

---

## 4. Q3 · Temporal action segmentation / detection 的 SOTA 与可复现实现

### 4.1 ⭐ 开放词表零样本 TAS——本项目判据的直接对口物

**OVTAS: Exploring Vision-Language Models for Open-Vocabulary Zero-Shot Action Segmentation** — **ICRA 2026**，https://arxiv.org/abs/2602.21406

- 提出 **Open-Vocabulary Zero-Shot TAS (OVTAS)** 这个问题本身，并给出 **training-free** 管线，**segmentation-by-classification** 设计：
  - **FAES**（Frame-Action Embedding Similarity）：把帧匹配到候选动作标签；
  - **SMTS**（Similarity-Matrix Temporal Segmentation）：强制时间一致性。
- 跨 **14 个不同 VLM** 做了系统研究（论文自称是该问题的首个广泛分析）。

**推断（对本项目非常关键）**：本项目的判据不是闭集标签，而是一组开放词表状态——`engage / melee / in_fight_loot / armor_swap / multi_kill / resupply / town_trade / between_battles_resupply / run_map`（`seg7_scan_report.md` 里出现的全部 `event_types` 与 `category`）。**OVTAS 的「帧→标签打分 + 相似度矩阵上做时间分段」正是把这类判据变成机器可算分数的现成框架**，而且免训练。

### 4.2 用项目自己的标注当先验修边界——最便宜的一条

**CAD: Improving Temporal Action Segmentation via Constraint-Aware Decoding** — **ICPR 2026**，https://arxiv.org/abs/2605.10149 ｜代码 https://github.com/LUNAProject22/CAD

> 把**可从标注数据直接提取的统计结构先验**（transition confidence、action boundary sets、per-class duration）整合进**改造过的 Viterbi 解码**，**推理时精修，无需重训、无额外模型复杂度**。

**推断**：§1.2 实测的 109 个 episode + 117 条洞，正好就是这套先验的原料。**这是本报告里投入产出比最高的一条**——不需要任何新模型，直接把人工合并的成果变成边界精修器，且可回溯（先验来自哪个任务、能追到源秒）。

**配套**：论文 §4.3 指出**标注成本集中在边界**（小的时间偏移会不成比例地拉低 segment 级指标）——这与本项目 §8.1「一场战斗不许被切断」的痛点同源。相关：B-ACT 边界中心主动学习（https://arxiv.org/abs/2604.15173）。

### 4.3 其余 TAS（按对本项目的可用性排序）

| 方法 | 时间 | 要点 | 判断 |
|---|---|---|---|
| **PEOT** — Probabilistic Embeddings for Unsupervised Action Segmentation | **ECCV 2026** https://arxiv.org/abs/2607.05263 ｜ https://github.com/derkbreeze/PEOT | 无监督 TAS 用最优传输产伪标签，改成**高斯概率嵌入**避免陷入局部最优；MoF 提升 **20.7%**、F1 提升 **19.0%** | 有代码。**推断**：无监督路线意义在于**新素材零标注时的冷启动** |
| Boundary regression + CDF segment regularization | **CVPR 2026 SAUAFG workshop** https://arxiv.org/abs/2604.01859 | 只加 1 个输出通道 + 2 个辅助 loss，**架构无关**，可直接挂在 MS-TCN / C2F-TCN / FACT 上 | **文档**：明写可即插即用于既有模型 |
| P-JEPA | https://arxiv.org/abs/2606.23256 | 稠密帧对齐动作空间 + 掩码潜向量预测，**可吃 30 分钟以上长视频**，实时 | 长视频表征 |
| M2R2 多模态机器人 TAS | https://arxiv.org/abs/2504.18662 | 本体+外感受多模态，特征可跨模型复用 | 域不符 |
| 骨架类（Spectral Scalpel / LaDy / MASQ / HSVQ） | 2026 多个 CVPR | 全是**骨架**输入 | **域不符**，永劫无骨架 |
| ZeProM | https://arxiv.org/abs/2606.21579 | 单个预训练 VLM 同时做 mistake detection + TAS，逼近/超过全监督 | 流程为程序性任务设计 |
| Towards Generalizing TAS to Unseen Views | https://arxiv.org/abs/2504.02512 | 未见视角泛化；egocentric 未见视角 F1@50 **+54%** | 视角泛化，有价值 |

**未找到**：任何在游戏画面上做过 TAS 的开源实现（除 §5.1 那篇 X-CLIP）。

---

## 5. Q4 · 14 路独立报告如何自动合并去重？有没有「区间聚类 + 置信度加权」算法替掉人工裁定？

**答：算法零件全都齐了；但没有任何论文做过「14 个 LLM agent 各报一段区间 → 自动合并」这个具体任务（未找到）。而且最好的答案其实绕开了"聚类"，见 §5.3。**

### 5.1 域内最接近的一篇（且是唯一一篇游戏域的）

**Gameplay Highlights Generation** — 2025，https://doi.org/10.48550/arxiv.2505.07721

- 做法：先定位"有趣事件"区间，再拼接。**明确对比并否决了**两条传统路——游戏引擎集成（要开发商配合，昂贵）、OCR 特定图像/文本 patch（每游戏工程化、跨游戏 UI 与语言不泛化）。
- 转而**微调 X-CLIP**（通用多模态视频理解模型）于自建 gameplay 事件数据集（VIA 标注器人工标注）。
- **文档**：> "such a finetuned model can detect interesting events in first person shooting games from unseen gameplay footage with **more than 90% accuracy**"
- **文档**：> 在**低资源游戏**上与高资源游戏一起训练时表现显著更好，"showing signs of **transfer learning**"。
- 部署：ONNX + **DirectML** 后端，Windows 推理；后训练量化降体积降延迟。
- **文档**：「自然语言监督（CLIP）带来的数据效率」。

**推断（本报告对 Q4 的真正回答）**：这篇论文比任何通用 VMR 都更贴本项目——它做的正是"**判断一段 FPS 画面里有没有值得剪的事件**"，而且证明了 **>90% 的准确率是靠微调小模型拿到的，不是靠通用大模型零样本**。加上 §1.2 实测的 5076 个域内 clip（2698 正 / 2378 负，同游戏同 UI 同镜头风格），**这是本项目风险最低、收益最高的一条路线**：模型只有 CLIP 量级，8 GB 显存吃得下，ONNX+DirectML 直接落 Windows，推理时零训练。

### 5.2 「区间聚类 + 置信度加权」——零件清单

| 需要的零件 | 有成熟算法/论文 | 出处 |
|---|---|---|
| 提案聚合去重 | soft-NMS / temporal NMS | 经典；Boundary-Matching Network https://doi.org/10.48550/arxiv.1907.09702 |
| **置信度加权**跨尺度聚合 | **EviDETR 的 MR2HD** | https://arxiv.org/abs/2609.30724 |
| **把"若干个互相冲突的分割"合成一个全局分割后验** | ⭐ **Segmental Posterior Decoding for Audio Moment Retrieval**：定义**时间分割上的全局归一化分布**，用**前向-后向推断**算每个候选的**精确边缘后验**，再把"一个前景跨度及其相邻细分"当作互斥假设放进训练空间 | https://arxiv.org/abs/2609.16495 ｜ CASTELLA 上 **41.15% R1@0.7 / 34.68% mAP，比同一网络 DETR slot 置信度高 10.91 / 9.20 个点** |
| 候选分割取共识 | **ConsensusTAS**（§2.1） | https://arxiv.org/abs/2608.24043 |
| 多 agent 报告的可信度加权 | Dawid–Skene 族；**Explainable modeling of annotations in crowdsourcing**（HCOMP 2019）https://doi.org/10.1145/3301275.3302276 | **文档** |
| 结构先验修边界 | **CAD**（§4.2） | https://github.com/LUNAProject22/CAD |

**推断**：把上面这几件按序拼起来就是一套**完整的、无需人工裁定的合并算法**：

```
14 份报告的区间  →  每条带 (source_start, source_end, confidence, 证据条数)
      ↓ 软聚类（重叠度 + 证据类别一致性）
候选簇（≈109 episode 的同构物）
      ↓ 分数加权：clip 分类器 s(t) × 各路 confidence × 互证信号数
带分数的簇
      ↓ 段内：用 s(t) 的累积证据定 engage_start / outcome_time（REZE 的均值平移 + 最大子段）
边界
      ↓ 间隙：读 s(t) 在间隙里的曲线形状（高→低→高 = 同一场，低谷平坦 = 换场）
合并/拆分判决 + 置信度
      ↓ CAD 的 Viterbi 先验精修（先验来自本项目 109 episode）
冻结时间线
```

**但请注意最后一步必须留人**：§8.1 的 `whole_battle_policy` 是用户专属判断，全库没有任何训练数据覆盖它，机器没有可学的标签。

### 5.3 ⭐ 最省事、也最该先做的一条

**根本不需要"聚类"。** 本项目 14 路是**按时间硬切分**的（`seg7` = `[510.0, 600.0)`），不是重叠采样。所以：

- **相邻簇合并**只要看**簇间是否相交或相接**，这是排序扫描 O(n)，不是聚类。
- 真正的判断只剩一个：**间隙里在干什么**。而这个判断 REZE 已经给了现成答案——**不要读帧，读 `s(t)` 在间隙里的曲线**：
  - 间隙内 `s(t)` 始终不低 → 同一场（战术停顿，含舔包/打药/拉开）→ **合并**，正好对应 R3 判据表的「拉开/打药/舔包/换装/重新进场＝合并」。
  - 间隙内 `s(t)` 掉到接近全片均值以下且平坦 → 换场 → 不合并，对应「换了对头/跑图/闲聊/结算＝分开」。

**推断**：这一步把 R3 从"逐帧核实"降级为"读一条曲线"，**而且 REZE 的 Table 3A 恰好证明这一层不该用阈值**（阈值法落后 6–14 个点），要与全片均值比较。这与本项目已经写下「纯计时判据是本次六版返工的根因之一」是同一条规律的两次独立发现。

---

## 6. Q5 · 把 14 路自由文本报告交给 LLM 自动合并成时间线 JSON——2026 年有可靠做法吗？

**有可用的分工原则，没有可靠的"一步到位"。而且有一条重要的负面证据。**

### 6.1 正面：LLM crowd 确实有 "wisdom of crowds" 效应，且聚合方式有定论

**Wisdom of LLM Crowds: Aggregation and Contamination in Language Model Ensembles** — 2026-05，https://doi.org/10.48552/arxiv.2607.18269 ｜期刊版 https://doi.org/10.1145/3839337

**文档**（15 个 LLM × 254 道二元预测题）：

> 学习式聚合器（MLP、logistic regression）**优于所有单个模型**；而 **MLP ≈ logistic regression** ——"suggesting benefit derives from **learning a linear combination of diverse model outputs** rather than nonlinear interactions"。

> 对该网络做符号化分析，最低复杂度的有用公式就是**纯粹的"模型分歧"信号** —— "further supporting this interpretation"。

→ **推断（对本项目非常实用）**：合并聚合器**不需要**复杂的东西。**"各路模型的分歧程度"本身就是最好的一个特征**——14 路一致的地方可信，14 路分歧的地方就该派人复核。这与项目 `roughcut-launch.md` §2.8 的"重叠带单裁决、双方互证失败不硬合"是同一条规律的两种表述。

**文档**（同文，污染警告，必须记）：训练截止污染是普遍混淆项——前沿云端模型对小模型的优势在**干净子集上从 35.8% 塌缩到 8.9%**。

→ **推断**：本项目 14 路若都是同一个模型 + 不同 prompt，**"模型多样性"这个聚合收益的前提就不成立**。想让聚合器真的学到东西，**至少要混 2–3 个不同家族/不同温度/不同 prompt 模板的扫描员**。这是一个便宜且具体的改法。

### 6.2 正面：可审计的分工是明确的方法论

**Self-prompting and cross-model consensus enable reproducible data extraction from scientific literature with LLMs** — https://arxiv.org/abs/2608.19025

四个递进工作流的结论（**文档**）：

1. 专家写好的 prompt 下，前沿 LLM 抽取表现良好，**但在解释语境与细微差别上有困难**；
2. 给简单指令让 LLM 自己写 prompt，效果**几乎等同于专家写的 prompt**；
3. **自主发现文献很困难，agent 要么漏掉、要么幻觉出参考文献**； ← **这就是"防漏"那半的直接证据**
4. LLM 能按已发表指南造出**接近人类专家评委**的数据集，**但仍需人在环**。

其总结的分工（**文档**，本报告认为这是 Q5 最该抄的一句）：

> "experts specify the evidence standard, models cross-check repeated extractions, and researchers resolve disputed cases"

→ **映射到本项目**：**人定判据（本文件的 R3 表就是判据）→ 模型做重复抽取的交叉校验 → 人只裁分歧案**。这恰好就是 §8 已经写下的"删除段审计员"和"重叠带单裁决"的学术版。

### 6.3 负面：让 LLM 直接吐时间戳会坏

REZE 论文的诊断小节标题：**"Interface failures account for a large share of Direct errors"**（直接生成时间戳的错误里，很大一部分是**接口层失败**——格式错、解析不出、拒绝回答）。

并且 REZE 在 Charades-STA 与 QVHighlights 上**每一次可用对比都优于 Direct timestamp generation**。

**文档**（Moment-GPT，AAAI 2025）：主流 MLLM VMR「过度依赖昂贵的高质量数据集与耗时微调」；且已有零样本工作**忽视了 query 固有的语言偏差，导致定位出错**——他们的修法是**先用 LLaMA-3 改写 query**。

### 6.4 姊妹报告的实测警告（必须并读）

`.scratch/aivideo/20-vlm-game-eval.md` **实测**：

> 零样本 VLM 连「现在是不是在交战中」这个粗粒度二分类都做不好 —— **GameVibe 实验里零样本 ~57%，低于「猜多数类」的 67.2% 平凡基线**；FPS 电竞画面最强模型天花板约 **71%**（GPT-5 @ EgoEsportsQA），人类 80.5%。

**推断（必须写清楚的分寸）**：这与 REZE 的 AUROC 0.84–0.87 **不矛盾**——测的不是一回事：

| | 20 号报告 | REZE |
|---|---|---|
| 测量对象 | 逐帧/逐 1 秒窗的**硬二分类准确率** | clip 级（3s）**logit 排序能力**（AUROC） |
| 判决方式 | 硬判决 | 软分数 + 与全片均值比较的累积证据 |
| 用途 | 直接定边界 | 只做候选/检测 |

**但结论对本项目不利的那一半必须承认**：REZE 的分数质量完全依赖 VLM 对「交战中」的判别力，而这正是 20 号报告实测的弱项（零样本低于平凡基线）。**所以零样本 REZE 直接用在永劫上，大概率不 work。** 这就引出了 §7 的推荐。

---

## 7. 结论：这条线能把「14 路人工裁定合并」自动化吗？

### 7.1 分层回答（哪一段最值得自动化）

| 环节 | 现在耗时 | 能否自动化 | 依据 |
|---|---|---|---|
| **14 路逐帧读图判断「这段有没有战斗」** | **10 小时大头** | ✅ **能，且收益最大** | X-CLIP 微调 >90%（域内同游戏）+ REZE 的确定性聚合 |
| **`engage_start` / `outcome_time` 精修** | 部分含在上面 | ⚠️ **半自动**，单 clip 分数给不出亚 clip 边界 | REZE 附录 C：≤10s 片段 mAP 5.39；需 CAD 式先验 Viterbi 二次精修 |
| **区间合并/拆分的排序扫描** | 小 | ✅ **纯确定性，O(n)** | 时间硬切分⇒相邻性即可；REZE Table 3A 给阈值 6–14 分的证据 |
| **间隙性质判决** | **864 六版返工的根因** | ⚠️ **降级而非取消**：从"逐帧核实"降为"读 s(t) 曲线形状" | REZE 曲线法 + §5.3 |
| **冻结门禁 / 对抗审 / 用户审片** | 固定成本 | ❌ **不该自动化** | AGENTS §8.1：门禁全绿后仍必须看片；`whole_battle_policy` 全库零训练数据 |

### 7.2 推荐落地路线（按投入产出比排序）

**Step 1（最便宜、先做）· 用本项目自己的 109 episode 造边界先验器**
CAD（ICPR 2026，https://github.com/LUNAProject22/CAD）：把 §1.2 实测的 episode 区间 + 117 条洞抽成 (per-class duration, transition confidence, boundary set) 三个先验，挂进 Viterbi 做**推理时**精修，**不重训、不加模型**。
**预期**：直接把 `qa_gate.py` 的边界类告警压下去。**零 GPU 成本。**

**Step 2（核心 ROI）· 微调一个 CLIP 系 combat 分类器**
数据：§1.2 实测的 5076 个 clip（2698 正 / 2378 负），4.23 h，同游戏同 UI。
做法照 **Gameplay Highlights Generation**（https://doi.org/10.48550/arxiv.2505.07721）：微调 X-CLIP（或 SigLIP2），ONNX 量化 + DirectML 落 Windows。
输出：**逐秒/逐 clip 的 `s(t)` 曲线**——这正是 REZE 后续一切聚合的输入。

**Step 3（把聚合补齐）· 照抄 REZE 的确定性读出**
```
clip 分数 → 逐秒曲线 s(t) → 均值中心化 s'(t)=s(t)−mean
  ├─ 单区间：Kadane 最大子段           （Table 3A：53.49 mIoU）
  └─ 多区间：固定 σ=3s 平滑 + Otsu θ  （Table 3B：42.46 mAP）
```
**三条必须照抄的细节**：
- 平滑带宽**固定秒数**，绝不用 ⌊D⌋/15（实测那一档只有 20.76 mAP）；
- 阈值用 **Otsu 从本条曲线自身分布求**，不用全局固定阈值；
- 保留**连续分数**（logits softmax），**不要**二值化。

**Step 4（保留人的那一半，但让复核有据）**
- 复核触发器不用"时间"，用**分歧度**（§6.1：模型分歧本身是最强特征）：仅在"多路不一致"且"曲线形状跨过某阈值"的区间派人。
- 间隙判决读曲线（§5.3），不读帧。
- 跨模型多样性：**至少 2–3 个不同 prompt 模板/温度/家族的扫描员**，否则 §6.1 的聚合收益前提不成立。

### 7.3 ⭐ 一句话可靠性判断

> **候选生成能到"可交付"（域内微调后 clip 级 ~90%，REZE 式聚合免训练可复现）；边界定不了（误差下限 ±clip 长度，短战斗 mAP 5.39）；合并裁定不该替掉——它只能被"降级成看一条曲线"，不能删。所以：10 小时大头能砍掉，但 §8.1 的审片环节一个都不能少。**

**必须同时记下的两个反向约束**：
1. **零样本 REZE 直接用在永劫上大概率不 work**（§6.4：本项目实测零样本 VLM 判"是否交战中"低于平凡基线）。Step 2 的微调**不可省**。
2. **本机跑不动论文配置（实测）**：GPU 是 **RTX 4060 Ti，8188 MiB 总显存**，采样时**仅剩 304 MiB 空闲**；venv 只有 `numpy` + `sklearn`，**无 torch / transformers / vllm**；`huggingface.co` 从本机**连接超时（WinError 10060）**。REZE 参考配置 Qwen2.5-VL-7B 光权重就 **16.6 GB** → 不可行。
   → **Step 2 选 CLIP 系小模型不仅是精度选择，更是硬件选择**（CLIP 量级 + ONNX + DirectML 是唯一能在 8 GB 上稳跑的路径）。这也与 AGENTS §2「绝不依赖临时环境、建在系统解释器上的 venv」一致——**任何新依赖必须落在 `C:\Project\永劫无间\.video-tools\venv`，权重走国内镜像离线落盘**。

---

## 8. 证据强度汇总

| 结论 | 强度 |
|---|---|
| 本项目全库 4.23 h / 109 episode / 117 洞 / 53% 战斗占比 / 5076 个 3s clip | **实测**（本项目 `timeline\combat_episodes*.json` 脚本统计） |
| 本机 RTX 4060 Ti 8 GB、venv 无 torch/transformers、HF 不可达 | **实测**（`nvidia-smi`、venv 探测、HTTP 超时） |
| REZE 算法细节、消融数字、"detected not delimited"、成本 | **文档**（arXiv:2608.04480 正文/附录） |
| X-CLIP 微调 FPS 事件 >90%、transfer、ONNX+DirectML | **文档**（arXiv:2505.07721） |
| DCASE 2026 AMR 前三名 R1@0.7 48.59%、基线 13.56% | **文档**（arXiv:2609.12484） |
| GMR「完整集合或空集」定义、Soccer-GMR | **文档**（arXiv:2605.02623 + GitHub） |
| OVTAS 是 training-free 开放词表 TAS、14 VLM 研究 | **文档**（arXiv:2602.21406, ICRA 2026） |
| CAD 推理时 Viterbi 先验精修 | **文档**（arXiv:2605.10149, ICPR 2026） |
| LLM crowd 聚合收益来自「输出的线性组合」+「分歧信号」；污染使差距 35.8%→8.9% | **文档**（arXiv:2607.18269 / 10.1145/3839337） |
| 「专家定标准 → 模型交叉校验 → 人裁分歧」分工；自主发现会漏会幻觉 | **文档**（arXiv:2608.19025） |
| FlashMMR 需 QVHighlights 训练，不能零样本用于永劫 | **实测**（读其 README 推理/特征/ckpt 要求）+ **推断**（外推到本域） |
| 聚类算法应替换本项目人工合并 | **推断**（由上述文档外推；**未找到**任何直接做"多 agent 区间报告合并"的论文） |
| REZE 式聚合在本素材时长（1152s）下不掉队 | **推断**（依据其 σ 固定设计 + Table 3B；**未实测**） |

## 9. 未找到 / 搜过确认没有

1. **任何在永劫 / 第一人称射击 / 武侠 ARPG 上训练过的 VMR 或 TAS 开源模型。**
2. **任何直接把「N 个 agent 的区间报告」自动合并成时间线的论文**——这是本项目的真问题，学术界没有对位工作，只能拼装零件（§5.2）。
3. **REZE 的公开实现**（GitHub 搜 "REZE temporal grounding" 无结果；论文 COMMENTS 字段为空）。算法本身完全可手写（≈50 行：logits softmax → 逐秒曲线 → 均值平移 → Kadane/Otsu）。
4. **STITCH 的公开实现**（论文 COMMENTS 为空）。
5. **`Temporal Segmentation Distance` / `Boundary Divergence Index` 在 arXiv 上的论文**——用 arXiv 站内搜索确认无结果（这两个是期刊/会议文献，不在 arXiv）。

## 10. 与本项目既有文档的冲突点（需人工裁决，本文不自行改动）

| # | 冲突 | 依据 | 建议 |
|---|---|---|---|
| 1 | 本项目多处把"删/不删"落到**阈值秒数**上（`rejoin_window_seconds` 12、`internal_gap_seconds` 8、`lead_in_seconds` 5） | **文档** REZE Table 3A：阈值类 extractor 比"相对全片均值累积证据"低 **6–14 个点** | 保留这些计时参数作**起始值**（文档已如此规定），但让 `s(t)` 曲线成为一等公民 |
| 2 | 本项目对 `excluded_inside`/洞有成熟门禁，但**没有"把本项目标注反哺成模型先验"的回路** | CAD 提供推理时先验精修，无需重训 | Step 1 就是补这条回路 |
| 3 | 合并台账 `PARTIAL/BRIDGED/FROZEN` 三态是**版本台账**，不是**置信度台账** | LLM crowd 论文：最优聚合器等价于模型分歧信号 | **推断**：可以再加一列 `disagreement`，把"该复核"从时间驱动改成分歧驱动 |
| 4 | 扫描报告的 `confidence` 字段（§1.1 表格里有，如 `combat_001` = 0.9）**如何算出来的，全库未查到定义** | — | **未找到**。若它是模型自评而非可算量，它不能直接进加权聚合器；这需要先定死 |