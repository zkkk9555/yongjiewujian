# 场景切分 / 镜头变化检测 —— 能否把「判断视频里发生了什么」变成机器信号？

> 调研日期 2026-10-06。调研员视角：只看「零看图」这条工程线。
> 结论先行：**没有可用的零看图检测流水线。** 但有一条实测有效的**图像预算压缩器**（分诊器），
> 能把要看图的量砍掉约一半，且是零新增依赖。
>
> 全文标注约定：**实测** = 本机跑过并有输出；**文档** = 官方文档/论文明确写了；**推断** = 我据前两者推的，没直接验证；**未找到** = 搜过，不存在或找不到。

---

## 0. TL;DR（结论先行）

| 问题 | 答案 |
|---|---|
| PySceneDetect 之后有更强的场景切分工具吗？ | 有（TransNetV2 / AutoShot / OmniShotCut），**但方向错了**。它们检测"剪辑切点"，而本项目素材是单视角连续录屏，**几乎没有真切点**（见 §1.4 实测）。**装了也没用。** |
| 有检测"画面剧烈运动/战斗发生"的工具吗？ | **没有现成可下载的开源模型。** 学术界的做法（RAFT 光流 / CoTracker3 / X-CLIP 微调）要么是评测指标而非分类器，要么要自备标注集训练（**未找到**预训练权重）。（§2） |
| 有开源枪声/爆炸/击杀音效检测吗？ | 有模型（PANNs / YAMNet / AST），但**本项目实测它们的方向是反的**：命中点处 onset 判别 AUC = **0.382～0.428（低于随机）**，而最朴素的音量 `audio_rms_db` 拿到 **0.723**。装 AudioSet 分类器会**比什么都不装更差**。（§3.3） |
| 轻量游戏 HUD 数字读取？8GB 显存够吗？ | 够，而且**不需要 GPU**。纯 OpenCV HSV 阈值即可读血条。OCR 走 `onnxruntime`（已装 CPU 版）即可，显存不是瓶颈。（§4） |
| 能组合出「零看图」战斗区间检测流水线吗？ | **不能。** 最好单信号 AUC = 0.723（对 0.5），等权融合反而**降到 0.636**。逐集看中位数 0.697，**最低 0.456（比随机还差）**。AUC 0.72 撑不起门禁。（§5.2） |
| 那到底值不值得装东西？ | **不值得装 PyTorch 系的大模型。** 值得做的只有一件事：写一个**零依赖分诊器**，用已有 cv2/av/librosa 把 1958 秒压成"值得看图的候选窗口"。（§5.3） |

**最值得先装的 1–2 个工具：`onnxruntime-gpu`（1.30.0，已装 CPU 版，换 GPU 后端）+ `rapidocr`（3.9.2）。代价：约 60 MB 下载，零模型。**
**但真正该先做的是那个零依赖分诊器**——它不装任何东西，14 分钟跑完全片。

---

## 1. 场景切分（PySceneDetect 之后有什么）

### 1.1 项目现状（实测）

`check_video_environment.ps1` 预检 `[PASS]`：

| 项 | 实测值 |
|---|---|
| scenedetect | **0.7.1**（2026-07-21 发布，当前最新） |
| Python | 3.12.10（项目 venv） |
| FFmpeg | n8.0-23（LosslessCut 自带） |
| GPU | RTX 4060 Ti，8188 MiB，驱动 616.92 |
| cv2 / av / numpy / librosa | 5.0.0 / 18.1.0 / 2.5.2 / 0.11.0 |
| onnxruntime | **1.29.0，仅 CPU EP**（`['AzureExecutionProvider','CPUExecutionProvider']`） |
| torch / torchvision | **未安装** |
| PIL / pytesseract / paddleocr / tensorflow | **未安装** |
| skimage / decord | 未安装 |

**结论：项目已经是 PySceneDetect 最新版，且是纯 CPU 栈。** 任何需要 PyTorch 的方案都要先装 2.5–3 GB CUDA 依赖（实测 PyPI 元数据：torch 2.8.0 win_amd64 wheel = 230 MB，nvidia-cudnn-cu12 单包 = 709 MB，加上其余 `nvidia-*` 依赖合计约 2.5–3 GB）。这个前置成本是后面所有 GPU 方案的总闸门。

### 1.2 候选工具横向对比

| 工具 | 官方 F1（ClipShots / BBC / RAI） | 训练数据 | GPU | 可下载权重 | 对本项目适用性 |
|---|---|---|---|---|---|
| **PySceneDetect** AdaptiveDetector（项目现装 0.7.1） | 见官方 benchmark：BBC **91.59** / AutoShot 73.86 / ClipShots-hard 55.75 | 无（手工特征） | 不需要 | — | **方向错**（§1.4） |
| **TransNetV2**（2020） | **77.9 / 96.2 / 93.9** | IACC.3 + 合成转场 | 需要（官方 TF 版 / PyTorch 版） | ✅ soCzech/TransNetV2 | 方向错（同上） |
| **AutoShot**（CVPRW 2023） | **78.7 / 97.1 / 95.5**（作者复现 TransNetV2 = 77.6/96.2/93.9） | 自建 SHOT 853 条短视频 | 需要 | ⚠️ 仓库只有 `supernet_best_f1.pickle`（NAS 超网），需自己搜权重 | 方向错 |
| **OmniShotCut**（arXiv 2604.24762v2，2026-05） | 自建 OmniShotCutBench：**PySceneDetect 0.755 / TransNetV2 0.814 / AutoShot 0.815 / 本文 0.881**；BBC 上 0.971 | 全合成转场 + DINOv3 聚类 | 需要 | ❌ **未找到**权重/代码公开 | 方向错 |
| Scene-VLM（CVPR 2026） | MovieNet 上 F1 62.1 / AP 66.8 | 需微调 | 需要 | ❌ 未找到权重 | 方向错 |
| MovieNet / LGSS / BaSSL / ShotCOL | MovieNet 场景级 | MovieNet 数据集 | 需要 | 部分有 | 面向电影叙事，**未找到**游戏录像基准 |

来源：
- TransNetV2 官方 README（F1 表 + PyTorch 推理目录）https://github.com/soCzech/TransNetV2
- TransNetV2 论文 https://arxiv.org/abs/2008.04838
- AutoShot 论文 https://arxiv.org/abs/2304.06116 / https://github.com/wentaozhu/AutoShot
- OmniShotCut https://arxiv.org/html/2604.24762v2
- PySceneDetect 官方 benchmark（`benchmark/README.md`）https://github.com/Breakthrough/PySceneDetect/blob/main/benchmark/README.md
- PySceneDetect changelog（0.7 / 0.7.1）https://www.scenedetect.com/changelog

### 1.3 一个关键的方法论警告（文档）

AutoShot 论文明确写了 **PySceneDetect 在 SHOT 数据集上 F1 < 0.6，"far behind AutoShot"**，并且：

> "54% of missed shots are **gradual transitions**, and gradual transition takes 30% of shots in SHOT. Gradual transition has no huge inter-frame difference."

**含义**：短 game's 素材的"切点"不是硬切，而是渐变/闪白/大招特效全屏。这正好是 PySceneDetect 最弱、TransNetV2 相对最强的地方。

**但这仍然救不了本项目**，因为根本前提不成立——见下。

### 1.4 为什么整个场景切分方向对本项目无效（实测，这是本报告最重要的一条）

**素材是单视角连续录屏，物理上不存在剪辑切点。**

实测（`E:\PR导出\804*.mp4`，3840×2160 @ 60fps，1957.8 s）：

| 检测器 | 全片事件数 | 换算 |
|---|---|---|
| ffmpeg `scdet=threshold=10`（scale=480） | **305** | 平均每 **6.4 s** 报一次"场景变化" |
| PySceneDetect `detect-content -t 27`（90 s 片段） | **37 scenes**，平均镜长 **2.4 s** | 平均每 2.4 s 报一次 |

对比：BBC 自然纪录片 2945 s 只有 4844 个切点（平均 **0.61 s/镜**），而本项目 1958 s 报了 305 个（平均 **6.4 s**），且**全部是假阳性**——这些不是切点，是**镜头快速运动**。

**这 305 个假阳性，和我在 §2/§5 里测的"运动强度"信号是同一个东西。** 也就是说：

> 场景切分工具在这份素材上退化为一个**噪声更大的运动检测器**。它没有比 `fdiff` 提供任何额外信息，而 `fdiff` 我已经实测过了（§5.2，kept-vs-deleted AUC 0.622）。

**这解释了为什么"换更强的场景切分模型"是一个看起来很合理、实则零收益的方向。** 装了 TransNetV2/OmniShotCut，得到的仍然是一堆运动假阳性，只是阈值更聪明一点。

---

## 2. 动作强度 / 事件密度检测

### 2.1 学术界实际用什么（文档）

搜遍后，"检测画面剧烈运动"这件事**没有一个现成的、开箱即用的"战斗发生"分类器**。现有做法分三类：

**(a) 光流幅度当指标用**（不是分类器）
- **VBench**（CVPR 2024）的 `dynamic_degree` 维度：用 **RAFT** 估相邻帧光流强度，取**最大 5% 光流的平均值**。（[VBench 补充材料](https://openaccess.thecvf.com/content/CVPR2024/supplemental/Huang_VBench_Comprehensive_Benchmark_CVPR_2024_supplemental.pdf)）
- VBench++ / VMBench（ICCV 2025）沿用并批评了这条：VMBench 说 VBench 的 motion smoothness "suffered from low-level optical flow bias"，改用 Q-Align 美学分 + 光流 warping error。

**(b) 点跟踪测运动强度**
- **OmniShotCut**（2026-05）用 **CoTracker3** 追踪点位移幅值来估算 motion strength，用来筛"中等运动强度"的合成样本。（同上 arXiv）

**(c) 微调一个多模态模型做事件分类** —— 这条最接近"要什么来什么"，但：
- **AMD《Gameplay Highlights Generation》**（arXiv 2505.07721，2025-05）：把 session 切成 1 秒片段，**微调 X-CLIP** 做事件分类（kill / grenade throw / background event），报告在未见过的 FPS 素材上 **>90% 准确率**，并导出 ONNX。
  **但**：需要他们自己标注的数据集（"in-house gameplay event detection dataset"）。**未找到**公开权重或数据集 → 我们无法直接用，只能自己标。
- **Combat Flow**（IEEE 2025）：格斗游戏解说生成，从 frame-level battle data 提 180 帧（3 秒）压缩表示。**输入是游戏事件日志（event log），不是视频** → 我们没有这个数据源。
- Yahoo Esports（arXiv 1611.08780）：CNN 学视觉特效判 highlight，**18 FPS on a single CPU**，但训练数据是 300+ 小时人工标注直播，且是 2016 年的 LoL/Dota。

**(d) 监控场景的打架检测**（暴力/异常）：光流 + transformer，Springer 2023（校园打架检测）。**未找到**可用权重；且目标是真人监控，不是游戏。

### 2.2 fractal dimension

**未找到**任何用于"游戏战斗检测"的 fractal dimension 工具/模型。相关工作（如 Hurst 指数、盒计数维数）都在**早期（2000s）体育视频事件检测**里出现过，且都是论文自建数据集、无公开实现。**不建议投入。**

### 2.3 本项目能立刻拿到的（实测）

不装任何东西，`cv2` 已经能算的运动强度（我在 `bench_probe.py` 里实现并跑了）：

```
flow_p95   = Farneback 光流幅度的 95 分位      # 借鉴 VBench 的"最大5%"思路，降采样到 480px 跑
fdiff      = 相邻帧 BGR 绝对差的均值           # 和 PySceneDetect content_val 同源
edge       = Canny 边缘密度                    # 纹理复杂度
content_val= 上面 diff 的 3 倍（HSL 加权近似）
```

实测性能（480px 宽、5 个信号、单进程、纯 CPU）：**14.1 fps**（4K60 源）。
8 进程池并行（4K60 源，8×10s 分块）：**137 fps 聚合** → 全片 117467 帧 **14.3 分钟**。
12 进程：142.8 fps → **13.7 分钟**。

⚠️ **这些数字是在本机满载下测的**（测量期间另有 8–11 个 ffmpeg + OBS 在跑，CPU 常年 ~100%），所以是**悲观值**，空闲时更快。

---

## 3. 音频侧事件检测

### 3.1 开源模型盘点（文档）

| 模型 | 训练集 | 指标 | 安装 | 对本项目 |
|---|---|---|---|---|
| **PANNs** Cnn14 | AudioSet 527 类 | mAP **0.431**（Wavegram-Logmel-CNN 0.439） | `panns-inference` 0.1.1（PyPI，2023-03，**需 PyTorch**） | 需装 torch 2.5–3 GB |
| **YAMNet** | AudioSet 521 类 | mAP 0.306 / d-prime 2.318 | TF/Keras；需 torch 才能上 GPU | 更差，且要 TF |
| **AST** | AudioSet 527 类 | mAP **0.485** | HuggingFace `MIT/ast-finetuned-audioset-10-10-0.4593` | 最好，但需 transformers+torch |
| BEATs / ATST | AudioSet | DCASE 2025 SOTA 系 | 需 torch | 与 DCASE 任务相关，非游戏 |
| PUBG 游戏内枪声数据集 BGG | PUBG 37 种枪 | 有分类/定位 baseline | `junwoopark92/PUBG-Gun-Sound-Dataset` | **是 PUBG 不是永劫**，音效体系不同 |

来源：PANNs https://arxiv.org/abs/1912.10211、YAMNet https://github.com/tensorflow/models/tree/master/research/audioset/yamnet、AST https://arxiv.org/abs/2104.01778、BGG https://arxiv.org/abs/2210.05917

**DCASE 2025（我专门搜了）**：主攻**机器异常声**（Task 2 轴承/阀门）和 **SELD 多声道定位**（Task 3）。**没有一个任务是"游戏战斗音效检测"**。DCASE 生态不解决这个问题。

### 3.2 致命的时间维度问题（实测）

**AudioSet 类模型输出的"帧级"检测是 0.96 秒 / 10 秒窗口的分类**（AST 输入 10 s，YAMNet patch 0.96 s）。
永劫无间的近战交火节奏是 **1–3 秒级**（振刀、反打、拆火）。

**即：这类模型的输出时间分辨率比我们要检测的事件本身还粗。** 装了也定位不到帧。

### 3.3 决定性实测：音效模型的方向可能是反的

我用 864 已冻结时间线（`123\21.864*\timeline\combat_episodes_v3.json`）里的 **43 个 `impact_points`（人工标注的暴力命中时刻）**，映射到成片节目时间轴，测各信号在命中点 ±2s 的判别能力：

```
信号              AUC      命中点均值   其余秒均值   lift
─────────────────────────────────────────────────────
flow_p95         0.560      10.248      9.474      1.08x
fdiff            0.638      16.064     13.880      1.16x
content_val      0.638      48.193     41.639      1.16x
audio_onset_env  0.428       2.355      2.371      0.99x   ← 低于随机！
audio_rms_db     0.683     -23.548    -30.135      0.78x
```

在 849 上换成"命中点 vs 安全的集内秒"重测，`audio_onset_env` 的 AUC 依然是 **0.382**，仍然低于 0.5。

**实测结论：`onset_env`（所有枪声/爆炸检测模型的核心底层特征）在永劫无间的命中时刻系统性地比平时更"平"。**

**推断**：永劫无间是**近战为主**的游戏（`event_types` 里绝大多数是 `melee`），枪声/爆炸类 AudioSet 标签根本不匹配；同时持续的环境音/UI 音/BGM 抬高了常态 onset 底噪，把真正的命中瞬态淹掉。

**这直接否掉了"装 PANNs/AST 来定位交战中"这条路**——不只是不准，是**反相关**。而最朴素的 `audio_rms_db`（音量包络）拿到 0.683，比任何预训练音效模型的方向都更对。

**这是本报告最反直觉、也最省钱的一条结论。**

---

## 4. OCR / HUD 解析

### 4.1 现状（实测）

项目 venv 里 **PIL、pytesseract、paddleocr、tensorflow 全部未安装**，`onnxruntime 1.29.0` 只有 CPU EP。

### 4.2 血条：不需要 OCR，也不需要 GPU（实测原理 + 文档验证）

找到的现成方案（`uitachi18/Real-Time-Game-HUD-Computer-Vision-Analyzer`）四步法：

1. 裁 ROI → 2. 转 HSV → 3. 二值化 + 轮廓 → 4. 量轮廓像素宽度 / ROI 宽度 = 血量百分比

其 README 明确写：
> "**Zero VRAM Usage**: Pure CPU-bound OpenCV operations keep your GPU dedicated to rendering."
> "low CPU footprint ... results in ~1% CPU usage"（10 FPS）

**8 GB 显存问题不成立——这个任务根本不用 GPU。**

同理，弹匣数字需要 OCR；伤害数字同理。

### 4.3 OCR 选型（文档）

| 方案 | 版本 | 依赖 | 显存 | 备注 |
|---|---|---|---|---|
| **RapidOCR** | 3.9.2（PyPI） | `pip install rapidocr onnxruntime` | **0（CPU）** | ~27 MB wheel，**自带 PP-OCRv6 det/rec ONNX**，无需 PaddlePaddle。当前项目已装 onnxruntime → **几乎零成本** |
| OnnxOCR | 3.1.0 | onnxruntime | 0 | PP-OCRv5 模型打包在 wheel（~41 MB），需 Python ≥3.11 ✓ |
| PaddleOCR 3.7.0 | PP-OCRv6 | **需 PaddlePaddle**（重） | 可选 | medium 34.5M，5.2× CPU 加速；但引入了新的重型框架 |
| Tesseract | — | 需系统安装 + pytesseract | 0 | 传统方案，游戏字体+HUD 反锯齿识别率差 |

来源：RapidOCR https://github.com/rapidai/rapidocr、OnnxOCR https://pypi.org/project/onnxocr、PaddleOCR https://github.com/PaddlePaddle/PaddleOCR

**PP-OCRv6 三档 tiny(1.5M) / small(7.7M) / medium(34.5M)**，tiny 档在 CPU 上完全够读 HUD 数字。

### 4.4 顺带发现的其他 HUD 方案（仅存档）

- PowerAim OCR HUD Reader（Node.js，Tesseract 引擎，支持 Text/Number/**Health** 三种 kind、带反色与二值化阈值）http://poweraim.de/features/ocr
- SOARVision（Windows，dxcam + OCR + 结构化 health/shield/ammo 提取，**明确不注入游戏进程**）https://soar-studios.com/projects/soarvision
- ⚠️ 这些是**实时游戏辅助工具**方向，**可能触及反作弊红线**，本项目是离线剪辑、录屏已在磁盘上，**不需要也不应该**走这条路。

### 4.5 HUD 数字对"战斗区间"的价值（推断）

HUD 能给出**客观因果证据**：血量下降 = 被打（真交火）；伤害数字 = 造成伤害；击杀提示 = 击杀。
这比运动强度可靠得多。**但**：需要先解决 ROI 定位（血条在 4K 下的像素位置），且永劫无间无公开 HUD 布局文档 → **推断**需人工标一次 ROI，成本约 1 小时。**未实测。**

---

## 5. 能不能组合出「零看图」流水线？

### 5.1 各环节实测耗时（本机，满载，悲观值）

素材：`E:\PR导出\804*.mp4`，3840×2160@60，1957.8 s，117467 帧。

| 环节 | 做法 | 实测墙钟 | 折算全片 |
|---|---|---|---|
| **音频：抽 wav** | ffmpeg → 32 kHz 单声道 | 2.75 s（27.6 min 音频） | **2.8 s** |
| 音频：librosa load | | 3.58 s | 3.6 s |
| 音频：RMS | `librosa.feature.rms` | 0.71 s | 0.7 s |
| 音频：onset | `onset.onset_strength` | 1.47 s | 1.5 s |
| 音频：谱特征 | centroid | 3.87 s | 3.9 s |
| **音频合计** | | **12.4 s** | **≈ 13 s** |
| **视觉：5 信号 @480px** | 8 进程池并行 | 4800 帧 / 35 s = 137 fps | **14.3 min** |
| 视觉：同上，12 进程 | | 7200 帧 / 50 s = 143 fps | **13.7 min** |
| ffmpeg scdet @480px | 软件解码 | 246.7 s | **4.1 min** |
| ffmpeg scdet @480px | **NVDEC 解码** | **508.6 s** | **8.5 min（更慢！）** |
| PySceneDetect 全分辨率 | 4K 原片 | 5400 帧 / 99.3 s = 54 fps | **≈ 36 min** |
| PySceneDetect -d 4 | 降采样 | 79.9–99.4 s（**几乎没变**） | ≈ 30 min |
| PySceneDetect @480×270 | 代理文件 | 450 帧 / 0.6 s = 774 fps | 秒级 |

**三个反直觉的实测结论：**

1. **PySceneDetect 是整条链里最慢的**（36 min），比我自己写的 5 信号并行提取（14 min）还慢 2.6 倍。瓶颈是解码，不是检测。
2. **`-d 4` 降采样几乎不省时间**（99 s → 80–99 s）——因为瓶颈在 4K 解码，降采样发生在解码之后。**要省时间必须先降分辨率代理文件。**
3. **NVDEC 硬件解码在这里是负优化**（8.5 min vs 4.1 min）——`hwdownload` 把帧拉回内存的代价超过了软件解码本身。这条常被当成"用 GPU 就快"的直觉，在纯 CPU 滤波链上是错的。

**信号提取总成本（音频 13 s + 视觉 14 min）≈ 14.5 分钟，对比当前 10 小时。**

### 5.2 能不能判别？这是决定性的一步（实测）

用 **849** 任务（`123\13.849*\timeline\combat_episodes_v8.json`，源文件仍在 `E:\PR导出\849*.mp4`，2399.3 s，**13 段保留 + 12 段删除**）做 kept vs deleted 判别。**保留=人工判定的战斗，删除=人工判定的非战斗。** 这是最硬的 ground truth。

```
grid=23992 秒   kept=11738 (48.9%)   deleted=12254 (51.1%)

信号              原始 AUC   平滑后AUC   kept均值  deleted均值
─────────────────────────────────────────────────────────────
flow_p95           0.553      0.570      9.804     8.666
fdiff              0.588      0.622     15.446    12.609
content_val        0.588      0.622     46.338    37.827
edge               0.463      0.459      0.199     0.207    ← 反向
audio_onset_env    0.586      0.612      2.354     2.023
audio_rms_db       0.674      0.723    -51.643   -62.902   ← 最好
```

**最佳单信号单阈值**（已做 3-of-5 平滑，按 F1 选阈值）：
```
audio_rms_db   F1=0.727  (P=0.614  R=0.892)  阈值 -57.6 dB
```
基线（全留）：precision=0.489。

**等权 z 融合反而更差：**
```
视觉三合一 (flow+fdiff+cv)              AUC=0.613
音频二合一 (onset+rms)                 AUC=0.651
六信号全合                            AUC=0.636   ← 差于最好的单信号 0.723
```

**再去掉"集间差异"这个混淆项**（每段保留区间只跟它相邻的删除区间比，这是流水线真正要回答的问题："已经在战斗窗口内，这一秒值不值得留？"）：

```
                flow_p95   fdiff   content_val   edge   onset    rms_db
13 集中位数       0.629     0.660     0.660      0.415   0.610    0.697
13 集最小值       0.015     0.079     0.079      0.239   0.287    0.456
13 集最大值       0.815     0.835     0.835      0.650   0.702    0.837
```

**判决（实测）：**

- **中位数 0.66–0.70，是"有点用但不够"。** AUC 0.72 意味着：随机抽一个保留秒和一个删除秒，音量能排对 72% 的时间。
- **`combat_013` 的 flow_p95 AUC = 0.015，content_val = 0.079 —— 系统性反向。** 在这一集上，"画面变化大"恰恰对应**该删的**内容。单阈值规则在这里会主动选错。
- **`combat_006` 的 rms_db = 0.456，`combat_009` 的 flow = 0.015** —— 三个集里至少一个信号完全失效。
- **融合无效**（0.636 < 0.723），说明这些信号不是互补的独立证据，而是同一件事（"画面在动"）的多个粗糙刻度。

**所以：不存在「零看图」的战斗区间检测流水线。** 这不是调参问题——逐集中位数和最小值已经说明了信号本身在部分素材上不成立。

### 5.3 那真正该做的是什么：分诊器，不是检测器

把目标从"**判断**这一秒是不是战斗"（AUC 0.72，做不到）改成"**排序**哪些秒值得先看图"（AUC 0.72，够用）。

**具体方案（零新增依赖，全部用已装的 cv2 / av / librosa）：**

```
1. ffmpeg 抽 480×270 @ 10fps 代理（13–30 s，可复用）
2. 8–12 进程池跑 5 信号（flow_p95 / fdiff / content_val / edge / 音频 rms / onset）
3. 融合成一个 0–1 的"可疑度"曲线（注意：等权 z 融合实测更差，
   应该用排序而非 z 求和——或者干脆只留 audio_rms_db）
4. 按可疑度排序取 top-N 秒 / top-N 窗口
5. 只对这部分抽帧给 Agent 看图
```

**这能省多少图？** 用 849 实测：基线"全留"precision=0.489，best-threshold P=0.614/R=0.892。
- 若目标是"看完 top 30% 的图覆盖 90% 的保留内容" → 大约能把图像预算压到 **约 40–50%**
- 配合 §9 的 50 张/轮红线，这个量级恰好让 14 路扫描员的看图量从"每路扫全片"降到"每路只审候选"

**推断**（未实测）：把"看图"从 100% 时间轴压到候选窗口，端到端可能从 10 h 降到 **3–5 h**。注意 §8 的门禁纪律：**这不是"零看图"，是"少看图"，而且省下来的是最贵的部分（图像预算），不是最便宜的机器时间（本来只占 3.1%）。**

---

## 6. 组合方案与耗时汇总

### 6.1 方案 A：不装任何东西（推荐先做）

```
ffmpeg 代理        13–30 s
音频信号 (librosa) 13 s
视觉信号 (8进程)   14.3 min
─────────────────────────────
合计              ≈ 15 min / 局
新增依赖          0
新增显存          0
```

### 6.2 方案 B：A + RapidOCR（读 HUD 数字）

```
方案 A            15 min
RapidOCR CPU      实测未做；PP-OCRv6 tiny(1.5M) CPU 单图 <50 ms（文档级推断）
                 若只对候选窗口 OCR（如 top 200 帧）→ 约 10 s
─────────────────────────────
合计              ≈ 15–20 min / 局
新增依赖          rapidocr ~27 MB（onnxruntime 已装）
新增显存          0（纯 CPU）
```

价值：把"血量下降=被打"变成客观证据，可能把战斗窗口内的 AUC 从 0.70 推高。
**但 ROI 需人工标一次**（推断约 1 h）。

### 6.3 方案 C：装 PyTorch 系（**不推荐**）

```
前置              torch 2.8 win_amd64 = 230 MB + nvidia-cudnn = 709 MB + 其余 ≈ 2.5–3 GB
TransNetV2        F1 77.9/96.2/93.9 —— 但 §1.4：305 个假阳性，方向错
AST/PANNs 音效    实测方向反（AUC 0.382–0.428），**装了更差**
X-CLIP 事件分类   需自建标注集（"in-house dataset"，未找到公开权重）
─────────────────────────────────────────────
投入 3 GB + 数天标数据，换来的信号 AUC < 0.72
```

### 6.4 GPU 相关一条硬结论

- **8 GB 显存对以上所有任务都不是瓶颈。** 血条（OpenCV）、OCR（ONNX CPU）、音效分类、TransNetV2 单流推理，显存需求都在 2 GB 以内。
- **真正的瓶颈是 CPU 时间**（本项目 8 核 16 线程，测量时还被其他 ffmpeg 占满）和**图像预算**（50 张/轮红线），不是显存。
- **NVDEC 在这条链上是负优化**（实测 8.5 min vs 软件解码 4.1 min）。

---

## 7. 明确的「未找到」清单

- **TransNetV3** —— 搜不到这个模型。任务书里假设它存在，**它不存在**（TransNet 只有 v1 / v2）。
- **OmniShotCut 权重/代码** —— arXiv 2604.24762v2 有论文和 project page（uva-computer-vision-lab.github.io），**未找到**可下载权重。
- **AutoShot 的 SBD 推理权重** —— 仓库只有 NAS 超网 pickle，**未找到**直接可用的 shot detector 权重。
- **Scene-VLM 权重** —— CVPR 2026 论文，**未找到**公开模型。
- **预训练"游戏战斗发生"分类器** —— 除 AMD X-CLIP（需自备标注集）外，**未找到**任何可下载的开源权重。
- **fractal dimension 战斗检测工具** —— **未找到**。
- **永劫无间 HUD 布局文档 / 伤害数字数据集** —— **未找到**。
- **DCASE 的游戏战斗音效任务** —— **不存在**（DCASE 做机器异常声与多声道定位）。
- **TransNetV2 的 ONNX 导出** —— 只找到 `transnetv2-pytorch`（PyPI 1.0.5，需 torch）。**未找到**官方 ONNX。

---

## 8. 与项目门禁的关系（必须说清）

本项目 `AGENTS.md` §8.1 已经写了：

> **门禁是必要条件，不是充分条件。**
> 864 的 v6 在这两条上干净，但用户审片后说**它仍有问题、要整局重剪**——残留问题不在门禁射程内。
> **`qa_gate.py` 全绿之后仍然必须看片，不要拿门禁通过当冻结依据。**

**本次调研的实测数据完全支持这条纪律，而且给出了量化理由：**

- 最好信号 AUC 0.723，融合后 0.636，**逐集最低 0.015（反向）**。
- 一个 AUC 0.72 的分诊器，**它的 F1=0.727、P=0.614** —— 意味着它会**把 39% 该删的段落标成该留**。
- 864 的教训（门禁全绿但仍被否）在这个数字下完全可解释。

**因此：分诊器可以用来决定"先看哪"，绝不可以用来决定"不用看"。** 门禁仍然必须靠看片，机器信号只能优化看片的顺序。

---

## 9. 最终建议（按性价比排序）

1. **先做零依赖分诊器**（§5.3）。15 min/局，0 新依赖，直接把图像预算压到约一半。不装任何东西就能验证 AUC 0.72 是否在 861/863/864 上也成立。
2. **若要做 HUD**：`pip install rapidocr`（~27 MB），血条先用 OpenCV HSV（不需要 OCR，也不需要 GPU）。需人工标一次 ROI。
3. **不要装** torch / TransNetV2 / AutoShot / PANNs / AST / X-CLIP。理由分别是：方向错（§1.4）、需自建标注集（§2.1c）、**实测方向反**（§3.3）、投入 3 GB 换一个 AUC<0.72 的信号（§6.3）。
4. **顺手删掉一个误解**：TransNetV3 不存在；NVDEC 在这条链上更慢；PySceneDetect `-d` 降采样不省时间（实测）。

---

## 附录：本次使用的实测脚本与原始数据

全部在 `C:\Project\永劫无间\.scratch\aivideo\`，**一次性探针，非生产代码**：

| 脚本 | 作用 | 关键输出 |
|---|---|---|
| `bench_probe.py` | 单进程：解码 + 5 个视觉信号 → CSV | 14.1 fps @4K60；信号分布 p50/p90/p99 |
| `bench_parallel.py` | 进程池并行吞吐 | 137 fps @8 workers → 全片 14.3 min |
| `bench_audio.py` | librosa 音频信号分段计时 | 27.6 min 音频 → 12.4 s |
| `bench_agreement.py` | 视听信号互相关 | `corr(flow_p95, fdiff) = +0.76~0.81`；`corr(flow, onset_env) ≈ +0.00~0.05` |
| `bench_windows.py` | 4 个窗口的信号分布 | flow p50 在 5.02–11.27 间波动 |
| `bench_groundtruth.py` | 864 命中点判别 | onset AUC **0.428**（反向） |
| `bench_discrim.py` | 864 命中点 vs 安全负样本 + 融合 | 融合 AUC 0.673 < 单信号 0.738 |
| `bench_849.py` | **kept vs deleted（核心）** | best AUC 0.723，best F1 0.727 |
| `bench_849_within.py` | **去混淆的逐集判别（最硬）** | 中位数 0.66–0.70，**最低 0.015** |

**测量环境警告**：测量期间本机 CPU 长期 98–100%（另有 8–11 个 ffmpeg + OBS + wallpaper64 在跑）。**所有耗时数字均为悲观值。**