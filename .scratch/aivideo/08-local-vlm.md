# 08 — 本机（RTX 4060 Ti 8GB）视觉模型可行性调研

**调研员**：subagent · **日期**：2026-10-05 · **目标**：本机能跑哪些视觉模型，用来替代人工读图判断「这段有没有战斗」

**标注约定**：每条结论标 **【实测】**（本次在这台机器上真跑过）/ **【文档】**（厂商或仓库声明）/ **【推断】**（由实测数据合理外推）/ **【未找到】**。

---

## 0. 一句话结论（先看这个）

> **本机 8GB 显存唯一值得装的视觉模型是 `Qwen3-VL-4B-Instruct` 的 `Q4_K_M` GGUF（2382 MB + 433 MB mmproj）。**
> 实测峰值显存 **7103 MiB / 8188 MiB**，5 帧窗口 **1.59 s/窗口（0.32 s/帧）**。
> **但它在人工标注的真值上只有 70.1% 平衡准确率 —— 该装，但只能当"召回型预筛"，不能当裁决器，替代不了审片。**
>
> 反而**被低估的是 OCR**：30 MB 模型、纯 CPU、960px **1.1 s/帧**，中文识别置信度 1.00，
> 能稳定读出 `25/60` 弹药、`06:53` 暗域计时、`[淘汰]xxx`、`【万夫莫政·2重】击败（2/5)` 击杀播报。
> 这些是**确定性字符串匹配**，比 VLM 的模糊判断更可审计、更便宜。

**并且有一条比选模型重要得多的发现（见 §5.3）**：本任务里「这一帧有没有战斗」**根本不是一个良定义的帧级问题**。项目自己的 §8.1 铁律已经写明"战术停顿要包含进来"，所以任何单帧"非交战"判定**都不构成删除依据**。这才是 8GB 上做视觉替代方案的天花板所在。

---

## 1. 环境真源（本次实测，不是查表）

| 项 | 实测值 | 来源 |
|---|---|---|
| GPU | NVIDIA RTX 4060 Ti，**8188 MiB**，驱动 616.92，CUDA UMD 13.4 | `nvidia-smi`【实测】 |
| GPU 桌面占用（会话开始） | 1418 MiB | 【实测】 |
| GPU 桌面占用（跑测试时） | **3707–4194 MiB**，GPU util 65%，但 compute-apps 列表**无计算进程** | 【实测】 |
| 争用者 | `GameViewer.exe`（远控录屏）、`wallpaper64.exe`、`dwm.exe`、Chrome、OBS | 【实测】 |
| CPU / RAM | Ryzen 7 7800X3D 8c16t / 31.1 GB 总，18.2 GB 空 | 【实测】 |
| 磁盘 | C: 195 GB / D: 237 GB / E: **146.9 GB** 空 | 【实测】 |

### 1.1 ⚠️ 关键环境事实：本机网络是半封闭的

安装任何东西之前必须知道这个，否则会白等半小时。

| 域名 | 状态 | 备注 |
|---|---|---|
| `huggingface.co` | **❌ 阻断**（curl `http=000`） | 直连 LFS 必失败 |
| `cdn-lfs.huggingface.co` | **❌ 阻断** | |
| `github.com` | **❌ 阻断** | |
| `objects.githubusercontent.com` | **❌ 阻断** | release 资产下载必失败 |
| `hf-mirror.com` | ✅ 可用 | **必须设 `HF_ENDPOINT=https://hf-mirror.com`** |
| `ghfast.top` | ✅ 可用，**13 MB/s** | GitHub release 镜像，实测 146 MB 十几秒下完 |
| `gh-proxy.com` | ✅ 可用 | 较慢（约 0.15 MB/s） |
| `ghproxy.net` | ⚠️ 可用但**不支持断点续传**（返回 200 而非 206），传到 43 MB 卡死 | **别用** |
| `pypi.org` | ✅ 可用 | |

**结论**：所有下载 URL 必须走 `hf-mirror.com` + `ghfast.top`。`huggingface_hub` 默认端点在本机不可用，要设 `HF_ENDPOINT` 环境变量。

### 1.2 现有 venv 的能力边界

`C:\Project\永劫无间\.video-tools\venv`（Python 3.12.10）【实测 `pip list`】：

- ✅ 有：`faster-whisper 1.2.1`（GPU 转写可用）、`onnxruntime 1.29.0`、`opencv-python 5.0.0.93`、`numpy 2.5.2`、`scikit-learn 1.9.0`、`av 18.1.0`、`tokenizers 0.23.1`、`huggingface_hub 1.28.0`
- ❌ **无** `torch`、无 `transformers`、**无 PIL**、无任何 OCR
- ⚠️ **`onnxruntime 1.29.0` 是纯 CPU 版**：`get_available_providers()` → `['AzureExecutionProvider', 'CPUExecutionProvider']`【实测】

所以"在现有 venv 里直接跑视觉模型"**不成立**——没有 torch，也没有 GPU 版 onnxruntime。

**若走 OCR 路线（推荐）**：不要污染项目 venv（rapidocr 会拖 shapely/pyclipper，且项目 venv 是 faster-whisper 的基座）。另建隔离 venv，且按 AGENTS.md §2 铁律，基座必须是**系统 Python**：

```powershell
& 'C:\Users\Administrator\AppData\Local\Programs\Python\Python312\python.exe' -m venv <venv路径>
<venv>\Scripts\python.exe -m pip install rapidocr onnxruntime opencv-python-headless
```

---

## 2. 8GB 显存下的 VLM 清单（含实测 GGUF 体积）

GGUF 体积均为 HF API `tree/main` 实测（【实测】），不是查表：

| 模型 | LM (Q4_K_M) | mmproj (Q8_0) | 合计 | 中文 | 本机可跑? |
|---|---|---|---|---|---|
| **Qwen3-VL-4B-Instruct-GGUF** | 2382 MB | 433 MB | **2.82 GB** | 强 | ✅ **本次已跑通并实测** |
| **Qwen3-VL-2B-Instruct-GGUF** | 1056 MB | 424 MB | **1.48 GB** | 强 | ✅ **本次已跑通并实测** |
| Qwen2.5-VL-3B (ggml-org) | 1840 MB | 806 MB | 2.65 GB | 强 | 【推断】可跑，未实测 |
| OpenGVLab/InternVL3-1B-hf | 1790 MB (safetensors) | 随主模型 | 1.79 GB | 中 | ⚠️ 需 torch+transformers，bf16 精度，8GB 紧 |
| HuggingFaceTB/SmolVLM2-2.2B-Instruct | 8571 MB (safetensors) | — | 8.57 GB | 中 | ❌ 无可用 GGUF，bf16 太大；压缩版未找到可靠来源 |
| vikhyatk/moondream2 | 2708 MB (text **f16**) | 868 MB (f16) | 3.58 GB | 弱 | ⚠️ 官方 GGUF 只有 f16，无量化版；【推断】可跑但显存浪费、中文弱 |
| openbmb/MiniCPM-V-4_5 | 16586 MB (bf16) | — | 16.6 GB | 强 | ❌ 必须量化，官方无 8GB 友好版本 |
| google/gemma-3-4b-it | 需第三方 GGUF | — | — | 中英 | 【未找到】官方 GGUF 缺失；视觉塔较重，8GB 很紧 |

**关于「量化后显存占用」的实测修正**【实测】：网络上流传的 "2B → 1.5GB / 4B → 5GB" 这类表格**在本机完全不成立**。实测 llama-server 加载后：

- 2B（ctx8192/imt1024）：**idle 7518 MiB**，推理峰值 **7798 MiB**（只剩 390 MiB 余量）
- 4B（ctx8192/imt1024）：**idle 7730 MiB**，峰值 **7768 MiB**（只剩 420 MiB）

权重才 1.5–2.8 GB，却占了 7.5 GB。**主因不是权重，是 `--image-max-tokens`（视觉 token 上限）决定的视觉计算缓冲区**，见 §5.4。**所以本机显存的实际控制旋钮是 `--image-max-tokens`，不是模型大小。**

---

## 3. 专攻视频的轻量模型 —— 结论：不存在可用选项

【实测】用 HF API 按下载量/点赞排序实查了全部主流视频 VLM：

| 模型 | 参数量 | 下载量 | 判断 |
|---|---|---|---|
| `yaolily/TimeChat-Captioner-GRPO-7B` | **7B** | 723 | 7B，且社区几乎不用 |
| `wyccccc/TimeChatOnline-7B` | **7B** | 220 | 7B |
| `ShuhuaiRen/TimeChat-7b` | **7B** | **0** | 7B，零下载 |
| `MCG-NJU/VideoChat3-4B` | 4B | 2549 | 最小的一个，但是小众研究模型，非 GGUF |
| `OpenGVLab/VideoChat-Flash-Qwen2-7B_res448` | **7B** | 1565 | 7B |
| `OpenGVLab/InternVideo2_5_Chat_8B` | **8B** | 4077 | 8B |
| `yanziang/InternVideo3-8B-Instruct` | **8B** | 1467 | 8B |
| `llava-hf/LLaVA-NeXT-Video-7B-hf` | **7B** | 102313 | 7B，FP16 约 14 GB，超 8GB |
| `lmms-lab/LLaVA-Video-7B-Qwen2` | **7B** | 11849 | 7B |

**结论【实测 + 推断】：3B 以下的视频专用模型，一个都没有。** 时间视频 VLM 的最小可用尺寸卡在 7B（FP16 约 14 GB，Q4 量化后约 5 GB + 视觉塔），而 8GB 显存跑 7B VLM 会把余量压到 1 GB 以内、且必须牺牲分辨率——对本任务（需要看清 HUD 血条和伤害数字）恰好是最不能牺牲的东西。

**替代方案（本次已实测可行）**：Qwen3-VL 原生支持**多图交错输入**，用多张抽帧模拟时序。llama.cpp 的 `llama-mtmd-cli` 支持：
- `--image f1,f2,f3`（逗号分隔多图）【实测，5 图窗口跑通】
- `--video FILE --video-fps 2`（原生视频抽帧）【实测能跑，见下】

**⚠️ 但原生 `--video` 路径慢 20 倍**【实测】：8 秒片段 @2fps = 19 chunks，`llama-mtmd-cli` 墙钟 **116.66 s**（含 ~16 s 模型加载），≈ **6.3 s/帧**；而"ffmpeg 抽帧 → HTTP 多图 API"只要 **0.32 s/帧**。

> **操作结论：不要用 `--video`。用 ffmpeg 抽帧，走 `llama-server` 的 OpenAI 兼容多图接口，快 20 倍。**

---

## 4. OCR —— 本次调研里性价比最高的一项

### 4.1 装什么

【实测】`RapidOCR 3.9.2`（不是 PP-OCRv4，它现在默认带的是 **PP-OCRv6**）：

| 文件 | 体积 |
|---|---|
| `PP-OCRv6_det_small.onnx` | 9.47 MB |
| `PP-OCRv6_rec_small.onnx` | 20.25 MB |
| `ch_ppocr_mobile_v2.0_cls_mobile.onnx` | 0.56 MB |
| **合计** | **30.3 MB** |

```powershell
# 隔离 venv（基座必须是系统 Python，见 AGENTS.md §2）
& 'C:\Users\Administrator\AppData\Local\Programs\Python\Python312\python.exe' -m venv <venv>
<venv>\Scripts\python.exe -m pip install rapidocr onnxruntime opencv-python-headless

# 首次运行会联网下模型 —— 本机必须先设镜像，否则卡死
$env:HF_ENDPOINT='https://hf-mirror.com'
```

【实测】首次运行 `model init: 0.69s`（模型已随包/首次下载后走缓存），**CPU EP only**。

### 4.2 速度【实测，8 线程 CPU，无 GPU】

| 输入 | 耗时 | 备注 |
|---|---|---|
| 960px 整帧 | **1.10 – 1.56 s/帧** | 批量测得 1.08 s/帧 |
| 3840×2160 整帧 | **1.89 – 2.48 s/帧** | 检出的文字框 65–67 个 |
| HUD 局部裁剪（左下 45%×30%） | **0.83 – 0.95 s** | **明显更快，检测器负担大减** |
| 中央区域裁剪（找漂浮伤害数字） | 0.93 s | |

**GPU 化没有必要**【推断】：det+rec 模型只有 30 MB，搬到 8GB 显存的收益会被 H2D 拷贝和 cuDNN 初始化吃掉；而且为它单独装 `onnxruntime-gpu`（**wheel 3202 MB**）会挤掉 VLM 的显存预算。**OCR 走 CPU 是正解。**

### 4.3 能不能读出 HUD 上的血量/弹匣/伤害数字？—— **能，而且中文几乎完美**【实测】

对 849 号素材 4K 原帧，识别置信度几乎全为 **1.00**：

**战斗帧（t=654，960px）实际读出：**
```
[1.00] 千机伞-潜锋          ← 武器名
[1.00] 体力回复             ← 正在打药/回体力（战术停顿，VLM 也判成了"非交战"）
[1.00] 06:53                ← 暗域倒计时
[1.00] 25/60                ← 弹匣：打了 35 发
[1.00] 14596 / 5125 / 16287 ← 伤害/分数数字
[1.00] 【万夫莫政·2重】击败（2/5)   ← 击杀播报
[1.00] 真的浩想你呀在附近发现敌人【季沧海】
[1.00] 吃东西饭.标记了[枪] / [双刀]
[1.00] 第3次暗域蔓延中 / 已达至高境界 / 【升华类魂玉】
[1.00] 91% / 替换当前武器
```

**非战斗帧（t=2158.9，960px）实际读出：**
```
[1.00] 60/60                ← 弹匣全满，没开过火
[1.00] 02:29 / 距离第5次暗域蔓延01:05
[0.98] 吃东西饭.准备前往一处地点   ← 纯跑图
[1.00] 经过 / 415m / 40m
（无伤害数字、无击杀播报、无武器名）
```

4K 原帧还能读到：`泥嚎是小锌击败了战神梅时不悔槐韵德`、`[淘汰]梅时不悔槐韵德`、`返魂次数将在30秒后扣除`、`5075/8000`（血量上限式读数）、`【急蓄&伏火】命中（1/6）`（命中计数）。

> **⚠️ 必须屏蔽性能监控 OSD**：OCR 会把 `CPU` / `GPU2` / `D3D11` / `35ms` / `2925Hz 84.3"` 全读出来。项目已有 `E:\OBS` 原始素材大概率带这些叠加层，做规则匹配前要先裁掉或过滤。

### 4.4 OCR 规则分类器实测成绩【实测，49 帧同一真值】

用正则从 OCR 文本里提确定性信号（击杀播报 / 弹匣是否打过火 / 大数字数量）：

| 判据 | acc | 战斗召回 | 空档特异度 |
|---|---|---|---|
| 击杀播报 **或** 弹匣打过火 | 57.1% | 64.0% | 50.0% |
| 仅击杀播报 | 53.1% | 24.0% | 83.3% |
| 仅弹匣打过火 | 57.1% | 56.0% | 58.3% |
| 击杀播报 或 开火 或 大数字≥4 | 57.1% | **92.0%** | 20.8% |

**为什么只有 57%**【推断】：我的"大数字"特征被**罗盘刻度**污染了——HUD 指南针上固定印着 `210 / 240 / 285 / 300 / 330 / 345 / 东北 / 北 / 西南`，全都是 3 位数，所以空档帧也有 7–9 个"大数字"。**只裁中央区域**（避开底部 HUD 和顶部罗盘）就能修掉，这是实现细节，不是模型能力问题。**修完之后 OCR 规则的分数应该显著高于现在的 57%，值得重测。**

---

## 5. 核心实测：能不能替代人工判断"这段有没有战斗"

### 5.1 真值从哪来（这是本项目最大的优势）

【实测】`123\<编号>.<素材名>\timeline\combat_episodes_v*.json` 里已经躺着**人工逐帧裁决过**的战斗/空档标注：

- **9 个任务目录、35 个时间线版本**
- **409 条已标注战斗场次**（`source_start` / `source_end` / `engage_start` / `outcome_time` / `event_types` / `confidence`）
- **423 条已标注空档区间**（每条带中文 `reason` 理由）
- 覆盖 9 个不同源视频

去重后约 90–100 条独立战斗场次 + 180 条空档。**这是一份免费、高质量、带理由的训练/评测集，不用再人工标。**

【实测】⚠️ 但**只剩 849 的源 MP4 还在盘上**（864/862/865/867 等的源文件已清理或移动）。所以：

- **评测**：现在就能用 849 跑（本次全部实测都基于它）
- **训练**：必须先确认哪些源素材还在，否则得重新抽帧

### 5.2 实测成绩总表【全部实测，849 真值，Qwen3-VL GGUF + llama.cpp b11401】

**A. 帧级（49 帧 = 25 战斗 + 24 空档，单图判定）**

| 模型 | 配置 | acc | 战斗召回 | 空档特异度 | 速度 |
|---|---|---|---|---|---|
| Qwen3-VL-**2B** Q4_K_M | ctx8192/imt1024 | **67.3%** | **84.0%** | 50.0% | **0.24–0.33 s/帧（≈4.2 fps）** |
| Qwen3-VL-**4B** Q4_K_M | ctx4096/imt512 | 61.2% | **28.0%** | **95.8%** | 0.45 s/帧（≈2.2 fps） |
| OCR 规则（最佳组合） | CPU | 57.1% | 92.0% | 20.8% | 1.08 s/帧 |

**B. 段级（23 个连续 5 帧窗口 = 12 战斗 + 11 空档，1 fps 抽帧）**

| 模型 | acc | 战斗召回 | 空档特异度 | **平衡准确率** | 速度 |
|---|---|---|---|---|---|
| Qwen3-VL-**2B** Q4_K_M | 52.2% | **100%** | **0.0%** | **50.0%** | 1.33 s/窗口（0.27 s/帧） |
| Qwen3-VL-**4B** Q4_K_M | 69.6% | 58.3% | 81.8% | **70.1%** | 1.59 s/窗口（0.32 s/帧） |

### 5.3 ⚠️ 三个必须知道的实测陷阱

**(1) `llama-server` 默认 `cache_prompt=true` 会给你假速度**【实测】：

| 模式 | `prompt_n` | wall | `prompt_ms` |
|---|---|---|---|
| `cache_prompt=true`（默认） | **1** | **0.07–0.08 s** ← 假的 | 7–13 |
| `cache_prompt=false`（诚实） | 582 | **0.24–0.33 s** | 157–236 |

差 **4 倍**。默认模式只重算了 1 个 token，视觉根本没重新编码。**任何 benchmark 必须显式传 `cache_prompt: false`，否则数字全是假的。**

**(2) 首次请求要 60–90 s**【实测】：加载模型后第一次推理 `60.90 s`（cuBLAS autotune），第二次起降到 0.8 s。**必须先空跑一次预热再计时**，否则首帧数字会把均值彻底带偏。

**(3) 显存余量比想象的危险**【实测】：4B + ctx8192 + imt1024 时峰值 **7768 MiB / 8188 MiB，只剩 420 MiB**。而本机桌面在跑 `GameViewer`（远控录屏）+ `wallpaper64`，空闲就吃 **3707 MiB**（会话开始时只有 1418 MiB，是测试期间涨上来的）。

> **只要开着 GameViewer，8GB 跑 VLM 就随时可能 OOM。做任何部署前先关掉远控/动态壁纸。**

### 5.4 `--image-max-tokens` 是本机显存的真正旋钮【实测，2B】

| 配置 | idle | 峰值 | 余量 |
|---|---|---|---|
| ctx8192 / imt1024 / 1 图 | 7518 | **7798** | 390 |
| ctx4096 / imt512 / 3 图 | 7523 | 7626 | 562 |
| ctx2048 / imt**256** / 4 图 | 4997 | **5121** | **3067** |

**imt 从 1024 降到 256，显存省掉 2.7 GB。** 权重才占 1.5 GB，剩下的全是视觉缓冲区。

⚠️ 但 llama.cpp 会警告：`Qwen-VL models require at minimum 1024 image tokens to function correctly on grounding tasks`，降到 256 **可能损害小字识别**（HUD 数字、伤害数字都是小字）。【推断】imt 512 是"能看清 HUD + 有余量"的折中。

### 5.5 最关键的判断：**帧级分类在这件事上原理上就不成立**

看 2B 的 5 帧窗口成绩：**战斗召回 100%，空档特异度 0%**——它对**每一个**窗口都答"战斗"。

为什么？看它自己的解释和 OCR 的读数就明白了。t=654 那一帧，OCR 读到 `体力回复` + `千机伞-潜锋`，VLM 解释为"玩家正在使用千机伞进行体力回复，而非与敌人交战"。

**它在技术上是对的。** 但那正是项目 §8.1 铁律写明**必须保留**的战术停顿：

> 「中间可能有二三十秒我都是在观察的状态，其实那也算战斗的一部分」
> 「战斗窗口内不许挖洞 —— 战术停顿要**包含进来**，不是挖掉」

所以：**单帧"非交战"≠ 可删除。** 这是标签定义层面的问题，不是模型能力问题。2B 之所以"召回 100%"，是因为它在实际执行 §8.1 的保守策略（宁可全留）；4B 之所以"特异度 96%"，是因为它在执行**错误**的激进策略（会挖掉战斗里的停顿）。

**两个模型的"准确率"都不能直接读。** 必须按项目的实际损失函数看：

> **假阴性（砍掉真战斗）的代价 ≫ 假阳性（留了一段无聊空档）。**
> 按这个不对称重算：
> - **2B**：召回 100% / 特异度 0% → **绝不会砍错，但也不会帮你删任何东西**。作为预筛是"安全但无用"。
> - **4B**：召回 58.3% / 特异度 81.8% → **会砍掉 42% 的真战斗**。按本项目标准这是**不可接受的**。

**这是本次调研最重要的结论：8GB 上现有的 VLM，没有一个能当删除裁决器。**

---

## 6. 问题 3 的正面回答：路径 A（微调）还是路径 B（零样本）？

### 路径 B：零样本 VLM 直接问 —— **实测不可行**

最好成绩 70.1% 平衡准确率（4B + 5 帧窗口）。§8.1 铁律下这个数**不够**，因为它意味着漏掉四成战斗。

而且零样本的失败模式特别恶劣：**不是"不知道"，是"自信地答错"**。它给出流畅的中文理由（"画面中显示了角色在战斗中使用技能、攻击、闪避和击倒"）去支撑一个错误答案。人 review 时反而更累——要去核实它编的理由。

### 路径 A：微调 —— **数据已经现成，但今天不建议做**

**数据**【实测】：409 条战斗场次 + 423 条空档区间，人工裁决、带 `engage_start`/`outcome_time`/`event_types`/`confidence`/`boundary_reason`。**这个量级对二分类已经够了**（§5.1 有详细统计）。

**但有三个真实障碍**：

1. **源素材只剩 1/9 在盘上**【实测】。只有 849 的 `E:\PR导出\849*.mp4` 还在。要训练得先解决素材留存，或者接受只用 1 局 2399 s 的数据（13 场战斗）——**那会过拟合到这一局的打法**。
2. **没有 torch**【实测】。装 `torch 2.14.1` + `transformers 5.18.0`，win+cu12 wheel 约 2.5–3 GB，且要重新解决 `HF_ENDPOINT`。这是一条独立的、目前**零基础**的链路。
3. **更便宜的路先存在**：见 §6.3。

### 6.3 推荐的中间路线：OCR 特征 + 传统分类器（不是神经网络）

**这是本次调研认为性价比最高的方案**【推断，基于 §4.3/§4.4 实测】：

理由：OCR 已经能把战斗的**确定性痕迹**读成字符串——弹匣 `25/60` vs `60/60`、击杀播报 `[淘汰]xxx`、命中计数 `命中（1/6）`、武器名、伤害数字、`体力回复` 这类状态词。这些是**可枚举的字符串特征**，不是模糊判断。

现有 venv 里**已经有 `scikit-learn 1.9.0`**【实测】，不需要 torch、不需要 GPU、不需要额外 3 GB 依赖。

工作流：
```
ffmpeg 1fps 抽帧（只抽 4K，一次性）
  → RapidOCR 裁剪区识别（~1.1 s/帧，纯 CPU，可并行）
  → 提特征：弹匣剩余比 / 有无击杀播报 / 伤害数字计数 /
            武器名 / 状态词 / 罗盘与准星相对位移
  → 段级聚合（滑动窗口多数表决 + 滞回阈值）
  → 产出"候选战斗段"给审片，不产出"删除建议"
```

**它天然满足 §8.1**：只会说"这里值得看"，不会说"这里可以删"。删除裁决仍然留给人。

⚠️ **前置修复**：必须先裁掉罗盘和性能 OSD（§4.4 已定位到大数字特征被 `210/240/285/330/345` 污染），否则分类器学到的是假特征。

---

## 7. 部署形态与可复现命令

### 7.1 安装（照抄可跑）

```powershell
# ---- 1) llama.cpp：两个 zip 都必须下，少一个 CUDA 就静默失效 ----
$rel = 'https://github.com/ggml-org/llama.cpp/releases/download/b11401'
#   注意：github.com 被阻断，必须走 ghfast.top；ghproxy.net 不支持续传，别用
curl.exe -L -o llama.zip      "https://ghfast.top/$rel/llama-b11401-bin-win-cuda-13.4-x64.zip"      # 146 MB
curl.exe -L -o cudart.zip     "https://ghfast.top/$rel/cudart-llama-bin-win-cuda-13.4-x64.zip"     # 404 MB ← 关键
Expand-Archive llama.zip  -DestinationPath .\llama -Force
Expand-Archive cudart.zip -DestinationPath .\llama -Force   # 覆盖进去

# ---- 2) 模型（huggingface.co 被阻断，必须走 hf-mirror）----
$hf = 'https://hf-mirror.com/Qwen/Qwen3-VL-4B-Instruct-GGUF/resolve/main'
curl.exe -L -o models\Qwen3VL-4B-Instruct-Q4_K_M.gguf       "$hf/Qwen3VL-4B-Instruct-Q4_K_M.gguf"        # 2382 MB
curl.exe -L -o models\mmproj-Qwen3VL-4B-Instruct-Q8_0.gguf "$hf/mmproj-Qwen3VL-4B-Instruct-Q8_0.gguf"   #  433 MB

# ---- 3) 起服务（推荐参数）----
.\llama\llama-server.exe `
  -m models\Qwen3VL-4B-Instruct-Q4_K_M.gguf `
  --mmproj models\mmproj-Qwen3VL-4B-Instruct-Q8_0.gguf `
  -ngl 99 -c 4096 --image-max-tokens 512 -np 1 -fa on `
  --host 127.0.0.1 --port 18081
```

> ⚠️ **下载必须带 `-C -` 和重试**。实测 `hf-mirror` 在 1 GB 文件上会 `Connection was reset`（本次 858 MB 处断过一次），`curl -C -` 续传解决。

### 7.2 调用（务必关 prompt cache，否则测出来的是假速度）

```python
body = {
  "messages": [{"role": "user", "content":
      [{"type":"image_url","image_url":{"url":"data:image/jpeg;base64,..."}} for _ in imgs] +
      [{"type":"text","text": PROMPT}]}],
  "max_tokens": 8, "temperature": 0,
  "cache_prompt": False          # ← 必须。否则 prompt_n=1，速度虚高 4 倍
}
POST http://127.0.0.1:18081/v1/chat/completions
```

实测提示词（5 帧窗口专用，把 §8.1 的"停顿仍算战斗"直接写进 prompt 里）：

```
这5张图是《永劫无间》同一段视频按时间顺序的连续抽帧（每秒1帧，覆盖约5秒）。
请判断这5秒内玩家是否参与了战斗（与敌人交手、攻击或被攻击、闪避、击倒、
看到敌人或伤害数字）。注意：战斗过程中可能夹杂短暂的停手、舔包、打药，
那仍属于战斗。只回答一个词：'战斗' 或 '非战斗'。
```

### 7.3 验证安装是否成功（两个静默失败点）

```powershell
# 失败点 1：CUDA 没加载 → 会静默退回 CPU，然后 buffer 分配失败
.\llama\llama-bench.exe -m models\Qwen3VL-4B-Instruct-Q4_K_M.gguf -p 16 -n 8 -ngl 99
#   ✅ 要看到：ggml_cuda_init: found 1 CUDA devices (Total VRAM: 8187 MiB)
#              load_backend: loaded CUDA backend
#              backend 列应为 CUDA（不是 CPU）
# ❌ 失败症状（本次都撞过）：
#      "load_backend: loaded CPU backend" 而没有 CUDA 行  → 缺 cudart zip
#      "failed to allocate CPU buffer of size 667707392"     → 退回 CPU 了

# 失败点 2：VRAM 被桌面吃光 → 服务起不来
nvidia-smi --query-gpu=memory.used --format=csv,noheader
#   实测：桌面空闲 1418 MiB；开着 GameViewer + 动态壁纸会涨到 3707–4194 MiB
#   → 跑 VLM 前先关远控录屏和动态壁纸
```

---

## 8. 一句话回答原始五个问题

1. **8GB 可用 VLM**：Qwen3-VL-4B（2.82 GB GGUF）✅ 最优；Qwen3-VL-2B（1.48 GB）✅ 更快但判断力反向偏置；Qwen2.5-VL-3B（2.65 GB）【推断】可跑；SmolVLM2-2.2B / MiniCPM-V-4.5 / InternVL3-1B ❌ 或不划算。**注意显存被视觉缓冲区主导**，`--image-max-tokens` 才是旋钮。
2. **3B 以下视频专用模型**：**不存在**【实测】。TimeChat / VideoChat / InternVideo / LLaVA-Video 全部 ≥4B、实际可用尺寸 7B+。走 Qwen3-VL 多图交错即可，**但别用 `--video`（6.3 s/帧），用 ffmpeg 抽帧 + HTTP 多图（0.32 s/帧，快 20 倍）**。
3. **二分类器**：**零样本不可行**（最好 70.1% 平衡准确率，4B 会漏掉 42% 真战斗，违反 §8.1）。微调数据现成（409 场次 + 423 空档），但源素材只剩 1/9 在盘、且要新建 torch 链路。**推荐中间路线：OCR 特征 + sklearn**——现有 venv 已有 `scikit-learn 1.9.0`，零 GPU 依赖。
4. **OCR**：**该装，优先级高于 VLM**。RapidOCR 3.9.2（PP-OCRv6 small）**共 30 MB**，纯 CPU，960px **1.08 s/帧**，中文置信度 **1.00**，能读弹匣 `25/60`、暗域计时 `06:53`、击杀播报 `[淘汰]xxx`、命中计数 `命中（1/6）`、武器名、伤害数字。**8GB 显存对它完全无压力，也不需要 `onnxruntime-gpu`（那个 wheel 3.2 GB，不值）。** 记得屏蔽性能 OSD 和罗盘刻度。
5. **最小可行实测**：已做，49 帧 + 23 个 5 帧窗口 + OCR 规则 + 显存扫描，全部数字见 §4–§5。真值用 849 的 `combat_episodes_v8.json`，素材为 4K60。

---

## 9. 给上层的建议（按性价比排序）

| 优先级 | 动作 | 成本 | 收益 |
|---|---|---|---|
| **P0** | **别装 VLM。** 先把现有 `combat_episodes_v*.json` 的 832 条人工标注整理成评测集 | 纯文本，0 安装 | 这是唯一能证明"能不能替代人工"的尺子。现在没有这把尺子，任何模型都是自说自话 |
| **P0** | **确认源素材留存策略** | 0 | 35 个时间线版本里只剩 1 个源文件在盘。**标注在涨，素材在丢**，再拖下去连训练集都建不起来 |
| **P1** | 装 OCR（30 MB，CPU），**先只做 HUD 区域裁剪** | 隔离 venv + 30 MB | 确定性信号：`25/60` vs `60/60`、`[淘汰]`、`命中（n/6)`。比 VLM 可审计得多 |
| **P1** | OCR 特征 + `sklearn` 段级分类器（滑窗 + 滞回） | 0 新依赖 | 已有 `scikit-learn 1.9.0`。**只产出"候选段"，绝不产出"删除建议"** |
| **P2** | 若 P1 特征不够，再上 Qwen3-VL-4B，**且只用它做召回预筛** | 2.82 GB + 553 MB llama.cpp | 补 OCR 读不出的语义（站位、意图、敌我关系）。**必须显式按 §8.1 调高召回，忽略特异度** |
| **❌ 不做** | 视频专用模型（TimeChat/VideoChat/InternVideo） | — | 全部 ≥7B，8GB 装不下或没有量化版 |
| **❌ 不做** | torch + transformers 全链路 | 3 GB | OCR+sklearn 路线零 GPU 依赖就能覆盖大部分需求，先证明它不够再说 |

**最后提醒 §8.1 的那条硬约束**（本次实测最深的一课）：

> 2B 模型"战斗召回 100%、特异度 0%"看起来像个坏结果，但它其实是**唯一符合项目铁律的行为**——
> 它从不告诉你"这里可以删"。**任何在 8GB 上能找到的 VLM，天然都是"宁可全留"的保守器，而不是裁决器。**
> 视觉模型在这个项目里的正确角色是**扩大召回**（别漏掉战斗），**不是替代判断**（该不该删）。
> `qa_gate.py` 全绿之后仍然必须看片 —— 这条现在同样适用于 VLM。

---

## 附录 A：本次落盘的可复现产物

| 路径 | 内容 |
|---|---|
| `%TEMP%\opencode\vlmtest\models\` | Qwen3-VL 2B/4B GGUF + mmproj（1.48 GB + 2.82 GB） |
| `%TEMP%\opencode\vlmtest\llama\` | llama.cpp b11401 + CUDA 13.4 runtime |
| `%TEMP%\opencode\vlmtest\frames\` | 49 张 960px 测试帧（25 战斗 / 24 空档）+ 2 张 4K 原帧 |
| `%TEMP%\opencode\vlmtest\win\` | 23 个连续 5 帧窗口（12 战斗 / 11 空档） |
| `%TEMP%\opencode\vlmtest\gt849.json` | 849 真值（源路径 + 13 战斗场次 + 12 空档） |
| `%TEMP%\opencode\vlmtest\ocr_result.txt` | OCR 逐框原文 + 置信度（UTF-8） |
| `%TEMP%\opencode\vlmtest\ocr_rules.txt` | 49 帧 OCR 特征 + 判定（JSONL） |
| `%TEMP%\opencode\vlmtest\win_acc.txt` | 5 帧窗口逐条判定 + 汇总 |
| `%TEMP%\opencode\vlmtest\acc.txt` / `acc3.txt` | 帧级 / 3 帧组 逐条判定 + 汇总 |
| `%TEMP%\opencode\vlmtest\vram.txt` | 显存扫描（ctx × imt × 图数） |
| `%TEMP%\opencode\vlmtest\timing.txt` | cache_prompt 真假速度对比 |
| `%TEMP%\opencode\ocrtest\` | 隔离 OCR venv（rapidocr 3.9.2） |

## 附录 B：引用的外部来源

- llama.cpp release `b11401`（2026-10-05，`version 0.5.0-dev build 11401`），资产清单经 GitHub API 实查
- `Qwen/Qwen3-VL-2B-Instruct-GGUF`、`Qwen/Qwen3-VL-4B-Instruct-GGUF` — 文件体积经 HF API `tree/main` 实查
- `Qwen/Qwen2.5-VL-3B-Instruct-GGUF`、`OpenGVLab/InternVL3-1B-hf`、`HuggingFaceTB/SmolVLM2-2.2B-Instruct`、`vikhyatk/moondream2`、`openbmb/MiniCPM-V-4_5` — 同上
- 视频模型下载量：`yaolily/TimeChat-Captioner-GRPO-7B`、`wyccccc/TimeChatOnline-7B`、`ShuhuaiRen/TimeChat-7b`、`MCG-NJU/VideoChat3-4B`、`OpenGVLab/VideoChat-Flash-Qwen2-7B_res448`、`OpenGVLab/InternVideo2_5_Chat_8B`、`yanziang/InternVideo3-8B-Instruct`、`llava-hf/LLaVA-NeXT-Video-7B-hf`、`lmms-lab/LLaVA-Video-7B-Qwen2` — 均经 HF API 实查
- PyPI 元数据：`rapidocr 3.9.2`（wheel 26 MB）、`onnxruntime-gpu 1.30.0`（wheel 3202 MB）、`torch 2.14.1`、`transformers 5.18.0` — 经 `pypi.org/pypi/<pkg>/json` 实查
- 项目内部真值：`C:\Project\永劫无间\123\*\timeline\combat_episodes_v*.json`（35 个版本）
- 网络可达性：`curl -sI` 对 9 个域名逐一实测
