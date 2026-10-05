# 03 · 音频侧自动定位「交战中 / 战斗结束 / 跑图」——调研报告

> 调研员：子 agent ｜ 日期：2026-10-05 ｜ 项目：`C:\Project\永劫无间`
> 角度：音频信号能不能自动定位战斗区间，替代/补充 14 路 Agent 读图判断战斗起止。
>
> **证据标签约定**：`实测` = 在本机（RTX 4060 Ti / 31GB RAM / Python 3.12）跑出来的数字；
> `文档` = 来自官方仓库 / 论文 / 官方 benchmark 页面（附链接）；
> `推断` = 我基于实测与文档做的推理，未直接验证；`未找到` = 搜过，确实没有。

---

## 0. 一页结论

| 问题 | 结论 | 标签 |
|---|---|---|
| 中文 ASR 谁最准最快 | **换 SenseVoiceSmall(FunASR)**：本机实测 RTF 0.008，比现在的 faster-whisper large-v3 快 **~100 倍**，中文明显更准 | 实测 |
| 19 分钟音频要跑多久 | SenseVoice ≈ **10 秒**；现状 faster-whisper large-v3 ≈ **15.6 分钟** | 实测 |
| 说话人分离能不能用 | pyannote community-1 **本机不可用**（HuggingFace gated）；改用 FunASR **CAM++**（ModelScope 通，已装成功） | 实测 + 文档 |
| 有没有开源模型能检测游戏战斗音效 | **未找到现成模型**。AudioSet/YAMNet 521 类、SenseVoice 的 AED 标签都没有近战格斗类 | 未找到 + 实测 |
| CLAP / audio embedding 做 few-shot「找相似战斗片段」 | **技术上最对路，但本机拿不到权重**（HF 不通）。Dasheng/YAMNet embedding 是可行的离线替代 | 文档 + 实测（网络阻断） |
| 「删除段语音战斗词扫描」能不能更好自动化 | 这条路**已被实测验证有效**（精确率 83%），换 ASR 即可显著提升；但它有**召回天花板**——实测有 72% 的战斗是全程无人声的 | 实测 |
| **能不能靠音频响度/活跃度判战斗** | **不能，且方向是反的**。实测响度 AUC 0.68、动态特征 AUC 0.34–0.41（反相关） | 实测 |

**一句话建议**：把 faster-whisper 换成 SenseVoiceSmall（10 秒 vs 15.6 分钟），这是投入产出比最高的一步；
**不要**再往「音频响度/静音检测」上投资（实测反相关）；真正缺的那块（无语音的战斗）只能靠自训音效分类器或音频嵌入检索。

---

## 1. 环境真相：这台机器连不上 HuggingFace（这决定了一半方案的可及性）

先查了网络，因为它直接否掉了一批方案。

| 主机 | TCP 443 | 影响 |
|---|---|---|
| `huggingface.co` | **不通** | pyannote community-1（gated）、Qwen3-ASR、AF3、Dasheng/AudioSet 权重 —— 全部要绕过 |
| `hf-mirror.com` | 通 | 可作 HF 镜像（需改 `HF_ENDPOINT`） |
| `www.modelscope.cn` | 通 | FunASR / SenseVoice / CAM++ / Paraformer 全部可下 |
| `pypi.org` / `github.com` | 通 | 装包正常 |

`实测`。证据：PowerShell `Test-NetConnection -Port 443`。

**推论（推断）**：本项目所有新增模型权重必须走 **ModelScope**，或给 HF 设 `HF_ENDPOINT=https://hf-mirror.com`。
`huggingface_hub` 离线缓存也只在 `C:\Project\永劫无间\.video-tools\models`（只有 4 个 faster-whisper 权重）。

**实测踩坑**：`pip install funasr modelscope` **不会自动带上 torch**，装完还得单独
`pip install torch torchaudio --index-url https://download.pytorch.org/whl/cu124`（拿到 2.6.0+cu124）。

### 1.1 附带发现：本机有 3 个遗留的 project ffmpeg 进程占着 GPU

`实测`。跑对照实验时 `nvidia-smi` 显示 GPU 99% 利用率、5912 MiB 占用，其中：

```
pid 24564 / 27016 / 30756  →  C:\Project\永劫无间\.video-tools\LosslessCut\resources\ffmpeg.exe
```

外加 obs64、wallpaper64、Chrome、微信、QQ 等一堆常驻程序共占约 2.5 GB。
`实测`：清掉我的 Python 作业后 GPU 回落到 14% / 2525 MiB。

**我没有动这三个 ffmpeg**（不确定是不是有在跑的粗剪任务在用）。
但按 AGENTS.md §2「绝不依赖临时、缓存或工具运行时目录」的精神，这类**超时/中断后遗留的
渲染进程**应该在任务收尾时清理掉——它会直接拖慢后续所有 GPU 音频批处理。
建议加一条：任务结束或超时后核对 `ffmpeg.exe` 残留。

### 1.2 关于 RTX 4060 Ti 上跑批的实测提醒

`实测`：同一段 300s、同一套 faster-whisper large-v3 fp16 参数，第一次跑 **245.7s（RTF 0.819）**，
第二次跑超过 20 分钟仍未完成，被我终止。两次之间我跑了 SenseVoice 与多次模型加载。
RTF 0.819 这个数取自**首次干净运行**。

**结论（推断）**：这台机器的音频批处理吞吐对「同时在跑什么」很敏感。
如果要批量跑很多局，**不要在同一张卡上并发多个 ASR 进程**，并且每次跑前先确认没有残留作业。
否则实测速度会严重退化，评估方案时容易被误导。

---

## 2. 转写：faster-whisper 之后的中文 ASR

### 2.1 本机实测对照（同一段音频，RTX 4060 Ti）

素材：`E:\OBS\869永劫无间 2026-10-03 19-08-41.mp4` 源 0–300s（`ffmpeg` 抽成 16k 单声道 wav）。

| 系统 | 配置 | 300s 音频耗时 | RTF | 19 分钟音频预计 |
|---|---|---|---|---|
| faster-whisper **large-v3**（现状） | cuda / float16 / beam 5 | **245.7 s** | **0.819** | **≈ 15.6 分钟** |
| **SenseVoiceSmall**（FunASR） | cuda + FSMN-VAD / batch 300s | **2.4 s** | **0.008** | **≈ 10 秒** |
| SenseVoiceSmall（复跑） | 同上 | 3.07 s | 0.0102 | ≈ 12 秒 |

`实测`。加速比约 **80–100×**。

**注意一个坑（实测）**：SenseVoice 不挂 VAD 直接喂长音频，只会解前 ~30 秒，返回单个字符串。
必须 `vad_model="iic/speech_fsmn_vad_zh-cn-16k-common-pytorch"`，否则长音频静默丢内容。

### 2.2 质量：SenseVoice 在这段素材上明显更准

同样 300 秒，`实测` 转写内容对比（节选）：

- **SenseVoiceSmall**：`护甲该修修了` / `准备好武器才好比刀` / `出手一刀，1518` / `现在应该没人了` /
  `三江倒海` / `这种人就不想杀了` / `基因之力，敢敢灭一切` / `好运气竟然会站在我这边`
- **faster-whisper large-v3**（在 864 同类素材上的既有产物 `combat_voice_index.json`）：
  `接跑法能量` / `内游全观众登高` / `子贵五毒洒五刀六魂枪` / `分尸多加` / `解阴者` / `是熟悉的感情`

中文语义连贯性差距非常明显。这对本项目尤其关键，因为**唯一有效的漏战检测手段依赖关键词字面命中**——
转写错了字，「谁在打我」「没事我杀了」就检不出来。

**对比来源说明（诚实标注）**：上表 faster-whisper 一栏取自**项目自己的既有产物**
`123\21.864...\analysis\combat_voice_index.json`（同款 faster-whisper large-v3、同款永劫素材的 182 条 cue），
不是同一段 300s 的实时对跑。我尝试过实时对跑，但第二个 faster-whisper 进程比第一次慢 3 倍以上、
跑 20 分钟未出结果被我主动终止（见 §2.4），因此**没有同一段音频的严格 A/B**。
结论方向可靠（同一模型、同一素材类型、同一用途），但严格意义上不是受控对比。

文档侧的公开 benchmark 也支持这个方向（SenseVoice 官方仓库 184 条普通话 clip 的自测，`文档`）：

| 系统 | micro-CER (normalize_zh) | CPU 速度 |
|---|---|---|
| Fun-ASR-Nano | 8.06 / 8.42 | LLM 解码，较慢 |
| **SenseVoiceSmall** | **7.81 / 8.17** | ~20× 实时 |
| Paraformer | 10.18 / 9.89 | ~21× 实时 |
| whisper.cpp small | 22.12 | 4.6× |
| whisper.cpp large-v3-turbo | 23.15 | 3.2× |

来源：<https://github.com/FunAudioLLM/SenseVoice/blob/main/runtime/llama.cpp/BENCHMARKS.md>
（注意：这是 SenseVoice 自家仓库的自测对比，不是第三方评测，`推断`其数字偏乐观，但方向与本机实测一致。）

### 2.3 候选模型横评（中文，本机 8GB 显存可及性）

| 模型 | 参数量 | 中文 CER（文档） | 8GB 显存 | 权重可达 | 建议 |
|---|---|---|---|---|---|
| **SenseVoiceSmall** | ~234M | 7.81（自测）/ 3.09 AISHELL-1 | ✅ 余量极大 | ✅ ModelScope | **首选**，已实测通过 |
| Paraformer-zh | 0.2B | 9.89（自测） | ✅ | ✅ ModelScope | 备选，略慢略差 |
| Fun-ASR-Nano | enc + Qwen3-0.6B | 8.06（自测） | ✅ 需 ~4–6GB | ✅ ModelScope | 想再准一点再考虑 |
| **Qwen3-ASR-1.7B** | 1.7B | WenetSpeech-net **4.97** / AISHELL-2 2.71 | ✅ fp16 约 4–5GB | ⚠️ HF（需镜像） | 文档上中文最强，**本机未实测** |
| Qwen3-ASR-0.6B | 0.6B | 5.97 / 3.15 | ✅ | ⚠️ HF | 同上 |
| FireRedASR-AED | 1.1B | avg-4 **3.18** | ✅ | ⚠️ HF | 精度最高但取不到 |
| FireRedASR2-LLM | — | avg-4 **2.89**，rtf 0.0681 | ❌ 大 | ⚠️ HF | 本机不可行 |

来源：
- Qwen3-ASR：<https://github.com/QwenLM/Qwen3-ASR>、<https://arxiv.org/html/2601.21337v2>（`文档`，Apache-2.0）
- FireRedASR：<https://github.com/FireRedTeam/FireRedASR>、<https://arxiv.org/html/2501.14350v1>（`文档`）
- FireRedASR2S / FireRedVAD：<https://huggingface.co/FireRedTeam/FireRedVAD>（`文档`，2026-03 发布）

**Whisper 有更新吗**：`文档` + `未找到`——没有找到 Whisper 家族的新一代（无 large-v4 之类）。
官方最新仍是 large-v3 / large-v3-turbo（2024），faster-whisper 最新仍是 1.2.1（本机已装，即当前最新版）。
中文上 Whisper 大模型被后来者全面超过，因为它多语种训练、中文只是一个小切片，且中文同音字替换错误多。

---

## 3. 说话人分离（diarization）

| 方案 | 状态 | 标签 |
|---|---|---|
| **pyannote.audio 4.0.7 / community-1** | 官方最新开源模型（2025-09-29 更新），DER 优于 3.1；**但模型在 HuggingFace gated，必须申请 token + 接受条款**。本机 HF 不通 → **用不了** | 文档 + 实测（网络阻断） |
| pyannote precision-2 | 付费云/私有部署 | 文档 |
| **FunASR CAM++** | ✅ **可用**。192 维 embedding，28.5MB，VoxCeleb EER 0.73% / CN-Celeb 6.78%。ModelScope 直下，已在本机装成功 | 文档 + 实测 |

来源：<https://huggingface.co/funasr/campplus>、<https://www.funasr.com/en/blog/funasr-speaker-diarization.html>
pyannote：<https://github.com/pyannote/pyannote-audio>、<https://www.pyannote.ai/blog/community-1>

CAM++ 一行代码接入 ASR 流水线（转写 + 时间戳 + 匿名 speaker 标签一起出）：

```python
from funasr import AutoModel
m = AutoModel(model="paraformer-zh", vad_model="fsmn-vad",
              punc_model="ct-punc", spk_model="cam++")
res = m.generate(input="clip.wav", batch_size_s=300)
for s in res[0]["sentence_info"]:
    print(s["start"], s["end"], "spk", s["spk"], s["sentence"])
```

**对本项目的价值（推断）**：现在规则写着「只保留玩家/队友人声」，但 faster-whisper 不做说话人身份识别，
这一条其实是空的。CAM++ 补上后可以：把队友语音单独聚成一类，与游戏本体音效分离；
再叠加 §2 的战斗关键词扫描，误报率会比现在低。

---

## 4. 音频事件检测（AED）：检测游戏战斗音效

### 4.1 结论：现成模型没有这类标签

`未找到`。逐一核对：

| 候选 | 类别覆盖 | 能否用 |
|---|---|---|
| **YAMNet**（AudioSet 521 类） | 只有 `Gunshot, gunfire`、`Collision`、`Impact sounds` 等通用类。**没有任何近战格斗 / 兵器碰撞 / 技能释放 / 击杀播报类** | ❌ 语义不对口 |
| **SenseVoice 自带 AED** | 标签只有 8 个：`<\|BGM\|>` `<\|Speech\|>` `<\|Applause\|>` `<\|Laughter\|>` `<\|Cry\|>` `<\|Sneeze\|>` `<\|Breath\|>` `<\|Cough\|>` | ❌ 完全不覆盖 |
| **PANNs / BEATs / AST** | 都是 AudioSet 系，同上 | ❌ |
| **VGGSound**（310 类，YouTube 弱标注） | 有 `people battle cry`，**没有兵器碰撞/技能音** | ❌ 且数据本身有噪声 |
| **CLAP / LAION-CLAP** | 开放词表，靠文本 prompt 匹配 | ⚠️ 见 §5，理论可行但本机取不到权重 |
| 专用游戏音效数据集 | 只找到 **枪声**类（BGG 枪械数据集、Forensic、C3GD）——永劫无间是**近战格斗**，枪声数据集不适用 | ❌ |

来源：YAMNet <https://www.tensorflow.org/hub/tutorials/yamnet>、
AudioSet 本体 <https://github.com/audioset/ontology>、
SenseVoice README（AED 段）<https://github.com/FunAudioLLM/SenseVoice>、
VGGSound <https://www.robots.ox.ac.uk/~vgg/data/vggsound/>、`gunshot_recognition` 类仓库页。

### 4.2 SenseVoice 的 AED 标签在本素材上实测无效

`实测`：300 秒音频里 SenseVoice 输出了 54 个 utterance 的事件标签，

```
EVENT  tags : {'Speech': 54}      ← 54/54 全是 Speech，零区分度
EMOTION tags: {'NEUTRAL': 33, 'EMO_UNKNOWN': 19, 'SAD': 1, 'HAPPY': 1}
LANG   tags : {'zh': 50, 'en': 4}
```

也就是说：它**完全无法**区分「人在纯 BGM 上说话」和「人在刀光音效上说话」；
情绪标签 96% 是 NEUTRAL/UNKNOWN，也带不出战斗强度。SenseVoice 官方自己就写明
「its event classification performance has some gaps compared to specialized AED models」（`文档`）。

**这否掉了「换个模型就自带战斗音效识别」的幻想。**

### 4.3 真正可行的两条路（都要自己训数据）

`文档` + `推断`：

1. **微调一个轻量分类头**（推荐）。冻结 YAMNet/Dasheng 主干，只训一个线性头。
   YAMNet 官方就支持这种用法——「1024 维 embedding 适合作为小数据集迁移学习输入」（`文档`）。
   Dasheng 更强：Base/0.6B/1.2B 在 HEAR benchmark 均分 61.9 / 66.6 / 68.6，
   且开源 fine-tune 工具 `mdl-toolkit`（含 ESC-50 中文示例 Notebook）。
   - 数据来源不需要外部数据集：**用现成的 864 战斗/删除段时间线当标签**（§6 有现成的 5 段战斗 + 6 段删除段标注）。
   - 参考一个同类小项目 `cozec/audio_event_detection`：YAMNet+微调头，TFLite 后 15–16MB、CPU 0.63ms/窗、140× 实时。
2. **开放词表 SED**。FlexSED（WASPAA 2025）用 Laion-CLAP 文本编码器 + Dasheng 初始化做开放词表检测，
   5-shot 就能恢复到全模型性能的 80–94%。适合「我要检测任意一种兵器碰撞」这种不定类别的需求。

### 4.4 顺带：能不能先剥掉 BGM

`文档` + `推断`：Demucs 可以分 vocals/drums/bass/other，理论上能压掉游戏 BGM 让音效/语音更干净。
但要注意：**上游 facebookresearch/demucs 已归档不再维护**，要用 `adefossez/demucs` fork。
我没有在永劫素材上实测 Demucs 的效果（音效会被误分到哪一路未知），列为待验证项。

---

## 5. 音频嵌入检索（few-shot：给一段已知战斗样本，找相似的）

用户的直觉是对的——这比分类器更可能好用，因为**不用定义类别**。

| 方案 | 机制 | 本机可及性 |
|---|---|---|
| **CLAP / MS-CLAP（微软）** | 文本-音频对比学习，zero-shot 检索。ESC-50 zero-shot 93.9%。`pip install msclap` | ❌ 权重在 HF |
| **LAION-CLAP** | 同上，HuggingFace 模型 | ❌ HF 不通 |
| **Omni-Embed-Audio**（ACL 2026） | LLM backbone 做检索，hard-negative 判别比 CLAP 强（HNSR@10 +4.3pp） | ❌ 太大 + HF |
| **Dasheng（推荐）** | 272k 小时掩码音频编码器，HEAR 均分 61.9–68.6，支持 clip 级和 frame 级特征。`pip install dasheng`（PyPI 有） | ⚠️ 权重在 HF，**但可试 hf-mirror** |
| **YAMNet embedding** | 1024 维/0.96s 窗，官方明说适合迁移学习。有现成 ONNX 导出（`audiomagic/yamnet-onnx`） | ⚠️ 需确认能否绕开 HF |
| MiDashengLM-0.6B | Dasheng 编码器 + Qwen3-0.6B 解码，**有 GGUF 3–16bit 可纯 CPU 跑** | ⚠️ 同上 |

来源：CLAP <https://github.com/microsoft/CLAP>、
Omni-Embed-Audio <https://aclanthology.org/2026.acl-long.1038.pdf>、
Dasheng PyPI <https://pypi.org/project/dasheng/>、
MiDashengLM <https://github.com/xiaomi-research/dasheng-lm>、
FlexSED <https://engineering.jhu.edu/lcap/data/uploads/pdfs/waspaa2025_2_hai.pdf>

**用法（推断）**：拿 864 里已经确认是战斗的 3–5 段（比如 887–1128）当 query 样本，
对全片按 2 秒窗滑窗提 embedding，算余弦相似度取 top-N。CLAP 的 audio-audio 相似度天然支持这个用法
（`get_audio_embeddings` + `compute_similarity`），不需要文字描述。

**风险（推断）**：CLAP 类模型在**同域内**相似度检索通常还行，但跨域（AudioSet/Caption 数据 → 国产近战游戏合成音效）
很可能退化。而且永劫素材**音频极密**——`实测` 869 素材 300 秒里只有 15.2% 的帧低于 -45 dBFS，
中位数 -33.5 dBFS，BGM 几乎全程铺底，这会严重压缩嵌入空间的对比度。**必须先小样本验证再投入。**

---

## 6. 组合方案：哪些音频信号能互补画面侧的漏战检测

这一节我用了**项目自己的真实标注数据**做实测，而不是纸上推演。

### 6.1 可用的现成真值

`实测`。任务 `21.864永劫无间` 里有：
- `timeline\combat_episodes_v3.json`：5 段确认战斗窗口（源 179–266.5 / 286–556 / 595–686 / 727–836.5 / 887.5–1128.5，共 799.0s）
- 同文件 `deleted_intervals`：6 段确认非战斗删除段（共 353.2s）
- `analysis\combat_voice_index.json`：faster-whisper large-v3 转写（182 条 cue）
- `analysis\audio_activity.json`：逐秒 dBFS（1152 个采样点）

⚠️ 坑：`E:\PR导出\864....mp4` **源文件已被清理**，所以上面只能做「离线特征 vs 标签」的检验，
**无法**在本机重新提取 864 的频谱去验音效分类器。要做音效实验得用还在的 869/871/872，
但那几局没有人工战斗标注——**这是下一步最该补的东西**。

### 6.2 实测结果一：语音密度判战斗 —— **方向是反的**

`实测`。用转写 cue 的时长覆盖：

| 区间 | 时长 | 语音覆盖 | 密度 |
|---|---|---|---|
| combat_001 | 87.5s | 87.2s | 99.7% |
| combat_002 | 270.0s | 131.0s | 48.5% |
| combat_003 | 91.0s | 90.2s | 99.1% |
| **combat_004** | 109.5s | **30.5s** | **27.9%** |
| combat_005 | 241.0s | 173.3s | 71.9% |
| **全部战斗** | 799.0s | 512.3s | **64.1%** |
| **全部非战斗** | 353.2s | 287.0s | **81.3%** |

**判别比 = 0.79×**——非战斗区间的语音密度**更高**。
原因很清楚：删除段里 0–179s 是「开局选法门 + 货郎交易 + 大厅闲聊」，队友全程在讨论配装；
反过来 combat_004 那场 109 秒的战斗有 **72% 时间完全没人声**。

> **这条实测直接否掉了「用语音活跃度筛战斗」这条路**（`推断`：AGENTS.md §8.1 的三信号里
> 「音频活动强度」这一路，在语音层面是负相关的，不该再当独立信号用）。

### 6.3 实测结果二：响度 / 动态特征判战斗 —— 弱到不可用

`实测`。逐秒 dBFS 当战斗打分，AUC 与最佳单阈值：

| 特征 | AUC | 最佳阈值准确率 | 误报 |
|---|---|---|---|
| 响度 dBFS | **0.6822** | 70.3%（阈值 -30.8 dB） | 258 / 349 |
| dB 相对全局中位数 | 0.6822 | 70.3% | 258 / 349 |
| 逐秒 dB 绝对变化量 | 0.4109 | — | — |
| 5 秒窗 dB 变化标准差 | **0.3393** | — | — |
| 10 秒窗 dB 极差 | 0.4079 | — | — |
| 3 特征逻辑回归（5 折 CV） | 0.6383 | 50% 标记率下 P=0.79 R=0.57 | — |

平均响度：战斗 -25.37 dBFS，非战斗 -28.77 dBFS（战斗**响 3.39 dB**）。

**结论（实测）**：
- 响度是唯一有正向信号的，但 AUC 0.68、最佳阈值仍有 **74% 误报率**，单独用不了。
- 三个「动态性」特征 AUC 全部 **< 0.5**，即**反相关**——战斗时声音反而更平稳。
  （合理解释：非战斗段是多人语音 + 环境切换，声音忽起忽落。）
- 加了动态特征的多特征模型 **AUC 反而降到 0.638**，不如单看响度。

> **这条实测说明：不要再往「响度阈值 / 静音检测 / 音频活动强度」上投资。**
> 现在 AGENTS.md §4 工作流里的 Auto-Editor 静音参考，对找战斗起止**没有增益**。

### 6.4 实测结果三：严格战斗词 —— **确实有效（唯一被验证的音频信号）**

`实测`。用严格高精度词表（打了/杀了/死了/快跑/打我/来了/别躲/敌人/赢了/能赢）扫 182 条 cue：

```
命中 cue 数：12
  落在已标注战斗窗口内：10   → 精确率 83%
  落在删除段（非战斗）  ：2
```

两条误报都很有信息量：
- `t=17.26 「杀包」` —— 命中「杀」但其实是**舔包**（字面撞词）
- `t=161.7 「我靠我谁在打我」` —— 命中两次「打我」，但 `deleted_intervals` 里已登记反证：
  该时刻玩家满血、身边是队友、屏内零敌方血条，是**讨论法门效果的开玩笑**，不是交战播报。

> 这两条误报说明：**换更好的 ASR 能减少误报**（SenseVoice 转写更准，字面撞词更少），
> 但**语义消歧仍需保留人工复核**。这也和项目现有做法一致——`roughcut-launch.md` 里的
> 「删除段审计员」角色正是干这个的。

### 6.5 关键词路径的召回天花板 —— 这是真正的缺口

`实测`。转写 cue 之间大于 5 秒的空档共 14 处、共 317.1 秒。最长的一个：

```
940.23s → 1006.70s   空档 66.5 秒
```

而 `combat_episodes_v3.json` 里 combat_005 明确写着 **949–1019 连续交战**（伤害数字 162/156、
敌方大招「寂静暗刑」、伤害 654、击杀「祝什么那 已淘汰」……）。

> **一场 70 秒的连续战斗，中间 66.5 秒没有任何语音。**
> 语音关键词扫描在这一段**结构性失明**，无论换多好的 ASR 都救不了。

再叠加 §6.2 的 combat_004（109 秒战斗只有 27.9% 有语音），可以下一个明确判断：

**（推断）语音关键词路径的召回上限，取决于「这场战斗有没有人说话」，
而近战格斗的静默战斗占比很高。项目要补的缺口是「无语音战斗的检测」，
这只能靠音效/音乐结构信号，也就是 §4 和 §5 那两条路。**

### 6.6 各信号与画面侧的互补关系

| 音频信号 | 与画面关系 | 实测/判断 |
|---|---|---|
| 严格战斗词扫描 | **强互补**（完全独立于画面） | `实测` 精确率 83%，是目前唯一验证过的 |
| 语音密度 / 音频活动强度 | **反相关，弃用** | `实测` 0.79× |
| 响度 dBFS | 弱互补，只能当粗筛 | `实测` AUC 0.682 |
| 语音时间线的**形状**（连续性、突增） | 可能互补，未验 | `推断`——比密度更有意义：漏战那段是「66 秒绝对安静」，可能与全局分布离群 |
| 说话人聚类（CAM++） | 互补：过滤非队友语音、剔除游戏提示音误转写 | `文档` |
| 游戏音效分类 / 音频嵌入检索 | **唯一能覆盖无语音战斗的路径**，但要自训 | `未找到`现成模型 + `推断` |

---

## 7. 落地建议（按投入产出排序）

### 第 1 步：换 ASR（几乎零成本，收益最大）

```powershell
# 一次性安装（注意 torch 不会自动装）
C:\Project\永劫无间\.video-tools\venv\Scripts\python.exe -m pip install funasr modelscope
C:\Project\永劫无间\.video-tools\venv\Scripts\python.exe -m pip install torch torchaudio --index-url https://download.pytorch.org/whl/cu124
```

```python
from funasr import AutoModel
m = AutoModel(model="iic/SenseVoiceSmall",
              vad_model="iic/speech_fsmn_vad_zh-cn-16k-common-pytorch",
              device="cuda", disable_update=True)
r = m.generate(input="clip.wav", batch_size_s=300, use_itn=True)
```

- 19 分钟音频 **≈10 秒**，对比现在 **15.6 分钟**。
- 转写质量明显更好 → 战斗关键词命中率上升 → 漏战检测的召回上升。
- ⚠️ 必须挂 VAD，否则长音频只解前 30 秒（实测踩过）。
- ⚠️ 保留现有 faster-whisper 作为对照基线，别直接删（`tests/` 或门禁里可能要引用旧产物）。

### 第 2 步：加 CAM++ 说话人分离

同样走 ModelScope，一行 `spk_model="cam++"` 接进上面的流水线。
让「只保留玩家/队友人声」从规则变成可执行的东西，顺带压掉 §6.4 那类撞词误报。

### 第 3 步：**先补标注，再谈音效模型**

这是我认为最被低估的一步。音效分类器 / 嵌入检索能不能用，**完全取决于有没有本域标注**，
而现在 `E:\PR导出` 里 869–872 四局都没标注、864 源文件已被清理。

建议：拿还在的 `E:\OBS\869永劫无间 2026-10-03 19-08-41.mp4`（2398.8s）
照 `combat_episodes_v1.json` 的 schema 标一遍战斗窗口，然后：
1. 留出**无语音战斗**（对照 combat_004、combat_005 的 940–1007s）
2. 用它训 §4.3 的 Dasheng/YAMNet 线性头，或验证 §5 的嵌入检索

没有这步，§4/§5 都只能停在「理论上可行」。

### 本次调研留下的临时环境

调研在**项目 venv 之外**另建了一个临时环境做实测，**没有改动项目 venv**：

```
C:\Users\Administrator\AppData\Local\Temp\opencode\asrbench\venv
  funasr 1.4.16 + modelscope 1.40.1 + transformers 5.18.0 + torch 2.6.0+cu124 + torchaudio 2.6.0
```

`实测`产物（转写对比、特征脚本）也在同目录 `audioprobe\`。确认方案后可直接删掉整个 `asrbench\`，
或按第 1 步正式装进项目 venv。

### 明确不要做的

- ❌ 别再调静音阈值 / 响度阈值找战斗（`实测` 反相关）
- ❌ 别指望 SenseVoice 的 AED 标签（`实测` 54/54 全 Speech）
- ❌ 别指望 YAMNet/AudioSet 直接给战斗音效（`未找到` 这类标签）
- ❌ 别碰 pyannote（HF gated + 本机 HF 不通）

### 需要人确认的

1. 要不要给 HF 设 `HF_ENDPOINT=https://hf-mirror.com`？（能开的话 Dasheng / Qwen3-ASR / pyannote 全部解锁）
2. 869 那 40 分钟要不要我先做标注？这决定第 3 步能否开工。
3. 是否接受把 SenseVoice 引入项目 venv（会新增 funasr + torch 依赖）？

---

## 8. 参考链接

**ASR**
- SenseVoice（官方仓库，含 llama.cpp benchmark）：<https://github.com/FunAudioLLM/SenseVoice>
- SenseVoice llama.cpp CPU benchmark：<https://github.com/FunAudioLLM/SenseVoice/blob/main/runtime/llama.cpp/BENCHMARKS.md>
- SenseVoiceSmall 模型卡：<https://huggingface.co/FunAudioLLM/SenseVoiceSmall>
- Qwen3-ASR 仓库 / 技术报告：<https://github.com/QwenLM/Qwen3-ASR> · <https://arxiv.org/html/2601.21337v2>
- FireRedASR / 技术报告：<https://github.com/FireRedTeam/FireRedASR> · <https://arxiv.org/html/2501.14350v1>
- FireRedASR2S / FireRedVAD：<https://huggingface.co/FireRedTeam/FireRedVAD> · <https://arxiv.org/pdf/2603.10420>
- faster-whisper（现状）：<https://github.com/SYSTRAN/faster-whisper>

**说话人**
- CAM++（FunASR）：<https://huggingface.co/funasr/campplus>
- FunASR diarization 教程：<https://www.funasr.com/en/blog/funasr-speaker-diarization.html>
- pyannote.audio / community-1：<https://github.com/pyannote/pyannote-audio> · <https://www.pyannote.ai/blog/community-1>

**AED / 音效**
- AudioSet 本体：<https://github.com/audioset/ontology>
- YAMNet：<https://www.tensorflow.org/hub/tutorials/yamnet>
- AudioSet strong labels：<https://research.google.com/audioset/download_strong.html>
- VGGSound：<https://www.robots.ox.ac.uk/~vgg/data/vggsound/>
- FlexSED（开放词表 SED，WASPAA 2025）：<https://engineering.jhu.edu/lcap/data/uploads/pdfs/waspaa2025_2_hai.pdf>
- Demucs（已归档，fork）：<https://github.com/adefossez/demucs>

**音频嵌入 / 检索**
- Microsoft CLAP：<https://github.com/microsoft/CLAP>
- LAION-CLAP：<https://github.com/LAION-AI/CLAP>
- Dasheng（PyPI）：<https://pypi.org/project/dasheng/>
- MiDashengLM：<https://github.com/xiaomi-research/dasheng-lm>
- Omni-Embed-Audio（ACL 2026）：<https://aclanthology.org/2026.acl-long.1038.pdf>
- Query-by-Example 综述性工作：<https://arxiv.org/abs/1706.03818>

**游戏/电竞音频**
- 电竞语音通信分析（Whisper + pyannote + 对齐）：<https://arxiv.org/html/2411.19793v1>
- 体育高光音频检测（Mel 频谱 + 多模态）：<https://arxiv.org/pdf/2501.16100>
- 游戏高光生成（X-CLIP 零样本，AMD）：<https://arxiv.org/pdf/2505.07721>

**项目内证据**
- `123\21.864永劫无间 2026-09-30 02-57-13\timeline\combat_episodes_v3.json`
- `123\21.864永劫无间 2026-09-30 02-57-13\analysis\combat_voice_index.json`
- `123\21.864永劫无间 2026-09-30 02-57-13\analysis\audio_activity.json`
- `E:\OBS\869永劫无间 2026-10-03 19-08-41.mp4`（ffprobe：2560×1440 / HEVC / 60fps / 2398.8s / AAC 48kHz 立体声 159 kbps）