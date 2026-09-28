# 832跑通报告：问题清单（供工作流优化用）

Status: ready-for-agent
任务目录：`123/3.832永劫无间 2026-06-29 00-34-53`
源：`E:\PR导出\832永劫无间 2026-06-29 00-34-53.mp4`（4K60 H.264，1187.6s≈19.8min，视频约16.4Mbps，音频AAC 48kHz立体声，2.48GB，只读未动）
预览：`preview/review.mp4`（1280x720 30fps H.264+AAC，572s≈9.5min，约386MB，完整解码通过 exit 0）
候选：13 场 combat_episode，`timeline/combat_episodes.json` + `candidate_clips.csv` + `master.otio` + `premiere.xml` + `markers.csv`，`validate_combat_timeline` pass。

## 跑通中遇到的真实问题（按出现顺序）

1. **probe JSON 的 BOM**：`Out-File -Encoding utf8` 写出的 `source_probe.json` 带 BOM，
   项目 venv 外的系统 Python `json.load` 直接报错。已在任务内用 utf-8-sig 重写修复。
   → 优化点：工作流应规定 probe 落盘统一用 Python `json.dump`（无 BOM），或读取统一用 utf-8-sig。
2. **faster-whisper GPU 起不来（cublas64_12.dll not found）**：
   DLL 文件实际存在于 `.video-tools/venv/Lib/site-packages/nvidia/*/bin`，
   但 Windows DLL 搜索路径没配，`WhisperModel(device=cuda)` 直接 RuntimeError。
   已验证：启动前把三个 `bin` 目录 prepend 到 `PATH` 即可 `CUDA OK`；
   并把该逻辑沉淀进任务 `analysis/transcribe_audio.py` 头部，重跑后 177 段中文转写成功。
   → 优化点：这是本轮最大卡点。应把 PATH 修复做进共享入口
   （环境检查脚本提示 + 转写脚本模板头部 + TOOLS/WORKFLOW 文档），而不是每个任务各自踩一遍。
   任务 2 的转写当年能跑，说明当时 shell 的 PATH 恰好对，不能当成“环境没问题”的证据。
3. **PySceneDetect exe 无输出**：`.video-tools/venv/Scripts/scenedetect.exe`
   在当前 shell 下跑完无 stdout、无文件（exit 0 但无产物），原因未定位
   （疑似 exe 启动器在 Git Bash 下的输出/路径问题）。
   改用 `python -m scenedetect` 同参数一次跑通，437 场景。
   → 优化点：工作流应把 `python -m scenedetect` 定为首选入口，exe 只作备用；
   且 `list-scenes --output` 指向已存在的目录时会产生“目录里套文件”的结构
   （`analysis/scenes.csv/xxx-Scenes.csv`），应改为输出到明确文件路径或先建父目录。
4. **ffprobe/ffmpeg 混用笔误**：解码检查时误把 `-show_entries` 传给 ffmpeg。
   → 非工作流缺陷，但建议质检脚本化（`validate_delivery.py` 扩展解码检查项），减少手敲。
5. **转写内容噪声**：177 段中开局 8–90 秒是闲聊（24 岁/孩子话题），
   尾段 1128–1182 秒有一段 54 秒的“尼尔贝…”幻觉重复；
   战斗关键词命中仅 14 处（钟/拉我/大佛链最有价值）。
   → 优化点：转写后处理应加“长重复段幻觉过滤 + 开局闲聊标记”，避免污染候选。
6. **场景切点过密**：437 个场景，平均不足 3 秒一个，不能直接当战斗边界
   （符合 skill 预期：只作候选信号）。
   → 优化点：文档已写明，但建议在时间线生成脚本里显式忽略 <2 秒的纯切点，
   只保留音频/语音/画面三者对齐的候选。
7. **音频活动阈值偏宽**：31 个区间，最长 55 秒，最短 3 秒；
   722–815 秒 93 秒长间隙需人工抽查确认无战斗（已用缩略图抽查）。
   → 优化点：删除区间审计应强制要求“长间隙抽查记录”（已在本任务 `deleted_intervals` 落字）。

## 候选质量自评
- 高置信：combat_013（大佛决战，语音链完整）、combat_006（连续战斗合并）、
  combat_008（救援链）、combat_012（52 秒决赛圈前大战）。
- 9 个标 needs_review，等你审预览后按“延长/删除/补漏”模板反馈。
- 节目 572 秒对 19.8 分钟源，压缩比约 48%，符合“宁长勿断”的粗剪定位。

## 下一步（等你确认）
- 你审 `preview/review.mp4` 后，我按反馈改源时间线 → 重渲染预览 → 通过后再谈 4K。
- 工作流优化建议基于上面 7 条，另起一轮 autopilot 落地（共享转写模板 + probe 规范 + scenedetect 首选入口 + 质检脚本化）。
