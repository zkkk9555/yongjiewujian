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

round-robin 第 1 轮，1440p HEVC 源，30 s 片段：

| 配置 | 墙钟 | 相对当前 | 体积 |
|---|---|---|---|
| **当前脚本原样**（`fps=60,scale=lanczos`, p7, tune hq, spatial+temporal AQ） | **45.87 s** | 1.00× | 69.3 MB |
| 去掉 `fps=60`（改 bicubic） | 53.47 s | 0.86×（更慢，落在噪声内） | 69.3 MB |
| `-hwaccel cuda` + `scale_cuda`（全 GPU 链） | 51.34 s | 1.12×（更慢） | 69.2 MB |
| **`fast_bilinear` + `-preset p4`（AQ 保留）** | **30.69 s** | **1.49×** | 69.3 MB |
| **`fast_bilinear` + `-preset p4 -tune ll -rc-lookahead 0 -g 30 -bf 0`** | **27.24 s** | **1.69×** | 71.5 MB |

同一批实验里单独隔离 AQ（1440p 源、p4）：

| | 每段墙钟 |
|---|---|
| p4 + AQ on | 41.7 s |
| p4 + AQ **off** | **28.6 s** |

→ **AQ 单独值 1.46×**，正好对应上面 §2.1 那条"all adaptive quantization modes internally use CUDA"。

### 2.3 scaler flag 影响很小（在 NVENC 瓶颈下）**[实测]**

同样 p7 + AQ，改缩放算法：

| scaler | 每段墙钟 |
|---|---|
| `flags=lanczos` | 58.7 s |
| `flags=bicubic` | 55.7 s |
| `flags=fast_bilinear` | **50.9 s** |

→ 三个算法差距不到 1.15×。**因为瓶颈在 NVENC/AQ，不在 swscale。**
换缩放算法是「免费的小钱」，但**别指望它当主优化**。

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

→ **统计上无差别。** 全 GPU 链解决的是「CPU 解码/缩放瓶颈」，
而 §0.2 已经证明**本机根本不是 CPU 瓶颈**。**回答问题 5：不必做，收益 0。**

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

### 3.2 代理建库成本（回答"756s 那个结论现在还成不成立"）

**[实测进行中 / 见 §6 表格 `PROXY_BUILD` 行]** — 720p h264_nvenc 代理整段 2400 s 源。

**先给结论方向 [推断]**：现代 NVENC 建 720p 代理确实比以前快，但**代理这条路对本项目仍然是净亏损**，理由与年代无关：

1. 解码只占 13–22%（§0.2），代理最多省这部分；
2. 720p 代理再上采样到 2160p，**画质比直接从 1440p/2160p 源上采样更差**；
3. 生产素材（`E:\PR导出`）本来就是 3840×2160，**代理连"变小"的意义都没有**，纯粹白建；
4. 建库是**一次性大额固定成本**，而渲染是要反复跑的（"多渲几版就上小时"正是本任务的前提）——
   代理只在「渲染次数极多」时才回本，而这里的瓶颈是**单次渲染太慢**，不是次数。

### 3.3 ProRes Proxy / DNxHR / 2024-2026 有没有更好的中间格式 **[推断]**

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

### 4.2 实测并行加速比 **[实测，但受 §0.3 争用污染]**

当前链、240 s 节目（8×30 s）、`E:\OBS` 1440p 源：

| 并发 | 墙钟 | 相对 jobs=1 |
|---|---|---|
| jobs=1 | 263 s | 1.00× |
| jobs=2 | 211 s | 1.25× |
| jobs=4 | **140 s** | **1.88×** |

→ **4 路是明显甜点**；**远非线性**。

### 4.3 为什么非线性（这是重点，别误判成"NVENC 不够"）

**[文档 + 实测]** §2.1 已经证明：lookahead 与 AQ **吃的是 CUDA core，不是 NVENC 引擎**。
所以 `jobs=4` 时真正被抢的是：8 个 CPU 线程做 HEVC 解码 + 4 份 CUDA 上的 AQ/lookahead。
**继续加并发只会让每路更慢，而不是让总量更快。**

**[推断]** 在你们当前参数（p7 + tune hq + 空间/时间 AQ）下，
**jobs=4 附近就该到顶了，再往上（6/8 路）大概率负收益**。

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

**round-robin（`E:\OBS` 1440p HEVC 源，同一轮内比较）**

| 配置 | wall | 相对 |
|---|---|---|
| 当前脚本原样 | 45.87 s | 1.00× |
| 去 `fps=60` + bicubic | 53.47 s | 0.86× |
| `-hwaccel cuda` + `scale_cuda` | 51.34 s | 1.12× |
| fast_bilinear + p4 + AQ | 30.69 s | 1.49× |
| fast_bilinear + p4 + ll + lookahead 0 + g30 + bf0 | **27.24 s** | **1.69×** |

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
| 单段 30 s（OBS 1440p 源，轮内） | 45.9 s | 27.2 s | **1.69×** |
| 240 s 节目（含并发 4 路） | 263 s | 约 70 s | **约 3.5×** |
| 859 式 899.7 s 节目（4.79× 实时） | 4312 s | 约 1230 s | **约 3.5×**，即 34 min → **约 10 min** |

### 最该改的 1–2 个参数/方法

1. **`-preset p7 -tune hq` → `-preset p4`**（实测单项 1.49×）。
   **代价：同码率下压缩效率下降，画质略降。** 若要补偿，把 `-b:v 18M` 往上调，
   或接受同等观感下体积略增。**这是唯一能动 1.5× 的单参数。**
2. **`ffmpeg -ss S -to E -i SRC` 里删掉 `fps=60`**（源已是 CFR 60，这滤镜是空转）。
   **代价：零画质代价。** 同时把 `flags=lanczos` 改 `fast_bilinear`/`bicubic`（再 ~1.1×，
   代价是上采样锐度轻微下降；**对 `E:\PR导出` 的真 4K 素材则完全无代价**，因为那是空操作）。

**并发 `-Jobs 4`（约 1.88×）是第三个便宜的大头。**

### 明确**不要**做的

- ❌ **不要建代理**（§3）：解码只占 13–22%，代理最多省这部分，还要付几百秒建库 + 画质更差。
- ❌ **不要用 `-noaccurate_seek`**（实测慢 2×）。
- ❌ **不要为了"全 GPU"上 `scale_cuda`**（实测收益 0；记得同时删 `-pix_fmt yuv420p`）。
- ❌ **不要 `-rc vbr -cq N -b:v 0` 不给 maxrate**（实测体积炸到 3.7×）。
- ❌ **不要换 PyAV / vidgear / FFmpegKit**（同一个 libav 内核）。
- ❌ **不要指望 ffmpeg 8.x 有 seek 加速特性**（[未找到]）。

### 一句话代价

> 真正的代价是**画质换速度**：`-preset p4` + 关 AQ 是这 1.5–1.7× 的主要来源，
> 而 `-spatial-aq/-temporal-aq` 关掉后**暗部与运动画面会明显变糙**——
> 对"游戏高光片段"影响比一般影视小，但**必须成片看过再冻结**。
> 若画质不可退让，就只吃「删 `fps=60` + 换 scaler + `-Jobs 4`」这 **约 2.4×**，
> 这三项**零画质代价**。

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

## 9. 本报告的已知弱点

1. **绝对数字不可信**：§0.3 有别的 session 同时在渲真母版，同配置重复测离散度可达 2×。
   已用 round-robin 缓解，但**没有完全消除**。**建议在机器空闲时重跑 `L_4k.ps1` 复核。**
2. **`E:\PR导出` 真 4K 源的 round-robin 数据见 §6/§6 表格**（`l_*` / `m_*` 行）——
   **这是最该采信的一组**，因为它对应生产素材。首次冷跑受争用影响，请重跑确认。
3. **`-slices`（多 slice）未实测**，[未测]，不编数字。
4. 4060 Ti 的 NVENC 引擎确切数量与聚合吞吐，[未找到] 官方表格。