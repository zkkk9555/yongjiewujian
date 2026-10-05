# 10 · MCP 生态里的视频/剪辑工具（调研员报告）

- 调研日期：**2026-10-05**
- 调研角度：MCP（Model Context Protocol）生态有没有能直接用的视频/剪辑工具
- 目标环境：opencode harness，**原生 Windows**（win32 / PowerShell），项目已有 29 个 skill
- 证据分级标注：**实测**（本次实际取到 API/页面数据）／**文档**（官方 README/站点声明，未实跑）／**推断**（基于证据的推理）／**未找到**

> 取数口径：star / fork / 创建日 / 最后 push 全部来自 `api.github.com/repos/*` 或 `ungh.cc/repos/*`（GitHub API 有速率限制时切 ungh），抓取时间 2026-10-05。
> 官方 MCP 注册表数据来自 `registry.modelcontextprotocol.io/v0/servers*`。

---

## 0. 一句话结论（先看这个）

MCP 生态**有**视频工具，而且不止一个；但**没有一个能替掉本项目最耗时的「多模态语义判读」环节**——
所有本地 MCP 都只做到「抽帧 + 转写 + 元数据」然后把图**丢回给 Agent 自己看**。
唯一真正「一次调用就判读」的方案（Gemini 原生视频摄入）是个 **0 star 的单人项目**，且要把 4K 素材上传 Google。

**而且存在一个可能直接判死整类工具的未验证风险：opencode 很可能不把 MCP 返回的图片内容送进模型上下文**（见 §4.3）。
装之前必须先花 15 分钟做那个冒烟测试。

---

## 1. MCP server 生态盘点（视频方向）

### 1.1 主流候选（全部实测数据）

| 仓库 | star | fork | 创建 | 最后 push | 语言 | 许可 | 形态 |
|---|---|---|---|---|---|---|---|
| [KyaniteLabs/kinocut](https://github.com/KyaniteLabs/kinocut)（原名 mcp-video） | **186** | 42 | 2026-03-21 | **2026-10-03** | Python | Apache-2.0 | MCP + Python lib + `kino` CLI |
| [guimatheus92/mcp-video-analyzer](https://github.com/guimatheus92/mcp-video-analyzer) | **86** | 16 | 2026-03-09 | **2026-10-04** | TS | MIT | npm MCP + 独立 CLI |
| [ronak-create/FableCut](https://github.com/ronak-create/FableCut) | **701** | 74 | 2026-07-06 | **2026-10-04** | JS | MIT | 浏览器编辑器 + MCP/REST |
| [mutonby/openshorts](https://github.com/mutonby/openshorts) | **6102** | 1368 | 2025-12-19 | **2026-10-04** | Python | MIT | Docker 服务 + MCP |
| [DareDev256/fcp-mcp-server](https://github.com/DareDev256/fcp-mcp-server)（原 fcpxml-mcp-server） | 116 | – | 2026-01-18 | 2026-09-26 | Python | MIT | FCPXML 时间线读写 |
| [WeftCut/WeftCut](https://github.com/WeftCut/WeftCut) | 54 | 15 | 2026-05-22 | **2026-10-05** | TS | MIT | 桌面编辑器 + MCP |
| [tydude001/proofcut](https://github.com/tydude001/proofcut) | 4 | – | 2026-09-11 | **2026-10-05** | Python | NOASSERTION | 转写驱动剪辑 |
| [KitDevUA/video-vision-mcp](https://github.com/KitDevUA/video-vision-mcp) | **0** | **0** | 2026-06-30 | 2026-08-11 | Python | MIT | PyPI MCP（三层后端） |
| [mrbuslov/capcut-ai-editor](https://github.com/mrbuslov/capcut-ai-editor) | 116 | 28 | 2026-02-01 | 2026-07-01 | Python | MIT | CapCut 工程改写 |
| [keiver/image-tiler-mcp-server](https://github.com/keiver/image-tiler-mcp-server) | 3 | – | 2026-02-09 | 2026-03-07 | TS | MIT | 图片切片（防视觉降采样） |
| [1000ri-jp/atsurae](https://github.com/1000ri-jp/atsurae) | 2 | – | 2026-02-15 | 2026-02-16 | Python | MIT | 时间线编辑 + 合成 |
| [ipythonist/mcp-video](https://github.com/ipythonist/mcp-video) | 4 | 1 | 2026-03-29 | 2026-03-29 | Python | MIT | yt-dlp 抽帧（已停更） |
| [littler00t/mcp-deep-video](https://github.com/littler00t/mcp-deep-video) | 1 | 0 | 2026-02-28 | 2026-02-28 | Python | MIT | 运动检测/热力图（已停更） |
| [haithamelmengad/popcorn](https://github.com/haithamelmengad/popcorn) | 7 | 0 | 2026-02-05 | 2026-02-05 | TS | MIT | 场景检测+本地转写（已停更） |
| [video-db/agent-toolkit](https://github.com/video-db/agent-toolkit) | 47 | – | 2025-03-19 | 2026-03-26 | Python | 未标注 | VideoDB 检索型 MCP |

### 1.2 零散 / 低质 ffmpeg 壳（不建议）

| 仓库 | star | 最后 push | 备注 |
|---|---|---|---|
| [bitscorp-mcp/mcp-ffmpeg](https://github.com/bitscorp-mcp/mcp-ffmpeg) | 未实测 | 未实测 | 只 4 个工具（resize/extract/info/version） |
| [maoxiaoke/mcp-media-processor](https://github.com/maoxiaoke/mcp-media-processor) | 未实测 | 未实测 | 10 工具，需 ImageMagick |
| [video-dev/ffmpeg-mcp-comp](https://github.com/video-dev/ffmpeg-mcp-comp) | 4 | 2025-06-03（4 commits） | playground 性质，已死 |
| [NoahWorkman/mcp-ffmpeg](https://github.com/NoahWorkman/mcp-ffmpeg) | 0 | 2026-03-11（3 commits） | 只 4 个工具 |
| [chandler767/mcp-video-editor](https://github.com/chandler767/mcp-video-editor) | 5 | 未实测 | Go 写的 |
| [studiomeyer-io/mcp-video](https://github.com/studiomeyer-io/mcp-video) | 5 | 未实测 | 面向「网页录制成营销视频」+ Playwright |

（以上 star 数为搜索快照，标 **未实测** 的表示本次未从 API 取到，不编数字。）

### 1.3 官方 MCP 注册表（实测）

`registry.modelcontextprotocol.io` 搜 `video` / `ffmpeg`：

- **被 AI 生成 SaaS 淹没**：`ai.makeaivideo/video-generator`、`app.filmee/anime-video`、`ai.tegas/video`、`com.automatedvideoapp/mcp`、`ai.videozero.engine/mcp`… 全部是「一句话生成营销短视频」，与本项目无关。**实测**
- 云转码类：`com.ffmpeg-api/ffmpeg`、`com.ffmpeg-micro/mcp-server`、`io.github.hifarrer/ffmpegapi`、`com.contenta-software/videorecompress`（2026-10-02，Windows H.265/AV1 GPU 压缩）、`com.contenta-software/ai-video-enhancer`（2026-10-02）。都是把素材传上云。**实测**
- 人脸打码类扎堆：`com.dyndns-server.noon-ai/video-anonymization-mcp` 等一堆同源条目。**实测**
- **本地视频分析类：注册表里几乎是空的。** 唯一一条真正本地、质量过硬的是 **`io.github.KyaniteLabs/kinocut`**：
  ```json
  {"name":"io.github.KyaniteLabs/kinocut","version":"1.16.0","status":"active",
   "publishedAt":"2026-10-03","packages":[{"registryType":"pypi","identifier":"kinocut",
   "runtimeHint":"uvx","transport":{"type":"stdio"}}]}
  ```
  **实测**（`/v0/servers/io.github.KyaniteLabs%2Fkinocut/versions/latest`）

### 1.4 官方 `modelcontextprotocol/servers` 里的 ffmpeg

- `modelcontextprotocol/servers-archived`：303 star，**已于 2025-05-28 归档**（`archived: true`，最后 push 2025-05-28）。**实测**
- 那个仓库里 `src/ffmpeg/README.md` 现在 **404**，路径已被移除。**实测**
- 结论：**官方没有在维护的 ffmpeg MCP**。**实测**

### 1.5 安装方式与 Windows

| 工具 | 安装 | Windows |
|---|---|---|
| kinocut | `pip install kinocut` / `claude mcp add kinocut -- uvx --from kinocut kino`；PyPI + 官方注册表 | **文档**声明 1.15.0 起「first-class Windows MCP」；但 `llms.txt` 的 Install 段只给了 `brew`/`apt`。**部分未验证** |
| mcp-video-analyzer | `npx mcp-video-analyzer@latest`（Node 22.12+）；`npx skills add` 装 Agent Skill | **文档**有 `%APPDATA%` 配置路径与 `%LOCALAPPDATA%` 缓存说明；**Windows 有一等支持描述** |
| FableCut | 浏览器打开，零依赖 | 浏览器即可，**平台无关** |
| WeftCut | 未取到 README（多次传输失败） | **文档**自述「macOS, Windows and Linux」 |
| openshorts | Docker 自托管（需 GPU） | **推断** Docker Desktop 可跑，但本项目已有原生工具链，引入 Docker 是净负担 |

---

## 2. 有没有「多媒体分析」这个类别？

- **有，但不是官方类别，是社区惯例。** `punkpeye/awesome-mcp-servers`（**95,837 star**，最后 push 2026-09-27）设有
  `### 🎥 Multimedia Process` 分类。**实测**
  本次完整枚举该节，共 **74 条**，摘录与本项目沾边的：
  `KyaniteLabs/kinocut`、`guimatheus92/mcp-video-analyzer`、`ronak-create/FableCut`、`mutonby/openshorts`、
  `DareDev256/fcpxml-mcp-server`、`WeftCut/WeftCut`、`tydude001/proofcut`、`clipkit-video/clipkit`、
  `realcrabcut/crabcut-mcp-server`、`editmamei/editmamei`、`1000ri-jp/atsurae`、`mordor-forge/gemini-media-mcp`、
  `legolev/mediamcp`、`keiver/image-tiler-mcp-server`、`haljishi/vidwords-mcp`、`mutonby/openshorts`、
  `tandryukha/aidemo`、`sunriseapps/imagesorcery-mcp`、`woladi/macos-vision-mcp`（macOS only，排除）、
  `burningion/video-editing-mcp`、`samuelgursky/davinci-resolve-mcp`、`flamexnreal/davinci-resolve-ai-bridge-mcp`、
  `AetherWave-Studio/aetherwave-mcp`、`musevate/MCP`、`a-y-ibrahim/after-effects-mcp`、
  `TwelveTake-Studios/reaper-mcp`、`xDarkzx/Reaper-MCP`、`gif-creator-mcp`、`zapcap-mcp-server`、
  `loudcheck`、`runcomfy-com/runcomfy-mcp`、`AIDC-AI/Pixelle-MCP`、`strato-space/media-gen-mcp`、
  `WaveSpeedAI/mcp-server`、`topaz-mcp`、`stass/exif-mcp`、`aetherwave-mcp` …
- 同一清单另有独立的 `🎙️ Speech-to-Text`、`🔊 Text-to-Speech`、`🎙️ Podcasts` 分类。**实测**
- **Anthropic 官方 connectors 目录：未找到。**
  `docs.claude.com/en/docs/agents-and-tools/mcp-connector` 返回 **「App unavailable in region」**（地域屏蔽），
  `claude.com/marketplace/connectors-plugins` 同样取不到。**未验证**——不能断言官方有/没有媒体类 connector。
  只能说：**没有可被本项目直接消费的官方媒体 connector**。
- 官方 MCP 注册表**不暴露分类体系**，搜索结果无媒体分类维度。**实测**

---

## 3. opencode 生态有没有媒体类 skill / 插件 / MCP？

**没有。**

- `opencode.ai/docs/ecosystem/`（页面自报 **Last updated: Oct 3, 2026**）完整枚举：**40 个插件、12 个项目、2 个 agents 集合**。
  逐条看过，**零个**与视频/媒体/ffmpeg 相关——全是 auth（gemini/antigravity/openai-codex）、token 注入、上下文裁剪、
  通知、LSP/AST、后台 agent、firecrawl/tavily 抓取、worktree 编排。**实测**
- opencode **本身支持 MCP**（local stdio + remote streamable-http/OAuth），配置在 `opencode.json` 的 `mcp` 块。**实测（文档）**
- 本项目当前 `opencode.json` 内容实测只有：
  ```json
  { "$schema": "https://opencode.ai/config.json", "skills": ["./skills"] }
  ```
  **尚未配置任何 MCP。实测**
- 社区有一个「按 skill 挂 MCP」的插件 [unphased/opencode-skill-mcp](https://github.com/unphased/opencode-skill-mcp)
  （`skill_mcp`，读 SKILL.md 旁的 `mcp.json`，只暴露当前会话已加载 skill 的 MCP）。
  对本项目有意义——可以做到**只在 `naraka-highlight-studio` 被加载时才挂视频 MCP**，避免工具常驻吃上下文。
  仓库存在与功能描述 **实测（README）**；opencode 上的实际行为 **未实测**。
- **Windows 注意（实测，官方文档）**：opencode 官方明确「While OpenCode can run directly on Windows, we recommend WSL」。
  本项目跑**原生 Windows**。原生 Windows + 中文项目路径 + `npx`/`uvx` 拉起的 stdio MCP 子进程，是明确的额外风险面。
  （本项目已经因为中文路径乱码吃过一次 BLOCKER 级事故，见 AGENTS.md §1。）

---

## 4. 对「抽帧 + 判读」环节到底有没有帮助？

这是本项目最值钱的问题，逐层拆开答。

### 4.1 没有任何主流 MCP 做「服务端语义判读」——**实测 + 文档**

逐个看它们的工具定义，规律完全一致：**抽帧 → 把 base64 图塞进 MCP 响应 → 交给 Agent 自己看**。

| 服务器 | 抽帧 | 转写 | OCR | 元数据 | **服务端 VLM 判读** |
|---|---|---|---|---|---|
| mcp-video-analyzer | ✅ 场景变化去重，1–60 帧 | ✅ 字幕/Whisper，认 sidecar `.vtt` | ✅ Tesseract | ✅ | ❌ |
| kinocut | ✅ | ✅（可选 Whisper） | – | ✅ | ❌（见 4.4） |
| popcorn | ✅ 场景切换 | ✅ 4 种后端 | – | ✅ | ❌（已停更） |
| mcp-deep-video | ✅ + 运动检测 + 热力图 | ✅ | – | – | ❌（已停更，1 star） |
| video-vision-mcp tier 1/2 | ✅ | ✅ | – | ✅ | ❌ |

它们省掉的是**抽帧循环**，不是**判读**。这正好对应 AGENTS.md §4 的警告：
「自动标签只是筛选信号，不能单独证明『振刀、反杀、拆火』发生」。这些工具产出的仍然是自动标签。

### 4.2 唯一真正「一次调用就判读」的：`KitDevUA/video-vision-mcp` tier 3 —— 但不可信

- **文档**（PyPI README 原文）：「**native Gemini** — `GEMINI_API_KEY` — **Gemini ingests the whole video (visual + audio) in one call, with MM:SS timestamps.** Default when the key is set.」
  优先级 Gemini > OpenAI > Groq > 本地。工具：`analyze_video` / `get_video_transcript_only` / `extract_frames_at` / `list_recent_analyses`。
  版本 0.5.1，2026-08-06 发布。**实测（PyPI JSON API）**
- 但：**0 star、0 fork、单一作者、创建 2026-06-30、最后 push 2026-08-11**——已两个月无提交。**实测**
  6 个版本全部集中在 2026-06-30 → 2026-08-06 的五周内爆发。典型「一个人周末项目」。
- 另外三条硬伤：
  1. 要 `GEMINI_API_KEY`，**4K 素材要上传 Google**——与本项目 local-first 基线冲突；
  2. Gemini 有视频时长/体积上限，4K60 整局素材能否整段摄入**未验证**；
  3. 判读质量不可控，AGENTS.md §8.1 的整场战斗判据（「洞只许落在窗口外」）远超出通用 VLM 的稳定能力。

**判定：不装。**

### 4.3 ⚠️ 一个可能判死整类工具的风险（必须先测）——**推断，附实测证据**

MCP 规范里工具结果可以是 `ImageContent`（内联 base64 图片）。上面一半的服务器
（mcp-video-analyzer、popcorn、video-vision-mcp tier1/2）**全靠这个把帧送进上下文**。

- **实测**：opencode 的 MCP 客户端源码 `packages/opencode/src/mcp/index.ts`
  （经 jsDelivr 镜像 `anomalyco/opencode@dev` 取得，2026-10-05）中
  `"image"` / `"Image"` **出现次数 = 0**。该文件里也没有 `CallToolResult` 的内容分片转换逻辑。
- **实测**：`opencode.ai/docs/mcp-servers/` 全文只讲 token 占用与配置，**一个字都没提图片内容**。
- **推断（未实测）**：opencode 大概率**不把 MCP 的 `ImageContent` 送进模型上下文**。
  若成立，则所有「返回内联关键帧」的 MCP 对本项目**完全无效**——工具会正常返回、退出码 0、
  但 Agent 什么也看不见，而且**不会报错**。这是最坏的一种失败：静默失效。

**→ 装任何东西之前，先做这个冒烟测试（见 §7）。**

### 4.4 kinocut 自己承认「判读」没做 —— 实测

kinocut.dev 路线图原文（实测抓取）：

> **human-gated 门禁**
> The watching guardrail remains next. Metric, **vision**, and **narrative checks** that propose
> bounded fixes and wait for human approval **remain explicitly gated. The project does not claim
> this phase shipped.**

即：视觉/叙事检查**明确还没发布**。所以即便装了 kinocut，判读环节还是本项目自己的活。
它给的是**编辑面 + 审计面**，不是判读面。

### 4.5 真正沾边的两个小工具，以及为什么仍然不装

- **[keiver/image-tiler-mcp-server](https://github.com/keiver/image-tiler-mcp-server)**：把大图切片，
  防止视觉模型降采样丢细节。3 star，最后 push 2026-03-07。**实测**
  → 对 AGENTS.md §9 的 50 张红线**方向对**，但本项目已经有 `scripts\make_contact_sheet.ps1`
  （拼联系表，一张算 1 张）和 `scripts\check_image_budget.ps1`（分轮计划）。**未解决新问题。**
- **[mutonby/openshorts](https://github.com/mutonby/openshorts)**：6102 star / 1368 fork，本类最热，
  「AI moment detection」听上去对口。**但**：面向**口播长视频转 9:16 竖版短视频**，要 Docker + GPU，
  **默认烧录字幕**——直接撞 AGENTS.md §5「禁烧录禁内嵌」。**判定不装。**

### 4.6 企业级方案存在但完全不适用 —— 文档

NVIDIA VSS 提供 `video_understanding` 工具（`vlm_name: cosmos3_nano_reasoner`、`max_frames`、`min_pixels`/`max_pixels`）
与 VA-MCP Server（`nat mcp serve`），确实是 VLM 逐帧判读。**实测（docs.nvidia.com 文档内容）**
但它是为**监控摄像头 + Elasticsearch 事件库**设计的 Docker/K8s 微服务栈（必需索引 `incidents-*`、`vlm-incidents-*`、
`frames-*`、`calibration-*`），吃 NVIDIA AI Enterprise 授权。**不适用于本地 4K 游戏录屏。**

---

## 5. 成本与可靠性

| 服务器 | 维护状况（实测） | 判断 |
|---|---|---|
| **kinocut** | 唯一进官方 MCP 注册表（1.16.0，status active，2026-10-03）；6.5 个月 563 commits；186★/42 fork/10 open issues；版本节奏约每几天一个；站点 + docs + `llms.txt` + Agent Skill 齐全 | 本类**唯一**有产业级投入的 |
| mcp-video-analyzer | 71 commits / 3.5 个月；86★/16 fork/5 issues；单人维护；昨天还在推 | 健康但单人 |
| openshorts | 6102★/1368 fork，活跃 | 星多 ≠ 合用 |
| FableCut | 3 个月 701★/74 fork，活跃 | 增长快 |
| WeftCut | 54★，**今天还在推** | 早期 |
| proofcut | **创建才 3 周**（2026-09-11），4★，今天还在推 | 太新，不托付 |
| video-vision-mcp | **0★0 fork**，2 个月无提交 | 单点故障 |
| popcorn / ipythonist / mcp-deep-video / atsurae | 全部 2026-02～03 创建后停更 | 已死 |

**共性风险（实测归纳）**：

1. **单人维护是本类常态。** 除 openshorts 外，活跃的那几个都是 1 人项目。作者一旦停手，项目没有任何缓冲。
2. **1.x 改名史。** kinocut 在 1.7.0 从 `mcp-video` 改名，PyPI 上还留着 `mcp-video 1.6.15` 兼容 shim
   （会装到 kinocut 1.16.0）。**文档实测**——依赖名会漂。
3. **缓存目录不在项目里。** mcp-video-analyzer 的帧默认落 `%LOCALAPPDATA%\mcp-video-analyzer\<hash>\` 且
   **不会自动回收**；video-vision-mcp 落 `~/.cache/video-vision-mcp/`。
   → **直接违反 AGENTS.md §1「全部派生文件只许落 `123\<编号>.<素材文件名>`」。** 装的话必须逐个改指到任务目录。
4. **FFmpeg 路径。** 本项目 FFmpeg 在 `…\LosslessCut\resources\ffmpeg.exe`，**不在 PATH**
   （AGENTS.md §2 明令禁止硬编码、必须运行时解析）。而 kinocut 文档要求「FFmpeg on PATH」，
   `llms.txt` 的 Install 段只给 `brew`/`apt`。**在原生 Windows 上怎么喂对路径，未验证。**
5. **字幕工具默认烧录。** kinocut / openshorts 的 caption 工具面向烧录。本项目 §5 禁烧录禁内嵌。
   → 即便装，也只能当作**参数生成器**，不能让它碰成片。
6. **4K60 NVENC 主链路没人做。** 本项目已验证的方案是 H.264 NVENC / 3840×2160 / 60fps / VBR≈18Mbps /
   峰值 28Mbps（AGENTS.md §6）。这些 MCP 没有一个提供这条参数路径，**成片渲染仍必须自己写**。

---

## 6. 结论：值得装几个？

### 值得装：**1 个，上限 2 个。**

**P0 · 先做这个，别先装（15 分钟）**
冒烟测试：验证 opencode 是否把 MCP 的 `ImageContent` 送进模型上下文。
这一步决定后面全部结论——若不支持（§4.3 的推断成立），**一个都别装**。

**P1 · 最值得装的 1 个：[KyaniteLabs/kinocut](https://github.com/KyaniteLabs/kinocut)**
理由（全部实测）：
- 本类**唯一**在官方 MCP 注册表里 status=active 的本地视频服务器（1.16.0 / 2026-10-03）；
- Apache-2.0，local-first，零遥测，零 API key（核心功能）；
- 唯一有**审计血统**的：每次工作流产出 `video_receipt.json`（意图 / 调用了哪些工具 / 哪些护栏触发 /
  哪些还需人眼 / 输入输出 sha256）。这跟本项目 `reports\` 的「谁核过、为什么留」诉求几乎一一对应；
- **preflight 护栏**：越界滤镜、不兼容合并、坏音频映射在 FFmpeg 渲第一帧之前就被拦下并解释。
  本项目历史上多个脚本硬编码路径炸掉的教训，正对应这个；
- **质量门禁**：VMAF / 响度 / 黑帧 / 音画同步评分 + release checkpoint；
- **它带一个 Agent Skill**（`skills/kinocut/SKILL.md`）→ 可以**直接丢进本项目现有 `skills\` 机制**，
  一次 MCP 配置都不用改。这对本项目是最省摩擦的接法。

**但必须先认清它的边界（实测）**：
- ❌ **不做语义判读**（路线图原文：vision/narrative checks 明确 gated，未发布）；
- ❌ **不做 4K60 NVENC 主渲染**；
- ⚠️ Windows 声明只在路线图里，install 文档没给 Windows 步骤，FFmpeg 路径喂法未验证；
- ⚠️ 它面向「本地访谈 → 竖版字幕片段」，本项目是「整场战斗连续保留」，场景不完全对口。

**它真正替代的是**：本项目手写的 ffmpeg 调用与参数校验，以及一部分手写的审计记录。
**它替代不了的是**：判读、整场战斗策略、4K 主渲染、禁烧录纪律。

**P2 · 备选：`guimatheus92/mcp-video-analyzer`** —— 只在 P0 测试通过**且**确实嫌抽帧循环啰嗦时再考虑。
必须先把 `MCP_CACHE_DIR` 指到任务目录，否则违反路径铁律。
它对本项目真正的增量价值其实只有一条：**认 sidecar `.vtt`**——可以在本项目已有 faster-whisper 产出的
SRT 旁边放一份 VTT，让 MCP 免跑一次 Whisper。这是加分项，不是决定项。

**明确不要装**（附理由）：

| 不装 | 理由 |
|---|---|
| `mutonby/openshorts` | 默认烧录字幕（撞 §5）+ 竖版口播场景不对 + 要 Docker/GPU |
| `KitDevUA/video-vision-mcp` | 0★0 fork、2 个月无提交、要把 4K 素材上传 Google |
| `ronak-create/FableCut` / `WeftCut` | 浏览器/桌面编辑器，出不了 4K60 NVENC 主片；只能当审片 UI，价值有限 |
| `DareDev256/fcp-mcp-server` | 写 FCPXML 需要装 Final Cut Pro，本项目不用 FCP |
| `mrbuslov/capcut-ai-editor` | 绑定 CapCut 工程、口播去停顿，与本项目形态不符；且**原地改工程无备份** |
| `keiver/image-tiler-mcp-server` | 已被项目现有 `make_contact_sheet.ps1` 覆盖 |
| popcorn / mcp-deep-video / ipythonist / atsurae | 已停更 |
| NVIDIA VSS | 监控场景 + ES + K8s + 企业授权，不适用 |

**未找到（明确标注，不编）**：

1. ❌ **没有**找到能「一次调用完成抽帧 + 语义判读」且面向**本地 4K 游戏录屏**的 MCP。
2. ❌ **没有**找到 opencode 官方或社区维护的媒体类 skill / 插件 / MCP 集成。
3. ❌ **没有**找到 Anthropic 官方的「多媒体分析」connector 类别（地域屏蔽，**未验证**，不能断言不存在）。
4. ❌ **没有**找到官方在维护的 ffmpeg MCP（官方 servers 仓库已归档，原路径 404）。
5. ❌ **没有**找到提供 4K60 NVENC 主渲染参数路径的视频 MCP。

---

## 7. 建议的下一步（可执行）

```text
1. 冒烟测试（15 min，不装任何东西到项目里）
   - 临时起一个最小 stdio MCP，工具返回一个 1×1 PNG 的 ImageContent
   - 在 opencode 里调用，看模型是否「看见」这张图
   - 看不见 → 本报告 §4.3 成立，一个 MCP 都不用装，把结论写进 docs\lessons\POOL.md

2. 若通过 → 只装 kinocut，且只装 Skill 不装 MCP（最小摩擦）
   - 拷 skills/kinocut/SKILL.md 进本项目 skills\
   - FFmpeg 绝对路径按项目铁律运行时解析后注入，不写死
   - 只把它当「参数校验器 + receipt 生成器」，成片仍走 scripts\ + verify_master.sh

3. 若要装 MCP → 写进 opencode.json 的 mcp 块，并用 unphased/opencode-skill-mcp
   之类的机制做到「只在 naraka-highlight-studio 加载时才挂载」，避免常驻吃上下文
```

---

## 附：本次用到的检索入口

- GitHub REST：`api.github.com/repos/*`（部分时段 403 限流）
- GitHub 代理：`ungh.cc/repos/*`（限流时替代）
- 官方 MCP 注册表：`registry.modelcontextprotocol.io/v0/servers?search=` 与 `/versions/latest`
- 社区清单：`punkpeye/awesome-mcp-servers` README `Multimedia Process` 节（jsDelivr 镜像，完整 74 条已枚举）
- opencode：`opencode.ai/docs/mcp-servers/`、`opencode.ai/docs/ecosystem/`、`opencode.ai/docs/windows-wsl`、
  `cdn.jsdelivr.net/gh/anomalyco/opencode@dev/packages/opencode/src/mcp/index.ts`
- PyPI：`pypi.org/pypi/video-vision-mcp/json`
- 产品站：`kinocut.dev`、`kinocut.dev/llms.txt`
- 文档站：`docs.nvidia.com/vss/...`（Video-Analytics-MCP Server、Agent Configuration）

> 注：本次 `websearch` 工具在中途开始返回 `HTTP 401`（认证失败），后半程全部改用
> `webfetch` + 直接 fetch 完成取证。`docs.claude.com` 与 `claude.com/marketplace` 因地域屏蔽取不到，
> 相关结论已标注为**未验证**而非「不存在」。
