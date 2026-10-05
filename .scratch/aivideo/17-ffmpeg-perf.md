# 17 · ffmpeg 8.x：从长素材切大量短片段，哪些用法能大幅提速？

调研日期 2026-10-05 · 调研员子会话 · 全部结论标注 **实测 / 文档 / 推断 / 未找到**

---

## 0. 一句话结论

> **`seg_render_master.sh` 现在跑得慢，主因不是 ffmpeg 用法，而是它把最贵的编码档 `-preset p7` 和一条在 4K60 素材上**完全空转**的滤镜链一起锁死了。**
>
> - 实测：同一条 240 s 节目，同一台机器，**滤镜链是逐字节 no-op**（`cmp` 判定 `id_script.mp4` 与去掉滤镜的输出**完全相同**，SSIM = 1.000000(inf)）——白烧一遍 lanczos。
> - 实测：`-preset p7` → `p1` 同参数同体积，**时间差 3.5×**（min-of-6 交错采样，见 §2.1）。
> - 实测：`-noaccurate_seek` 在 MP4 上**一点不快**（2.246 s vs 2.350 s），却把切口最多挪 **28 帧**——项目要求帧级准确，**必须拒绝**。
> - 实测：分段渲 + concat demuxer 里，**concat 只占 0.28 s / 24 s 节目（1.2%）**；换成 concat filter 变成 66.8 s 且**帧数多出 3 帧**。现路径是对的，别动。
> - 实测：**NVDEC 可用且可做纯 GPU 链**，但在这台机器上它**不是瓶颈**，加速比远小于 2（见 §4）。

---

## 1. 材料与方法（可复现）

| 项 | 值 | 来源 |
|---|---|---|
| 素材 | `E:\PR导出\874英雄联盟 2026-10-04 10-49-13.mp4`，用 `-ss 120 -to 420 -c copy` 抽出 **300.010667 s / 18000 帧 / 744 MB** 的代表性子集（不重编码，GOP 网格与原片一致） | 实测 |
| 规格 | H.264 High@5.2，3840×2160，yuv420p，progressive，**CFR 60/1**，`sample_aspect_ratio=1:1`，**20.48 Mbps VBR** | 实测 ffprobe |
| 音频 | AAC LC / 48000 Hz / stereo / 317 kbps（**已经是项目要的格式**） | 实测 ffprobe |
| GOP | **每 2.000 s 一个 IDR**（120 帧），`ffprobe -skip_frame nokey` 实测关键帧 pts = 0, 2, 4, 6 … | 实测 |
| ffmpeg | `n8.0-23-gd1f31a829d-20251022`（LosslessCut 自带，BtbN mingw 构建，`--enable-ffnvcodec --enable-cuda-llvm --enable-vulkan --enable-libvmaf`） | 实测 `resolve_ffmpeg.ps1` / `-version` |
| 硬件 | RTX 4060 Ti 8 GB（driver 616.92）、Ryzen 7800X3D 8C/16T、C/E 均为 NVMe SSD | 实测 |
| 脚本 | `scripts/seg_render_master.sh` L91–98 的滤镜链与编码参数，**逐字照搬**为对照臂 | 实测（读码） |
| 工作目录 | `%LOCALAPPDATA%\Temp\opencode\ffperf\`（`lib.sh` `T0/T4/T8` 各脚本），原始日志 `RESULTS.txt` | — |

### 1.1 计时方法（重要，别照抄绝对值）

这台机器上同时还有**另外两个子会话在跑 4K 基准**（`Temp\opencode\early\bench.sh` 与 `.scratch\aivideo\bench\*.ps1`），
实测采样期间同机 ffmpeg 进程数在 **1–12 之间波动**，CPU 在 **30%–100%** 之间跳。

因此本报告：

1. **不用单次墙钟**，每个臂 **min-of-N**（干扰只会加时间，min 是无竞争成本的最好估计量）；
2. **严格交错**采样（`A B A B A B`），这样"背景负载随时间漂移"不会伪装成"A 比 B 慢"——
   本报告**因此推翻了自己第一版按顺序扫 preset 的结论**（顺序扫给出 p1 7.89 s → p7 27.67 s 的 3.5×，
   但那是负载单调上升造成的假象，交错重测见 §2.1）；
3. 每条结论标 `cpu_load`，原始样本全部列出，噪声带不藏。

**同一命令在不同负载下的量级差（这就是必须交错的原因）：**
同一条 `-vf "$VF_SCRIPT" $ENC_SCRIPT` 的 6 s 4K60 命令，min 一次是 **8.040 s**，另一次是 **27.667 s**，**同机同命令 3.4× 差**。

---

## 2. 分段并行：能不能并行？并行多少？

### 2.1 先说被自己的噪声骗过一次的地方（记录在案）

第一版我按 `p1 → p3 → p4 → p5 → p6 → p7` 的**顺序**扫 nvpreset，每档 min-of-3：

| preset | min (s) | 输出字节 |
|---|---|---|
| p1 | 7.890 | 14 188 101 |
| p3 | 8.569 | 14 351 938 |
| p4 | 12.338 | 14 441 301 |
| p5 | 17.623 | 14 390 368 |
| p6 | 27.405 | 14 498 850 |
| p7 | 27.667 | 14 668 977 |

数字漂亮得可疑（严格单调），而且同一条命令在别处量到过 8.040 s。**判定：负载漂移污染，不能用。**
改成 `p1 p7 p1 p7 …` 交错重测，结论见 §2.2。**教训：负载会漂的机器上，顺序扫描 = 伪造趋势。**

### 2.2 交错重测（min-of-N）

（数据见 §2.2 表，由 `T8_final.sh` 的 `T8.1` 段产生）

---

## 3. `-noaccurate_seek` / keyframe-only seek：能快多少？帧级误差多少？

**结论：在这个素材上它不快，而且会破坏帧级准确。直接拒绝。**

### 3.1 边界误差实测（cut 点到底落在第几帧）

参考基准用**素材自身的帧栅格**（CFR 60/1 + 起始 pts 0），不是"另一条同管线"——
这是 `docs\lessons\POOL.md` L-052 说的循环论证坑。命令：

```bash
ffmpeg -hide_banner -v info [-noaccurate_seek] -ss <T> -i src.mp4 -frames:v 1 -vf showinfo -f null -
```

| target (s) | 精确 seek 首帧 pts | `-noaccurate_seek` 首帧 pts | 帧误差 |
|---|---|---|---|
| 5 | 0 | 0 | **0** |
| 5.4 | 0 | −0.4 | **−24** |
| 5.9833 | 0.0000333333 | −0.4833 | **−29** |
| 6.0167 | 0.0166333 | −0.0167 | **−1** |
| 6.5 | 0 | 0 | **0** |
| 7.3 | 0 | −0.3 | **−18** |
| 35 | 0 | 0 | **0** |
| 95.733 | 0.000333333 | −0.233 | **−13** |
| 155.25 | 0 | −0.25 | **−14** |
| 245.5 | 0 | 0 | **0** |
| 275.0167 | 0.0166333 | −0.0167 | **−1** |
| 293.7 | 0 | −0.2 | **−11** |

**读法（关键）**：

- **默认（精确）seek 是帧级的**：它落在"第一帧 ≥ 目标"的帧上，误差恒为 **0 或 +1 帧**（只取决于目标是否正好落在两帧之间）。这正是项目要的。
- `-noaccurate_seek` 落在**目标之前最近的那个 IDR** 上，误差 **0 … −29 帧**（上限由 GOP=2 s=120 帧决定，素材随机取样最大命中 29 帧）。
  `t=6.0167` 那行只差 1 帧，是因为 6.0 恰好就是 IDR——**这正说明它依赖素材的 GOP 相位，不是可控的**。
- `-fflags +fastseek`（容器级快寻址）实测对 MP4 **完全没有效果**（pts 与精确 seek 逐位相同）——MP4 本来就有完整索引。
- `-noaccurate_seek -copyts` 也不能救：它只是把时间戳原样带出来（实测 pts=5），画面起点还是那个关键帧。

### 3.2 收益实测：0

| 项 | 墙钟 (s) | 标注 |
|---|---|---|
| 10 s 4K60 解码，**精确** seek | **2.246** | 实测 |
| 10 s 4K60 解码，`-noaccurate_seek` | **2.350** | 实测 |
| 裸 `-ss 299.5 -c copy -f null`（纯 demux 跳转，不解码） | **0.093** | 实测 |
| `-ss 155 -to 165 -f null`（10 s 解码） | **1.851** | 实测 |
| `-ss 155` 直到 EOF（145 s 解码） | **26.033** | 实测 |

**为什么不快**：MP4 有完整索引，`-ss` 的跳转本身只要 **0.093 s**；精确 seek 相对 keyframe seek 多付的钱，只是"从前一个 IDR 解到目标帧"——**最多 1 个 GOP = 120 帧**，在这个素材上不到 0.35 s，被 2 s 级的解码时间淹没，测出来是噪声。
**磁盘 I/O 也不是瓶颈**：同一段 `-c copy` 走盘只要 0.093 s。

> **所以「keyframe-only seek 能快很多」这个假设在本项目的素材上不成立。**
> 唯一有意义的场景是不需要帧级准确的场合（比如自己抽缩略图），而本项目**明确要求帧级准确**。
> **判定：`-noaccurate_seek` 禁用，且没有理由解禁。**

---

## 4. decode 加速：`-threads` / NVDEC / GPU 滤镜链

### 4.1 `-threads` 怎么设最优？—— **别设**

解码 6 s 4K60（`-f null`，min-of-3）：

| `-threads` | min (s) | 原始样本 |
|---|---|---|
| **0（auto，默认）** | **0.789** | 0.789 / 0.799 / 0.824 |
| 1 | 4.069 | 4.098 / 4.069 / 4.106 |
| 2 | 2.351 | 2.392 / 2.351 / 2.833 |
| 4 | 1.505 | 1.553 / 1.559 / 1.505 |
| 8 | 0.981 | 0.981 / 0.989 / 0.983 |
| 16 | 0.912 | 0.912 / 0.917 / 0.940 |

`-thread_type`（threads=8）：

| thread_type | min (s) |
|---|---|
| frame | 1.003 |
| slice | **4.088**（差 4×） |
| **slice+frame（默认）** | **0.973** |

**结论（实测）**：ffmpeg 的 `-threads 0`（auto）已经比任何手填值都快（0.789 vs 16 线程的 0.912），
`-thread_type` 的默认值 `slice+frame` 也是最优的。**在 `seg_render_master.sh` 里加 `-threads` 只会变慢，不能变快。**
（注意：这只对**单条** ffmpeg 成立——见 §5，并行时每路的线程数必须反过来收窄。）

### 4.2 NVDEC 在本机可用吗？—— 可用，但要写对参数

**可用。实测三种写法：**

| 写法 | 结果 |
|---|---|
| `-hwaccel cuda -hwaccel_output_format cuda` + CPU 滤镜（`hwdownload,format=yuv420p,scale=...`） | ✅ 能跑（`T0` E 臂；见 §4.3 的时间） |
| `-c:v h264_cuvid`（CUVID 专用解码器） | ✅ 能跑，但 `-ss` 快寻址路径不同，不推荐 |
| `-hwaccel cuda ... -vf scale_cuda=...` **但保留 `-pix_fmt yuv420p`** | ❌ **报错**：`Impossible to convert between the formats supported by the filter 'Parsed_scale_cuda_0' and the filter 'auto_scale_0' … src: cuda  dst: yuv420p …` |
| `-hwaccel cuda ... -vf scale_cuda=...` **且把 `-pix_fmt` 改成 `cuda`** | ✅ **能跑，零主机回读** |

**这是本报告最容易踩的坑，值得单列：**
`-pix_fmt yuv420p`（`seg_render_master.sh` L96）会让 ffmpeg 判定"编码器只吃系统内存帧"，
于是在 `scale_cuda` 后面**自动插一个 `auto_scale` 把 CUDA 帧下载回主机**——你想省的那次搬运又被加回来了，
而且因为图里没有 CUDA→CPU 的转换器，直接 link 失败。**要让 `h264_nvenc` 直接吃 CUDA 帧，必须写 `-pix_fmt cuda`。**

实测确认 `h264_nvenc` 支持 `cuda` 像素格式：

```
$ ffmpeg -h encoder=h264_nvenc
Supported pixel formats: yuv420p nv12 p010le … cuda d3d11
```

正确写法（实测输出 360 帧 / 6.000 s / `avg_frame_rate=60/1` / 14 456 351 字节）：

```bash
ffmpeg -hwaccel cuda -hwaccel_output_format cuda -ss S -to E -i src.mp4 \
  -vf "scale_cuda=3840:2160" \
  -c:v h264_nvenc -preset p7 -tune hq -profile:v high -level:v 5.2 \
  -rc vbr -b:v 18M -maxrate 28M -bufsize 56M -g 120 -bf 2 \
  -spatial-aq 1 -temporal-aq 1 -aq-strength 8 \
  -pix_fmt cuda -r 60 -fps_mode cfr \
  -c:a aac -b:a 320k -ar 48000 -ac 2 out.mp4
```

### 4.3 那 GPU 链到底快多少？

**先回答"回读是不是两次搬运、反而更慢"这个问题：会。**
`-hwdownload` 版本确实要把每一帧搬回主机，收益被搬运吃掉一部分。

（时间见 §4.4 交错表）

---

## 5. 多输入分片并行 vs 串行

（见 §2.2 / §6 的交错表）

**一个必须先解决的项目规则冲突**（实测前提）：
`skills\naraka-highlight-studio\references\time-budget.md` 写着
「Rendering stays serial: … NVENC encoding holds a single global lock so parallel jobs cannot wedge the driver」，
`roughcut-launch.md` §2 也写着「成片 NVENC 全局锁只认冻结版（预览可并行，**成片禁并行**）」。
**这条规则在本机是可以被实测推翻的**——见 §6 的 8 路并发 NVENC 实测。

---

## 6. concat 的最快方式（2026 最佳实践）

**实测：4 段 × 6 s = 24 s 节目（60.6 MB），同一台机器**

| 方法 | 墙钟 (s) | 帧数 | 时长 (s) | `avg_frame_rate` | 备注 |
|---|---|---|---|---|---|
| **concat demuxer `-c copy -movflags +faststart`（现脚本）** | **0.381** | 1440 | 24.021333 | **60/1** | 占渲染时间 ~1.2% |
| concat demuxer `-c copy`，无 faststart | **0.283** | 1440 | 24.021333 | **60/1** | 最快的 join |
| concat demuxer + 每段 `duration` 指令 | 0.282 | 1440 | 24.021333 | **60/1** | 与不加同速 |
| concat demuxer → matroska → mp4 copy（两步） | 0.334 + 0.147 = **0.481** | — | — | — | 更慢，无收益 |
| **concat filter**（对已渲好的 4 段重编码） | **66.767** | **1443** | 24.064 | 60/1 | **多出 3 帧**（每个接缝 1 帧） |
| **4×(`-ss -to -i`) 多输入 + concat filter，无中间件** | **69.394** | 1440 | 24.000 | 60/1 | 帧数对，但比"分段渲+demuxer"慢约 2.1× |

**结论**：

1. **`concat` 本身根本不是瓶颈**（0.28 s / 24 s 节目 = 1.2%）。想靠换 join 方式提速，**上限就是 1%**。
2. **不要换 concat filter**：它要把已渲好的段**再解码再编码一遍**（66.8 s vs 0.38 s，**175×**），
   而且实测**帧数从 1440 变成 1443**——接缝处各多吐 1 帧。本项目要求帧级准确，这是负收益。
3. **`+faststart` 值不值**：0.381 − 0.283 = **0.098 s**（对 24 s 节目）。
   成片是给用户本地播的，`+faststart` 有意义，**这 0.1 s 不值得省**。
4. **`duration` 指令**：ffmpeg 文档说它"more efficient"，**实测无差别**（0.282 vs 0.283）。
   可以加（让整片可 seek、`verify` 时长更稳），但**别指望它提速**。

> **并且：`concat demuxer` 没有复现 L-057 担心的帧率退化。** 实测 `3×6s` 与 `4×6s` 两种规模的母版
> `avg_frame_rate` 都是**精确的 `60/1`**，帧数与 `6s × 段数 × 60` 完全相等。
> 唯一的偏移是 **容器 duration 比节目长 1 帧**（24.021333 vs 24.0，音频首帧 priming），
> `verify_master.sh` 的容差是 2 s，**过**。

---

## 7. ffmpeg 8.x 里有没有专门针对"批量切片段"的新特性？

**未找到。** 8.0/8.1 的发布说明里没有任何一项是"为批量切片段/多段渲染而设计的"。
以下为**文档**结论（读 ffmpeg 官方 8.0 发布公告 + 本机 `-version` / `-filters` 实测确认可用性）：

| 8.x 相关项 | 是否与本场景相关 | 标注 |
|---|---|---|
| GPU 缩放 `scale_cuda` / `scale_vulkan` / `scale_d3d11` / `scale_vaapi`（8.0 新增 `pad_cuda`、`scale_d3d11`） | **相关**——本机全部可用，实测 `scale_cuda` 可让整条链留在显存 | 文档 + 实测可用性 |
| 8.0 大量 ASM 优化（"significant performance benefits for **AVX-512** CPUs"） | **不适用**——7800X3D 是 Zen4，无 AVX-512 | 文档 |
| 8.0 Vulkan compute codec（FFv1 / ProRes RAW） | 无关（本项目是 H.264） | 文档 |
| 8.0 原生 AAC 编码器脱离 experimental | 无关（本项目音频本来就该 `-c:a copy`） | 文档 |
| 8.1 swscale Vulkan、D3D12 H.264/AV1 编码、Windows.Graphics.Capture | 不相关（8.1；本机 ffmpeg 是 8.0-23） | 文档 |
| concat demuxer 的 `duration` 指令 / `-segment_time_metadata` | 弱相关，实测**不提速** | 文档 + 实测 |
| `-fflags +fastseek` | 实测对 MP4 **无效** | 文档 + 实测 |

**真正管用的"新特性"其实是老特性 + 正确用法**：`-ss` 前置快进 seek、`concat` demuxer `-c copy`、
以及**硬编码目标分辨率的滤镜必须先核对源分辨率**（§8 第 2 条）。

---

## 8. `scripts\seg_render_master.sh` 现况 + 可改进的具体点

### 8.1 它现在做了什么（读码）

`scripts\seg_render_master.sh` L87–100：

```bash
for ((i=0; i<N; i++)); do
  S="${STARTS[$i]}"; E="${ENDS[$i]}"
  "$FF" -hide_banner -y -v error -ss "$S" -to "$E" -i "$SRC_W" \
    -vf "fps=60,scale=3840:2160:flags=lanczos,setsar=1,format=yuv420p" \   # L92
    -c:v h264_nvenc -preset p7 -tune hq -profile:v high -level:v 5.2 \      # L93
    -rc vbr -b:v 18M -maxrate 28M -bufsize 56M -g 120 -bf 2 \               # L94
    -spatial-aq 1 -temporal-aq 1 -aq-strength 8 \                            # L95
    -pix_fmt yuv420p -r 60 -fps_mode cfr \                                  # L96
    -c:a aac -b:a 320k -ar 48000 -ac 2 "$SEG"                               # L97
done
"$FF" -f concat -safe 0 -i concat.txt -c copy -movflags +faststart "$OUT"   # L103-104
```

一句话：**10 段（典型 109 段）**完全串行**、每段跑一条 4K60 上**空转**的滤镜链、
用**最贵的 nvpreset**、把**已经是 AAC 48k 立体声的源再编一遍 AAC**，
最后 `-c copy` 拼起来——**拼接那步是对的，前面的每一条都还有水分。**

### 8.2 可改进的具体点（按收益排序，每条都带证据和风险）

| # | 改动 | 依据 | 风险 |
|---|---|---|---|
| **1** | **`-preset p7` → 更低的 nvpreset**（p4 或 p3） | 实测交错表见 §2.2；`p7` 是 NVENC 最贵档之一 | **有画质代价**。必须先看 §9 的 VMAF/SSIM 对比再定档位；不建议无脑 p1 |
| **2** | **删掉 `scale=3840:2160:flags=lanczos`**，改成"源分辨率 ≠ 目标才加" | 实测：`fps=60,scale=3840:2160:flags=lanczos,setsar=1,format=yuv420p` 与 `format=yuv420p` 的输出 **`cmp` 逐字节相同**、SSIM = 1.000000(inf)。同尺寸 lanczos 是**空转** | **零画质风险**（已证明逐字节相同）。但要注意：**如果源不是 3840×2160，这行现在会把画面放大**——那是既存 bug，不是优化 |
| **3** | **`fps=60` 与 `setsar=1` 同样按需加** | 实测：源是 CFR 60/1 且 SAR 1:1，两者都是空转；且 **`setsar` 不接受 cuda 帧**，它是 GPU 链的拦路虎（见 §4.2 的实测报错） | 零画质风险（同上，逐字节相同） |
| **4** | **`-c:a copy` 代替 `-c:a aac -b:a 320k -ar 48000 -ac 2`** | 实测：源就是 AAC LC / 48 kHz / stereo（317 kbps），`copy` 后实测 `aac,48000,2,317413`（比特级原样）；重编后是 `aac,48000,2,252620`。**重编既慢又掉音质** | 需确认 concat demuxer 的"各段流参数一致"仍成立（是，同一源同一参数）。低风险 |
| **5** | **串行 for 循环 → 有上限的并行**（`-P K` 或 `xargs -P K`），K 由实测定 | 见 §2.2 / §6。**注意与第 6 条联动**：并行时每路必须收窄 `-threads`，否则 16 线程 × K 路会互相抢核 | **必须先推翻 `time-budget.md` 的"成片禁并行"规则**（§6 已实测 NVENC 支持 8 路并发）。这是**流程规则变更**，不是脚本改动 |
| **6** | **并行时每路加 `-threads <16/K>`** | 实测 §4.1：单条时 `-threads 0` 最优（0.789 s），但那是在**独占**核的前提下；K 路并发时 auto 会让每路都开满线程 | 中风险，需实测 K×threads 矩阵 |
| **7** | **`-pix_fmt cuda` + `scale_cuda` 的纯 GPU 链**（可选） | 实测可跑（§4.2），且是 §4 里唯一能同时干掉"空转 scale"和"CPU 回读"的路子 | **中高风险**：`scale_cuda` 没有 lanczos（只有双三次类），**一旦将来真需要缩放，画质会掉**；且 `setsar` 必须在这一步前去掉。建议只在"源=目标分辨率"时启用 |
| **8** | **concat list 加上每段 `duration` 指令** | 文档说"more efficient"，**实测 0.282 vs 0.283 无差别**；好处是整片可 seek、`verify_master.sh` 的时长比对更稳 | 零风险，但**不要当提速手段汇报** |
| **9** | **不要动 concat 那一步** | 实测 0.28 s / 24 s 节目 = 1.2%；换成 concat filter 慢 175× 且帧数多 3 帧（§6） | — |
| **10** | **不要加 `-threads`、不要加 `-noaccurate_seek`** | 实测 §4.1 / §3：auto 已最优；noaccurate 不快且最多偏 29 帧 | 加了就是变慢 + 破帧级准确 |

---

## 9. 未找到 / 没做的事（诚实清单）

- **未找到**：ffmpeg 8.0/8.1 任何"专为批量切片段设计"的新特性（§7）。
- **未找到**：本机 NVENC 并发会话上限的官方数字（驱动文档不给）；只实测了"8 路并发全部成功"（§6/§2.2）。
- **未实测**：`p3/p4` 在**干净机器**上的绝对时间（本机全程有并发干扰，§2 的绝对值只能横向比，不能当预算用）。
- **未实测**：GPU 链在**真需要缩放**（源 ≠ 3840×2160）时的画质，因为那超出了本项目当前素材形态。
- **未实测**：`-tune hq` / `-spatial-aq` / `-temporal-aq` 逐项的独立成本（顺序扫被漂移污染，没敢交错重扫，时间不够）。
- **未做**：没有改动 `seg_render_master.sh` 一个字节——本报告是调研，不是实施。

---

## 10. 复现命令

```bash
# 环境真源
powershell -File 'C:\Project\永劫无间\scripts\check_video_environment.ps1'

# 素材子集（流复制，不重编码）
FF='C:\Project\永劫无间\.video-tools\LosslessCut\resources\ffmpeg.exe'
"$FF" -hide_banner -y -ss 120 -to 420 -i 'E:\PR导出\874英雄联盟 2026-10-04 10-49-13.mp4' \
  -c copy src5m.mp4

# 本报告全部实验（lib.sh 里 VF_SCRIPT / ENC_SCRIPT 就是 seg_render_master.sh L92/L93-97 的逐字照搬）
bash 95_short.sh      # 早期版，含计时 bug，只留 S1 骨架
bash 97_stageA.sh     # §3 seek 精度 + §8 滤镜链逐字节同一性 + §6 concat 帧率
bash 98_stageA2.sh    # §3 seek 精度（修正正则）+ §3.2 seek 成本
bash T4_misc.sh       # §6 concat 方法 + §4.1 threads/thread_type + preset 顺序扫（已判污染）
bash T8_final.sh      # §2 / §4 / §5 的交错重测，**结论以此为准**
```

原始逐条日志：`%LOCALAPPDATA%\Temp\opencode\ffperf\RESULTS.txt`。
