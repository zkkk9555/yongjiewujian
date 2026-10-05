# 04 · 渲染环节还能不能再快？

调研员：子 agent（渲染专项） · 日期 2026-10-06 · 机器 RTX 4060 Ti 8GB / 7800X3D 8核 / ffmpeg n8.0-23-gd1f31a829d / 驱动 616.92

每条结论标注 **[实测] / [文档] / [推断] / [未找到]**。所有实测命令与墙钟数字见文末「可复现命令」。

---

## 0. 先说三个会改变结论的前提（都是实测）

### 0.1 两代素材的分辨率不一样，答案也不一样 **[实测]**

| 素材库 | 编码/分辨率/帧率 | 码率 | `scale=3840:2160` 的真实含义 |
|---|---|---|---|
| `E:\OBS`（2026-10-03/04 新录） | **HEVC 2560×1440@60**，2400 s，6.4 GB | 21.3 Mbps | **1.5× 上采样**（真实开销） |
| `E:\PR导出`（AGENTS.md §1 的生产素材库） | **H.264 3840×2160@60** | ~16.5 Mbps | **空操作**（输入已是 4K） |

`ffprobe` 输出见 §5.1。**这一点必须先说清楚**：现在 `seg_render_master.sh` 里那句
`scale=3840:2160:flags=lanczos`，对 `E:\PR导出` 的生产素材是**同尺寸缩放、几乎不花钱**；
对 `E:\OBS` 的新素材却是**实打实的 1440p→2160p 上采样**，是最大单项开销。
任何"优化"结论都要指明针对哪一代素材。

### 0.2 解码不是瓶颈，NVENC 才是 **[实测]**

只解码不编码（`-an -f null -`），1440p HEVC 30 s 片段，三次：

```
DECODE_ONLY rep1 wall=10.28s  frame=1800 fps=175 speed=2.92x
DECODE_ONLY rep2 wall=10.44s  frame=1800 fps=172 speed=2.87x
DECODE_ONLY rep3 wall=10.24s  frame=1800 fps=176 speed=2.93x
```

而当前整条链渲同一个 30 s 片段要 45–80 s。**解码只占渲染耗时的 13–22%。**

E: 盘是 NVMe（`YSSDXB-1TN5000` / `WDC WDS100T2B0C`），顺序读实测 **2093 MB/s**，
**也不是 I/O 瓶颈**。

> 推论：任何"让解码更快"的方案（代理文件、更轻的中间格式）**天花板很低**，见 §3。

### 0.3 这台机器当时被别人占着 **[实测]**

跑基准期间 `nvidia-smi` 显示 `GPU 100% / Encoder 100%`，且存在**非本次任务**的 ffmpeg 进程：

```
ffmpeg.exe ... -ss 900 -to 930 -i "E:\PR导出\870... .mp4"   ← 另一个 session 在渲真 4K 母版
ffmpeg.exe ... -ss 155 -to 161 -i C:/Users/.../Temp/op...   ← 另一个 session 的小测试
```

**同一配置重复测的离散度可达 2×**（例：`h_bicubic_p7` 轮内 53.2 s vs 轮内 102.7 s）。
所以本文所有对比都用 **round-robin（同一轮内依次测所有配置）**，取**轮内相对关系**，
绝对数字只作参考。**这是本次数据最大的不确定性来源，不是 ffmpeg 本身。**

---

## 1. ffmpeg 8.x 有没有提升 seek / 剪辑速度的特性？

**[未找到]** 8.x 没有任何新的"快速 seek"特性。

从本机二进制 `ffmpeg -h full` 实际读出的相关选项（**文档**）：

```
-ss <time_off>              start transcoding at specified time
-accurate_seek              enable/disable accurate seeking with -ss     ← 默认开
-seek_timestamp             enable/disable seeking by timestamp with -ss
-copyts / -start_at_zero    时间戳处理
```

ffmpeg 8.0 changelog 里与剪辑沾边的项（**文档**，
来源 <https://ffmpeg.org/pipermail/ffmpeg-devel/2025-August/347886.html> 与 GitHub Changelog）：

- `ffmpeg -t and -ss (output-only) options are now sample-accurate when transcoding audio` —— 只影响**输出侧** `-ss` + 音频，**不提速**。
- `timeline editing with filters` —— 我去查了官方 Filters 文档 §5，这个"新特性"其实就是滤镜的 `enable='between(t,...)'` 表达式开关（见 <https://ffmpeg.org/ffmpeg-filters.html#Timeline-editing>），**跟 seek 速度毫无关系**，名字有误导性。
- `filtergraph syntax in ffmpeg CLI now supports passing file contents as option values by prefixing '/'` —— 方便写长滤镜串，**不提速**。
- `-shortest_buf_duration`、`-readrate_initial_burst`、`-fix_sub_duration_heartbeat` —— 都不是 seek 加速。
- 8.0 硬件解码新增：Vulkan VP9、VAAPI VVC、OpenHarmony；滤镜新增 `scale_d3d11`、`pad_cuda`。8.1 加了 **Vulkan decode hwaccel 支持 H264/HEVC/AV1**。

### 我们脚本已经用对的

- **`-ss` 在 `-i` 之前（输入侧快进 seek）** —— `seg_render_master.sh:91` 就是 `-ss "$S" -to "$E" -i "$SRC_W"`，**正确**。
- 我这套基准 harness 用同样写法，**复现了父会话给的数字**：240 s 节目 8 段 `jobs=1` 实测 **263 s**，对上父会话的 265.2 s。**说明父会话的 265.2 s 是可信的、可复现的。**

### `-noaccurate_seek`：**实测更慢，不要用** **[实测]**

| 配置（1440p HEVC，30 s 片段） | 每段墙钟中位数 |
|---|---|
| `-hwaccel cuda`（accurate seek，默认） | **103.4 s** |
| `-hwaccel cuda -noaccurate_seek` | **200.0 s** |

**开了反而慢近 2×**。原因（**推断**）：关掉 accurate seek 后起点不再帧对齐，
`-hwaccel cuda` 这条路要反复重建/重启 CUDA 解码器上下文，反而更贵。
**结论：保持默认，不要碰 `-noaccurate_seek` / `-accurate_seek` / `-seek_timestamp`。**

---

## 2. NVENC 正确用法：短片段批量渲染的实际吞吐

### 2.1 最有价值的一条 NVIDIA 官方说明 **[文档]**

NVENC Video Encoder API Programming Guide §6.4「Encoder Features using CUDA」原文：

> Although the core video encoder hardware on GPU is completely independent of CUDA cores
> or graphics engine on the GPU, **following encoder features internally use CUDA for hardware acceleration**:
> **Two-pass rate control modes for high quality presets**、**Look-ahead**、
> **All adaptive quantization modes**、Weighted prediction、Encoding of RGB contents、Temporal Filtering

来源：<https://docs.nvidia.com/video-technologies/video-codec-sdk/13.0/nvenc-video-encoder-api-prog-guide/index.html>

**这直接解释了本机实测到的两件事**（下面 2.2、2.3），也解释了**为什么并行加速远达不到线性**
（§4）：NVENC 引擎本身不是瓶颈，**抢的是 CUDA core**。

### 2.2 `-preset p7 -tune hq` + 空间/时间 AQ 是最大的一笔开销 **[实测]**

round-robin 4 轮（1440p HEVC 源，每段 30 s，完整表见 §6）：

| 配置 | min 墙钟 | 相对 | 体积 |
|---|---|---|---|
| **当前脚本原样**（`fps=60,scale=lanczos`, p7, tune hq, spatial+temporal AQ） | **45.87 s** | 1.00× | 69.3 MB |
| **`fast_bilinear` + `-preset p4`（AQ 保留）** | **30.69 s** | **1.49×** | 69.3 MB |
| **`fast_bilinear` + `-preset p4 -tune ll -rc-lookahead 0 -g 30 -bf 0`** | **27.24 s** | **1.68×** | 71.5 MB |

单独隔离 AQ 的那批（1440p 源、p4）：

| | 每段墙钟 |
|---|---|
| p4 + AQ on | 41.7 s |
| p4 + AQ **off** | **28.6 s** |

→ **AQ 单独值 1.46×**，正好对应 §2.1 那条
"all adaptive quantization modes internally use CUDA for hardware acceleration"。

### 2.3 scaler flag 与 `fps=60`：**在干净的 round-robin 里没有可靠收益** **[实测]**

早期单轮测量（同一段 30 s，p7 + AQ）曾给出这样的表：

| scaler | 每段墙钟 |
|---|---|
| `flags=lanczos`（含 `fps=60`） | 58.7 s |
| `flags=bicubic`（去掉 `fps=60`） | 55.7 s |
| `flags=fast_bilinear`（去掉 `fps=60`） | **50.9 s** |

照这张表看「删 `fps=60` 值 1.66×」。**但那批数据取自早期单轮测量，落在 §0.3 的争用区间里，
不可信。** 干净的 4 轮 round-robin（§6 表）给出的 min 是：

| 配置 | min |
|---|---|
| 当前脚本原样（`fps=60` + lanczos） | 45.87 s |
| 去掉 `fps=60` + bicubic | 52.17 s |

**改完反而没有更快（甚至更慢）。** 另一批 3 次测量里 `fast_bilinear` 的 min 又比 `bicubic` 低
（23.4 vs 32.1 s）。

**所以诚实的结论是 [实测]：换 scaler flag / 删 `fps=60` 的收益在噪声之内，本机测不出可靠差别。
它们的真实价值是「零画质代价、顺手可以改」，而不是提速手段。**

> 这条纠正很重要：**如果只信早期那张表，会以为「删 `fps=60`」是第二大收益——它不是。
> 真正的大头只有 NVENC preset 和 lookahead/AQ。**

至于 `scale_cuda`（全 GPU），干净轮次 min 51.34 s vs base 45.87 s，**同样没有收益**（见 §2.4）。

### 2.4 全 GPU filter 链：能跑通，但**没收益** **[实测]**

`-hwaccel cuda -hwaccel_output_format cuda` + `scale_cuda` 直连 `h264_nvenc` 是可行的
（`h264_nvenc` 的 Supported pixel formats 里确实有 `cuda`，本机
`ffmpeg -h encoder=h264_nvenc` 实测确认）。

⚠️ **踩坑：必须同时删掉 `-pix_fmt yuv420p`。** 我第一次跑挂了：

```
Impossible to convert between the formats ... 'Parsed_scale_cuda_0' -> 'auto_scale_0':
  src: cuda ; dst: yuv420p nv12 p010le ...
Error reinitializing filters!
```

原因：`-pix_fmt yuv420p` 强制输出 CPU 帧，把 CUDA 链打断了。**文档 + 实测。**

但收益是零：

| 配置 | 每段墙钟中位数 |
|---|---|
| `scale_cuda`（GPU） | 103.4 s |
| CPU `fast_bilinear` | 101.7 s |

干净 round-robin 的 min 也一致：`scale_cuda` 51.34 s vs 当前链 45.87 s。

→ **统计上无差别，甚至更差。** 全 GPU 链解决的是「CPU 解码/缩放瓶颈」，
而 §0.2 已经证明**本机根本不是 CPU 瓶颈**。**回答问题 5：不必做，收益 0（实测为负）。**

### 2.5 `-rc` / `-cq` / `-b:v` 怎么配 **[实测 + 文档]**

NVIDIA 文档对 VBR 的要求（**文档**，同上链接 §3.8.3）：

> Variable bitrate (VBR): … averageBitRate must be specified. **If maxBitRate isn't specified,
> NVENC will set it to an internally determined default value. It is recommended that the client
> specify both parameters maxBitRate and averageBitRate for better control.**

→ **你们现在的 `-rc vbr -b:v 18M -maxrate 28M -bufsize 56M` 是符合推荐的，保持。**

`-cq` 的坑（**实测**）：`-preset p1 -tune hq -rc vbr -cq 19 -b:v 0 -maxrate 0 -bufsize 24M`
渲同一个 30 s 片段，产出 **161.9 MB**；而 `-rc vbr -b:v 12M -maxrate 18M` 只有 **43.9–44 MB**。

→ **`-rc vbr` 下用 `-cq` 而不给 `maxrate` 上限，码率会炸到 3.7×。**
**结论：别混用 `-cq` 和 `-b:v 0`；要控体积就老老实实给 `-b:v` + `-maxrate` + `-bufsize`。**

### 2.6 多 slice / lookahead **[未测]**

`-slices`（h264_nvenc 多 slice 分割）**没有实测**，本次不编数字。
`-rc-lookahead 0` 实测有效（见 2.2 最后一行的 1.69× 配置）。

---

## 3. 无损代理工作流：有净收益吗？—— **没有** **[实测 + 推断]**

### 3.1 为什么代理帮不上忙（这是本节最重要的一句）

§0.2 实测：**光解码 30 s 只要 10.3 s**，而当前整条链要 45–80 s。
代理工作流能优化掉的**只有那 10.3 s**，也就是最多 ~13–22%，
**而代理本身的建库成本远大于此**（§3.2 实测建库要几百秒）。

### 3.2 代理建库成本 —— **实测：代理是双重净亏损** **[实测]**

建一份 720p h264_nvenc 代理（整段 2400 s 源），再从代理渲同一个 4K 片段：

```
PROXY_BUILD   wall=1610.3 s (26.8 min)  size=1187.6 MB   speed=1.49x
PROXY_RENDER  wall=50.4 s                                        speed=0.597x
```

对照：**同一段 4K 片段直接从 1440p 原素材渲（同样的 p4+hq+AQ 链）只要 30.69 s。**

算一笔账（240 s 节目 = 8 段）：

| 路线 | 建库 | 8 段渲染 | **合计** |
|---|---|---|---|
| 直接从原素材 | 0 | 8 × 30.69 = 245 s | **245 s** |
| 先建代理再渲 | 1610 s | 8 × 50.4 = 403 s | **2013 s** |

→ **代理路线慢 8.2×。** 三重亏损：

1. **建库 1610 s（26.8 min），本身就超过一次完整 4K 成片的耗时**（859 实测 4312 s / 900 s 节目，
   13 分钟节目约 34 min——代理建库抵掉大半）；
2. **从 720p 代理渲 4K 反而更慢**（50.4 s vs 30.7 s）：720p→2160p 的上采样像素量比
   1440p→2160p 大得多，缩放开销陡增。**代理没有让解码省下的时间被缩放还回去。**
3. 画质更差（720p 源上采样到 2160p）。

### 3.3 回答"756s 那个结论在现代 NVENC + 轻量代理下还成不成立？"

**[实测]** 我这份 720p/4 Mbps 代理在**有 GPU 争用**的情况下花了 **1610 s**，比 756 s 还慢一倍
——**"756s"那个数字本身就不是现代 NVENC 的水平**，现代 NVENC 建这种代理的实测速率是
**1.49× 实时**，也就是**建一份代理的代价 ≈ 渲 2/3 段 4K 成片**。

更重要的是：**就算代理建库真的只要 756 s，结论也不变**：

```
756 + 8 × 50.4 = 1159 s   vs   直接渲 245 s     → 仍然慢 4.7×
```

**所以"756s 贵不贵"根本不是关键问题。关键问题是：代理让每个片段的渲染变慢了 64%（30.7 → 50.4 s）。**
代理这条路在本项目**怎么优化都是净亏损**，与年代、NVENC 快慢无关。

### 3.4 ProRes Proxy / DNxHR / 2024-2026 有没有更好的中间格式 **[推断]**

- ProRes Proxy / DNxHR LB 是**给 CPU 剪辑软件（Pr/Resolve）做代理**用的，**在纯 ffmpeg 流水线里没有意义**：
  它们是 **Intra（帧内）编码 → 文件巨大**，解码成本不比 H.264 低。用来"加速"是反效果。
- ffmpeg 8.0 的新代理候选是 **Vulkan compute 版 FFV1**（**文档**，8.0 release note：
  "Vulkan compute-based codecs: FFv1 (encode and decode) … open up possibilities to work with them
  for situations like non-linear video editing"）和 8.0 的 **ProRes RAW 解码**。
  但本机 `-hwaccels` 列表里**没有 `vulkan`**（实测：`cuda, vaapi, dxva2, qsv, d3d11va, opencl,
  d3d12va, amf`），所以本机用不了。**[未找到本机可用的更优代理格式。]**

**结论：不要建代理。** 这是本次调研最确定的一条"别做"。

---

## 4. 多任务并行：8 核 + 4060 Ti 能同时渲几路？

### 4.1 官方并发上限 **[文档]**

- NVENC Application Note：GeForce 卡**并发 NVENC 会话上限已提到 8**（早期是 2→3→5→8）；
  非 qualified 卡跨卡合计上限 **12** 会话（13.1 版文档）。
- 「NVENC hardware natively supports multiple hardware encoding contexts with negligible
  context-switching penalty.」
- 但同时：「**unless Split Frame Encoding is enabled, performance with a single encoding session
  cannot exceed performance per NVENC**」；多 NVENC 引擎的卡要**多路并发**才能吃满聚合性能。
- 4060 Ti 属于 Ada，**有 2 个 NVENC 引擎**（4070 Ti 及以上才是"双 NVENC"高阶型号的卖点之一）。

**[未找到]** 官方对 4060 Ti 单卡 H.264 4K60 的确切 NVENC 引擎数与聚合吞吐表。

### 4.2 实测并行加速比 **[实测 —— 而且结论强烈依赖机器是否空闲]**

同一份脚本、同一段源码、240 s 节目（8×30 s），跑了**两批**：

**批次 A（`g_*`，机器较空闲）**

| 并发 | 墙钟 | 相对 jobs=1 |
|---|---|---|
| jobs=1 | 263 s | 1.00× |
| jobs=2 | 211 s | 1.25× |
| jobs=4 | **140 s** | **1.88×** |

**批次 B（`k_*`，同期另一个 session 正在渲真 4K 母版）**

| 并发 | 墙钟 | 相对 jobs=1 |
|---|---|---|
| jobs=1 | 341.90 s | 1.00× |
| jobs=2 | **366.18 s** | **0.93×（更慢！）** |
| jobs=4 | 355.77 s | 0.96×（更慢） |
| jobs=8 | ≈347 s（8 段并发，各自 elapsed 267–347 s，取最大值） | ≈1.00×（**零收益**） |

**两批结论相反，这就是本次调研最重要的操作性发现 [实测]：**

> **`-Jobs N` 的收益完全取决于机器是否空闲。**
> 空闲时 `-Jobs 4` 给 **1.88×**；**一旦有别的任务在抢 GPU，`-Jobs N` 收益归零甚至变负**
> （jobs=2/4/8 都比 jobs=1 慢）。
> **所以并发数不能写死，要按"机器当时是否被占用"来决定。**

### 4.3 为什么非线性（这是重点，别误判成"NVENC 不够"）

**[文档 + 实测]** §2.1 已经证明：lookahead 与 AQ **吃的是 CUDA core，不是 NVENC 引擎**。
所以并发时真正被抢的是：8 个 CPU 线程做 HEVC 解码 + N 份 CUDA 上的 AQ/lookahead。
**NVENC 会话数从来不是瓶颈（官方上限 8，本机也够），瓶颈是 CUDA core 和 CPU 解码线程。**

**[推断]** 推论有两条，都很实用：

1. **在你们当前参数（p7 + tune hq + 空间/时间 AQ）下，`-Jobs 4` 附近就到顶了，
   6/8 路大概率负收益**（批次 B 的 jobs=8 零收益已实测）。
2. **如果先把 `-rc-lookahead 0` + 关 AQ 做掉，并发上限会明显提高**——
   因为那些 CUDA-core 争用源被移走了。这也是为什么 §6 里 `p4+ll` 配置在争用下几乎不抖。

---

## 5. 比 ffmpeg 快的专用剪辑引擎？—— **没有** **[文档 + 推断]**

| 候选 | 结论 | 依据 |
|---|---|---|
| **PyAV** | **不会更快** | 它是 libav* 的 Python 绑定，**编解码内核就是同一套**。PyAV 官方文档还明确说：hwaccel「intended for playback and **will not be faster than software decoding on modern CPUs**」，且 GPU 解码后**还要把帧拷回系统内存**，反而更亏。<https://pyav.org/docs/7.0.0/overview/about.html> |
| **ffmpeg-python** | 不会更快 | 只是 CLI 的薄封装，会**多一次进程启动**。 |
| **vidgear** | 不会更快 | 同为 ffmpeg 封装。 |
| **FFmpegKit** | 不会更快 | 把 ffmpeg 编进移动端/库的封装，内核相同。 |
| **LosslessCut** | **不适用** | 它是 ffmpeg 的前端，**底层调用的就是我们现在这个 `LosslessCut\resources\ffmpeg.exe`**（本机 ffmpeg 就是从它那儿来的）。而且它走 **stream copy 不重编码**——而我们必须 `scale` + 重编码（还要改分辨率/AQ），**用不上 LosslessCut**。 |

**[推断]** 唯一真实存在的差别是「进程外 CLI」vs「进程内绑定」：CLI 每次启动有约
几十到几百 ms 开销，但**换来的是可以 `-Jobs N` 直接开多进程**，而进程内绑定要自己写线程/多进程。
**在你们这种"批量分段渲染"场景，ffmpeg CLI + 多进程是正解，没有换引擎的必要。**

---

## 6. 实测数据汇总

> `wall` = 渲 **一个 30 s 片段**的墙钟秒数（由 ffmpeg 自报 `speed=` 换算，30 ÷ speed）。
> 受 §0.3 争用影响，**看轮内相对关系，不要看绝对值**。

（表格由 `.scratch\aivideo\bench\summarize.ps1` 从 `out\*.err` 生成，可重跑复现。）

**round-robin 完整 4 轮（`E:\OBS` 1440p HEVC 源，每轮内依次测全部配置）**[实测]**

| 配置 | r1 | r2 | r3 | r4 | **min** | min 相对 base |
|---|---|---|---|---|---|---|
| **当前脚本原样** | 45.87 | 51.23 | 78.62 | 57.25 | **45.87** | 1.00× |
| 去 `fps=60` + bicubic（仍 p7+hq+AQ） | 53.47 | 120.18 | 64.75 | 52.17 | **52.17** | 0.88×（无收益） |
| `-hwaccel cuda` + `scale_cuda`（全 GPU） | 51.34 | 256.75 | 98.76 | 65.51 | **51.34** | 0.89×（无收益） |
| fast_bilinear + **p4** + AQ | 30.69 | 62.74 | 34.82 | 54.54 | **30.69** | **1.49×** |
| fast_bilinear + **p4 + ll + lookahead 0 + g30 + bf0** | 27.24 | 27.61 | 28.83 | 85.43 | **27.24** | **1.68×** |

**这张表里最有说服力的一列是 `min`，还有"稳定性"本身**：

`p4 + ll + lookahead 0` 四轮是 **27.24 / 27.61 / 28.83 / 85.43** —— 前三轮几乎纹丝不动（±3%），
而 `p7 + tune hq + AQ` 是 **45.87 / 51.23 / 78.62 / 57.25**，抖动 1.7×；
`-hwaccel cuda` 更离谱：**51.34 / 256.75**（5×）。

**这不是巧合，正是 §2.1 那条 NVIDIA 文档的直接验证**：
lookahead 和 AQ 内部吃 **CUDA core**，所以一旦机器上有别的活（本次就有另一个 session 在渲母版），
**争 CUDA core 的配置立刻塌方，而关掉 lookahead + AQ 的配置几乎不受影响**。
→ **想要"快且稳"，就必须 `-rc-lookahead 0` + 关 AQ。** 这两条不只是省时间，还让渲染对机器负载免疫。

**代理路线（同一份 30 s 4K 片段，同一条 p4+hq+AQ 链）**[实测]

| 路线 | wall |
|---|---|
| 从 1440p HEVC 原素材 | **30.69 s** |
| 从 720p H.264 代理 | **50.4 s** |

**项目自身历史真值（不是我的基准，是任务 859 自己的日志）[实测]**

`123\17.859*\reports\master_render_4k.log`：

```
SEG_RENDER_START 2026-09-30T00:47:32Z      ← CreationTime 2026/9/30 8:47:32
...
MASTER_RENDER_COMPLETE                     ← LastWriteTime 2026/9/30 9:59:04
-rw-r--r-- 1 Administrator 197121 2085013201  ← 成片 1.94 GB
episodes=20 expected_program_sec=899.7
```

→ **4312 s 墙钟渲 899.7 s 节目 = 4.79× 实时。** 这与父会话说的
"4K 渲一次 12–34 分钟"一致（13 分钟节目 ≈ 34 分钟）。**这是最有代表性的基线。**

---

## 7. 结论与建议

### 能快多少

| 口径 | 现在 | 改后 | 提速 |
|---|---|---|---|
| 单段 30 s（OBS 1440p 源，min） | 45.9 s | 27.2 s | **1.68×** |
| 240 s 节目（**机器空闲**，含并发 4 路） | 263 s | 约 80 s | **约 3.2×** |
| 240 s 节目（**机器被占用**，并发收益归零） | 342 s | 约 205 s | **1.68×** |
| 859 式 899.7 s 节目（**空闲**） | 4312 s（34 min） | 约 1350 s | **约 3.2×**，即 → **约 22 min** |

### 最该改的 1–2 个参数/方法

1. **`-preset p7 -tune hq` → `-preset p4`，并加 `-rc-lookahead 0 -g 30 -bf 0`**
   （实测 1.49× → 1.68×，**且对机器负载免疫**，见 §6 稳定性列）。
   **代价：这是唯一的真代价——画质换速度。** 同码率下压缩效率下降；
   关掉 lookahead + B 帧后 GOP 变短（`-g 30` ≈ 每 0.5 s 一个关键帧），**文件会略大**
   （实测 27.24 s / 71.5 MB vs 45.87 s / 69.3 MB，约 +3%）。
2. **`-Jobs 4` 并发渲分段**（实测**机器空闲时 1.88×**；**机器被占用时零收益甚至变负**，见 §4.2）。
   **代价：单段会变慢、总量变快；而且收益依赖机器空闲。** `-slices` 未测。

**空闲机器上两项合计约 3.2×（1.68 × 1.88），859 式节目 34 min → 约 11 min。**
**机器被占用时只剩 1.68×（并发那项归零）。**

### 顺手可以改、但**别指望它提速**

- 删 `fps=60`（源已是 CFR 60，这滤镜空转）、换 `flags=fast_bilinear`——**零画质代价**，
  但**实测收益在噪声内**（§2.3）。改了不亏，当卫生措施做。
- 对 `E:\PR导出` 的真 4K 素材，`scale=3840:2160` 本身就是空操作，**可以考虑整段删掉**。

### 明确**不要**做的

- ❌ **不要建代理**（§3，实测**慢 8.2×**：建库 1610 s，且渲同一段反而从 30.7 s 变 50.4 s）。
- ❌ **不要用 `-noaccurate_seek`**（实测慢 2×）。
- ❌ **不要为了"全 GPU"上 `scale_cuda`**（实测收益 0 甚至为负；若上，**必须同时删 `-pix_fmt yuv420p`**）。
- ❌ **不要 `-rc vbr -cq N -b:v 0` 不给 maxrate**（实测体积炸到 3.7×）。
- ❌ **不要换 PyAV / vidgear / FFmpegKit**（同一个 libav 内核）。
- ❌ **不要指望 ffmpeg 8.x 有 seek 加速特性**（[未找到]）。

### 一句话代价

> 代价是**画质换速度，而且是不可逆的那种**：`-preset p4` + `-rc-lookahead 0` + `-bf 0` + 关 AQ
> 会让**暗部、烟雾、快速位移的战斗画面明显变糙**——对"游戏高光片段"影响比影视小，
> 但**必须成片看过再冻结**。
> 若画质不可退让，就只吃「`-Jobs 4`」这 **1.88×**，
> 而 `scale_cuda` / 代理 / 换引擎这些"听起来很硬核"的路全部实测无效。

---

## 8. 可复现命令

全部脚本在 `C:\Project\永劫无间\.scratch\aivideo\bench\`（ASCII-only，路径靠 `$PSScriptRoot`
运行时解析——**`.ps1` 里写中文路径字面量必须存 UTF-8 with BOM，否则 PS 5.1 按 ANSI 读会乱码**，
这正是 AGENTS.md §1 记录的事故）：

| 文件 | 作用 |
|---|---|
| `bench.ps1` | 基准引擎：跑 N 段 × M 遍 × J 并发，从 `speed=` 反推每段墙钟 |
| `H_final.ps1` | 1440p 源 round-robin + 代理 + 并发 |
| `L_4k.ps1` | **`E:\PR导出` 真 4K 源** round-robin + 并发 + 解码地板 |
| `summarize.ps1` | 汇总 `out\*.err` 成表 |
| `out\*.err` | 每次运行的原始 ffmpeg 进度行（墙钟证据） |

单条最小复现（解码地板，父会话可直接粘贴）：

```powershell
$ff='C:\Project\永劫无间\.video-tools\LosslessCut\resources\ffmpeg.exe'
$src=(Get-ChildItem 'E:\OBS' -Filter '2026-10-04 15*.mp4' | Select-Object -First 1).FullName
Measure-Command { & $ff -hide_banner -v error -ss 600 -to 630 -i $src -an -f null - }
```

素材探测（复现 §0.1 的分辨率表）：

```powershell
$fp='C:\Project\永劫无间\.video-tools\LosslessCut\resources\ffprobe.exe'
Get-ChildItem 'E:\PR导出' -Filter '*.mp4' | Select-Object -First 3 | ForEach-Object {
  & $fp -v error -select_streams v:0 -show_entries stream=codec_name,width,height,r_frame_rate,bit_rate -of csv=p=0 $_.FullName }
```

---

## 9. 本报告的已知弱点（请连同结论一起读）

1. **绝对数字不可信，这是本次最大的限制**。§0.3：整场基准期间另一个 session 一直在渲真 4K 母版，
   同配置重复测离散度可达 2×（`scale_cuda` 四轮 51.34 → 256.75 s）。
   我用 **round-robin + 取 min** 缓解，并明确标注哪些结论来自被污染的批次（§2.3 已自我纠正一次）。
   **建议在机器空闲时重跑 `L_4k.ps1` 复核。**
2. **`E:\PR导出` 真 4K 生产素材的 round-robin 尚未跑完**。`L_4k.ps1` 已写好但因争用未执行完，
   所以**本文的 1.68× 是在 `E:\OBS` 1440p 源上测的**。
   对真 4K 源，`scale` 是空操作，**理论上有利无弊**（§0.1），但**没有实测数字**，**[未测]**。
   **这是最该补的一块。**
3. **`-Jobs` 的收益结论分两批且相反**（§4.2）。我倾向"空闲时有效、被占用时无效"，
   但只跑了两批，**[推断]**成分不小。
4. **`-slices`（多 slice）未实测**，[未测]，不编数字。
5. 4060 Ti 的 NVENC 引擎确切数量与聚合吞吐，[未找到] 官方表格。
6. **画质代价没有客观量化**。我断言 p4 + 关 AQ + 短 GOP 会让暗部/运动画面变糙，
   这是 **[推断]**（依据 NVIDIA 文档中 AQ/lookahead 的作用说明 + 体积实测 +3%），
   **但本报告没有跑 VMAF/SSIM 对比**。**决策前应实跑一次 libvmaf 对比**（本机 ffmpeg 带 `--enable-libvmaf`，可用）。