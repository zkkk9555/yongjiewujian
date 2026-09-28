# Spec: 全外挂字幕（预览与成片禁烧录禁内嵌）

## Goal
用户规则：所有视频不内嵌字幕，所有字幕全外挂，预览与成片一视同仁。现状缺口：成片已有“默认干净画面”规则（deliverables-and-qa.md §4K节），但预览仍保留“单层烧录版”选项（WORKFLOW.md §5/Agents §5/TROUBLESHOOTING），`--burned-subtitles` 烧录分支仍是合法路径。目标是把全链统一为全外挂、禁烧录、禁内嵌字幕流。

## Anchors
- `AGENTS.md :: 字幕规则`
- `docs/WORKFLOW.md :: 阶段 5：低清预览`
- `skills/naraka-highlight-studio/references/deliverables-and-qa.md :: 粗剪成片字幕规则`
- `skills/naraka-highlight-studio/scripts/qa_gate.py :: gate_burned_srt`
- `skills/naraka-highlight-studio/scripts/validate_delivery.py :: main`

## Non-goals
- 不改 `.video-tools` 环境，不重跑历史任务，不碰源片。
- 不改时间线判定、并行编排、冻结五门本身，只收紧字幕交付形态。

## Slices（3 票）
1. `01-docs-external-only`：AGENTS §5 / WORKFLOW §5-§7 / TROUBLESHOOTING / PROMPT_TEMPLATES / deliverables-and-qa / roughcut-launch 字幕员与验收 C 门统一为全外挂禁烧录。
2. `02-gate-no-burn`：qa_gate 烧录门改为禁烧录（任何烧录即 FAIL）+ MP4 零字幕流检查（ffprobe subtitle 流必须为 0）；validate_delivery `--burned-subtitles` 改为兼容残留参数（传了即按禁烧录判 FAIL，不再是合法分支）。
3. `03-regress`：fixture 回归 + 全量 py_compile + 任务目录零触碰确认。

## Checks
- 复查：全仓 grep“烧录版/单层烧录/burn-in 烧录选项”只剩历史教训与禁令表述，无合法烧录路径。
- 验证：含字幕流或烧录标记的交付实跑 FAIL；干净 MP4 + 外挂 SRT 实跑 PASS。
- 验证：旧 `--burned-subtitles` 调用不崩溃但判 FAIL（兼容不兼容错）。

## Glossary
- 全外挂：MP4 内零字幕流、零烧录像素字，字幕只以 SRT 外挂交付、播放器按需挂载。
- 干净画面：可再用的无字视频轨，不因字幕返工。
