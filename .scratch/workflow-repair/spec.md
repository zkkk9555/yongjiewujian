# Spec: 工作流修复（素材路径 → 完成粗剪）

> 管理窗口产出。本窗口不做任何视频剪辑、不渲染、不导出，只修工作流底座。
> 定位：让其他工作窗口「拿到一个素材路径就能跑完粗剪」，且第一步自检不再骗人。

## Goal

把「给一个素材路径 → 自动跑完整战斗粗剪」这条链路的**启动段**修成可信、可执行、单一真源：

1. 环境自检必须**真的执行**解释器，跑不起来就是硬失败，不许假绿。
2. 工具路径**动态解析**，不再指向已删除的 WinGet 符号链接。
3. 文档与提示词不再指示工人去执行已失效的操作。
4. 未修复项（Python 不可用）对用户可见、可决策，不静默降级。

## Anchors

- `AGENTS.md §2 已安装的共享工具基线`、§3 启动顺序
- `docs/TOOLS.md :: FFmpeg 和 FFprobe`
- `docs/WORKFLOW.md :: 阶段 0：环境检查`
- `scripts/check_video_environment.ps1`（L30 `Test-Path` 误判源、L59 缺 `-Required`）
- `docs/PROMPT_TEMPLATES_GOAL.md` L18、`docs/PROMPT_TEMPLATES_OPENCODE.md` L22（指示解析已删符号链接）
- `123/README.md` L41-43（任务编号漂移）

## 现状证据（2026-09-29 实测）

| ID | 缺陷 | 证据 | 是否阻断「路径→粗剪」 |
|---|---|---|---|
| D1 | 全机无可用 Python。venv 基础解释器随 `codex-runtimes` 缓存被清；PATH 上仅 WindowsApps 商店占位 stub | `pyvenv.cfg home=%USERPROFILE%\.cache\codex-runtimes\...\python.exe` → `Test-Path=False`；`~/.cache` 下只剩 `huggingface`/`opencode`；无任何 `C:\Python3xx` | **是**。faster-whisper / PySceneDetect / Auto-Editor 全部不可达，字幕不可用 |
| D2 | 文档指定的 FFmpeg 路径已整体删除 | `...\WinGet\Links` → `Test-Path=False` | **是**。所有探测/渲染命令指向空处 |
| D3 | 自检脚本检测不到 D1 | L30 只 `Test-Path`；L59 执行失败分支漏 `-Required`，只 WARN 不置 `requiredOk=false` | **是**。步骤 0 假绿，工人误以为环境可用 |
| D4 | 文档与两个提示词指示工人执行 D1/D2 的操作 | TOOLS.md §FFmpeg、两个 PROMPT L18/L22 | **是**。照做即进死胡同 |
| D5 | 两个提示词文件互为分叉且声明「等价」，harness 专属（`create_goal` / `subagent`），单文件内含 4 套模板（含标注「旧版保留」），并复述 skill 已有规则 → 必然漂移 | 两文件通读 | 部分。用户已宣布弃用 |
| D6 | 文档任务编号漂移 | `123/README.md` L41-43 写 11/12/13 在制，实存 12/13/14/15 | 否，但误导 |
| D7 | 根目录两处路径违规 | `t2.txt`(32B)、`14-review-v2.decode.log`(196B) | 否，但违反项目自订铁律 |

## Non-goals

- **不安装/修复 Python 运行时**（D1）。属 AGENTS.md §3 授权闸口 + 对外可见的网络下载，须用户明确批准。
- 不重跑任何既有任务、不动源素材、不渲染任何视频。
- 不重写提示词正文（用户已明确「之后会让我重写」）。本轮只标弃用 + 指向。
- 不拆解既有 7 角色 / 5 门禁编排（e1–e5、g 升级成果），不擅自简化用户的工艺体系。
- 不删除任何文件（D7 只迁移，不删）。

## Slices

1. **可执行预检**（核心）：重写 `check_video_environment.ps1`，真执行解释器 + 动态解析 FFmpeg + 机器可读摘要 + 区分退出码。
2. **文档去漂移**：TOOLS.md / WORKFLOW.md / README.md / 123\README.md 修正死路径与错编号，启动段收敛为「单一预检真源」。
3. **提示词标记弃用**：两个 PROMPT 文件加显著弃用横幅，指向「启动契约」，不改正文。
4. **路径卫生**：根目录两处违规文件迁入对应任务目录，记账。

## Checks

- `check_video_environment.ps1` 在**解释器不可运行**的今天必须**非零退出**并把 Python 列为 BLOCKER（回归基线：今天必须红）。
- 修好 FFmpeg 解析后，脚本必须报出实际找到的 `ffmpeg.exe` / `ffprobe.exe` 绝对路径，而不是空的 Target。
- 脚本在解释器可运行的机器上必须转绿并打印包版本（正向验证，用可用的 python stub 或人工核对逻辑）。
- 全文检索：文档与提示词中不再出现「解析符号链接 Target」这类指向 WinGet Links 的指示。
- 根目录 `Get-ChildItem -File` 结果中不再有 `*.txt` / `*.log` 派生物。

## Glossary

- **预检（preflight）**：`scripts/check_video_environment.ps1`，任务启动第一步，只读，判定「本任务能不能开工」。
- **BLOCKER**：使粗剪无法进行的环境缺口，须用户决策（当前唯一：无可用 Python）。
- **降级（degraded）**：BLOCKED 时走视觉 + silencedetect/ebur128 兜底出无字幕预览；**不得**声称满足完整门禁。
- **启动契约**：AGENTS.md 中收敛后的启动顺序段落，唯一真源指向预检脚本。
