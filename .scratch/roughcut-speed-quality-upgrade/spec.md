# Spec: 粗剪提速保质升级（零安装约束）

## Goal
把 40 路调研整合结论落地为可执行的仓库升级：在零安装约束（不装 torch/不下 turbo、无新增依赖）下，让粗剪从 2-3 小时进入可信时间表（有缓存 30 分钟快览 / 无缓存 60 分钟快览 + 90-120 分钟可审预览），同时用门禁把小错拦在冻结前。用户原话两条：产出质量不稳定、小错误多；剪辑太慢，下指令后要最快拿到剪好的视频。

## Anchors
- `AGENTS.md :: 项目级工作规则`
- `docs/WORKFLOW.md :: 标准视频剪辑工作流`
- `docs/TOOLS.md :: 工具基线与固定入口`
- `skills/naraka-highlight-studio/SKILL.md :: Required workflow`
- `skills/naraka-highlight-studio/references/complete-combat-roughcut.md :: 第三层执行流程`
- `skills/naraka-highlight-studio/references/roughcut-launch.md :: 并行编排`
- `skills/naraka-highlight-studio/references/deliverables-and-qa.md :: Quality gates before delivery`
- `skills/naraka-highlight-studio/scripts/validate_combat_timeline.py :: main`
- `skills/naraka-highlight-studio/scripts/validate_delivery.py :: main`
- `skills/naraka-highlight-studio/scripts/build_batch_manifest.py :: stable_id`
- `scripts/check_video_environment.ps1 :: Write-Check`

## Non-goals
- 不安装任何 Python 包，不下载 turbo/SenseVoice/YOLO/CLIP/Qwen-VL 模型（Phase3-01 已判本周不可行，需用户另行审批）。
- 不改动 `.video-tools` 内虚拟环境二进制与已安装包。
- 不重跑任何历史任务的转写与渲染，不碰 `E:\OBS` / `E:\PR导出` 源片。
- 不引入 BGM 自动榜单/TTS/竖屏重构/全自动母带（Phase3-05 已判暂缓）。

## Slices（Lane B，5 票，blocker 在前）
1. `01-qa-gate-script`：新增 `skills/naraka-highlight-studio/scripts/qa_gate.py`，把 12 项门禁做成唯一可执行入口（Phase2-05 + Phase3-02 三处补齐 + Phase4-05 验证口径）。
2. `02-manifest-content-hash`：`build_batch_manifest.py` 缓存 key 与文件名解耦（内容指纹优先，路径/mtime 只作展示），解决改名挪目录即失配（Phase4-09）。
3. `03-time-budget-sop`：新增 `references/time-budget.md`，写入可信时间表 + 全局时钟熔断 + cache-miss 早退（Phase3-03 + Phase4-06）。
4. `04-multiagent-contract`：`roughcut-launch.md` 补 Supervisor 单写者 + 1+2~3 配比 + token 纪律（Phase3-04 + Phase4-07）。
5. `05-subtitle-delivery-gates`：`validate_delivery.py` 补字幕哈希互斥 + `validate_combat_timeline.py` 补 Proxy-Source 映射校验口径（Phase4-03/05/08）。

## Checks
- 复查：`qa_gate.py --help` 可运行；fixture 时间线实跑 pass/fail 各一例。
- 复查：manifest 对同一文件改名/挪目录前后 id 一致（或有内容 hash 字段一致）。
- 复查：四文件锚点（time-budget 索引 / 单写者 / 字幕互斥 / 映射校验）可 grep 命中。
- 验证：`validate_combat_timeline.py` fixture 仍 pass；`validate_delivery.py` 对 `123/2.839...` 目录仍可用；`check_video_environment.ps1` 只读通过。

## Glossary
- 快览：不可冻结的 30/60 分钟中间预览，只用于早看早反馈，不送审。
- 可审预览：走完冻结五门 + streak 规则、可送用户的 720p 预览。
- 冻结三件套：同 N 的 combat_episodes + program_map + validate JSON。
- 单写者：台账只指挥写，时间线与合并决策只修线员写。
- cache-miss 早退：缺模型/缺显存/NVENC 占满时记缺口出降级清单，不重试不安装。

## Notes
- Skills called: ask-matt（T0，通用路由文档，无 lane 裁决，按 prelane 自判走 Lane B）。
- 现状基线：venv 有 faster-whisper 1.2.1/scenedetect 0.7.1/auto-editor 29.3.1/ctranslate2 4.8.1/librosa 0.11.0/otio 0.18.1 + cv2，无 torch/funasr/ultralytics/transformers/PIL；模型缓存仅 tiny/small/medium/large-v3；FFmpeg 9.0 链接与目标均 PASS；validate fixture 实跑 pass。
- e1-e5 已合入正文（merge_log_e），本次只做参数升级与新增小节，不覆盖 d1-d3。
