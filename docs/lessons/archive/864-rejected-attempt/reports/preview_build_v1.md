# preview_build_v1.md — 渲染员落盘（任务 21 / 素材 864）

## 渲染依据

| 项 | 值 |
|---|---|
| 时间线（唯一真源） | `timeline\combat_episodes_v1.json`（v1，validate pass=true，11 场，16 条删除段，1 处段内挖洞） |
| 渲染源 | `E:\PR导出\864永劫无间 2026-09-30 02-57-13.mp4`（**从原始素材直接渲染**，不是从任何低清预览放大） |
| 节目映射 | `timeline\program_map_v1.json`（12 个切口，节目总秒 614.9） |
| 渲染脚本 | `cache\render_preview.py`（纯 ASCII，无烧录开关，无字幕滤镜参数） |
| 分段缓存 | `cache\v1segs\vseg001..012.mp4` + `concat.txt` |
| 成品 | `preview\864-review-v1.mp4` |

**从源重渲，不是复用**：12 个分段全部本次实渲（`rendered=12 reused=0`）。分段落盘后用 concat demuxer `-c copy` 合成，因此容器时长 = 各段时长之和。

## 编码参数

| 项 | 预览 v1 |
|---|---|
| 分辨率 | 1280×720（720p，横版） |
| 帧率 | 60 fps CFR（`r_frame_rate == avg_frame_rate == 60/1`） |
| 视频编码 | H.264 High，`libx264 -preset fast -crf 20`，`-g 60`，`yuv420p` |
| 视频码率（实测） | 10,266,612 bps ≈ 10.27 Mbps（VBR，由 crf 控制） |
| 帧数 | 36,894（= 614.9 s × 60 fps，与节目秒一致） |
| 音频编码 | AAC-LC 48 kHz 立体声 160 kbps（**源音轨直通，无 BGM、无混音处理**） |
| 音频码率（实测） | 160,342 bps |
| 容器 | MP4，`+faststart` |
| 字幕流 | **0 条**（ffprobe `codec_type == "subtitle"` 计数为 0） |
| 烧录像素字 | **无**（渲染命令无任何字幕/文字滤镜） |
| 文件体积 | 802,410,248 字节（≈ 765 MB） |
| 容器时长 | 614.921333 s（节目口径 614.9 s，差 **+0.021 s**） |

## 解码

```
ffmpeg -v error -xerror -i preview\864-review-v1.mp4 -f null -     →  exit 0，stderr 0 行
```
日志落 `preview\864-review-v1.decode.log`。全片 36,894 帧从解码到解码无错、无黑帧中断、无 A/V 漂移（`av_sync` 差 0.021 s）。

## 媒体滤镜证据（补 qa_gate `media_filters` 的 WARN）

原始输出落 `reports\preview_media_filters_v1.log`：

| 滤镜 | 命中 | 换算到源 | 判定 |
|---|---|---|---|
| `blackdetect d=0.5 pix_th=0.10` | 节目 598.371–600.271（1.9 s） | 源 1095.871–1097.771 | **游戏原生的终局过场黑屏**，不是剪辑缺陷。落在 combat_011 段内（非切点，切点是节目 603.3）。规约要求"不得切在'打完 → 黑屏/结算前'"，且黑屏是"失败/战报 → 结算三屏"的必要过场（seg13/seg14 两路独立逐帧确认过 `[1096.0,1097.8)`）。**保留，不挖。** |
| `freezedetect n=-60dB d=1.0` | 节目 598.371 起 | 同上 | 与上面同一处静止黑画面，非独立缺陷 |
| `silencedetect n=-45dB d=1.5` | 节目 603.292–609.191（5.9 s） | 源 1115.9–1121.8 | **战报/名次屏（第 3/8 名）自身的静音**，结算屏常态，非剪辑引入 |
| `ebur128 peak=true` | I = **-17.8 LUFS**，LRA = 9.6 LU，true peak = **-0.2 dBFS** | — | 未加任何音频处理，源游戏混音直通。true peak 贴近 0 dBFS 是源素材自身电平，本阶段**不做响度归一**（会改变源混音），如实记录 |

补充说明：节目 603.3 那个"段内挖洞接缝"（源 1100.8–1115.9 的 15.1 秒纯加载屏被 `excluded_inside` 挖掉）**没有产生黑帧或静音命中** —— blackdetect/freezedetect 都没报到它，silencedetect 命中的 603.292–609.191 已是结算屏本体。

## 清理

本次渲染未删除任何旧预览（v1 是本任务第一版，`preview\` 下无过期版本）。后续 vN+1 可解码可用时立即删 vN-1 及更早，每次删除记 `reports\cleanup_log_vN.md`。

## 结论

渲染链路合规：从原始素材重渲、720p、干净画面、零字幕流、零烧录、无 BGM、无装饰特效；12 个分段实渲零复用；容器时长与节目口径差 0.021 s。
