# 01 — 可执行预检：让自检真的会红

Status: resolved
Slice: 1
Blocked by: —

## 落地结果（2026-09-29）

`scripts/check_video_environment.ps1` 已重写并实跑验证：

- 解释器判据改为**实执行 + 哨兵**（`PREFLIGHT_PY_SENTINEL_OK`）。跑不出哨兵即判 BLOCKER。
- 实测退出码 **2**（期望值），`SUMMARY: ok=4 warn=3 blocker=1`，`ready=false`。
- BLOCKER 文本点名根因：`venv base interpreter is MISSING (was): ...\codex-runtimes\...\python`。
- 修复两个实跑才暴露的缺陷：
  - `$home` 撞 PowerShell **只读自动变量 `$HOME`**，抛异常导致根因 hint 永不触发 → 改名 `$homeLine`。
  - 解释器候选顺序原为 PATH 优先，会选中 WindowsApps 商店占位符并**掩盖根因** → 改为项目 venv 优先、PATH 垫底。
- 只读性复查（大小写敏感，排除 `WinGet` 目录名误报）：**CLEAN**，无 pip/Install-/New-Item/Remove-Item/Invoke-WebRequest。
- 新增 `-Json` 机器可读输出与分级退出码（0 ready / 2 blocked）。

## 问题

`scripts/check_video_environment.ps1` 是所有工作窗口的启动第一步，但它今天**无法发现最关键的故障**：

- L30 只用 `Test-Path` 判断 `python.exe` 存在 → 存在即 PASS。
- L44-60 才尝试执行解释器；失败时走 L59 `Write-Check ... $false ...`，但**漏了 `-Required`**，因此不置 `requiredOk=false`。
- 结果：只要 FFmpeg 那两项凑巧通过，脚本会在解释器根本起不来的情况下打印 `Environment baseline is present.` 并 `exit 0`。

今天的实测正是如此：venv 的 27 个 shim 都在、`Test-Path` 全过，报 `[PASS] canonical Python`，实际解释器无法启动。

## 目标

预检必须**以「能不能真的跑」为判据**，而不是「文件在不在」。

## 动作

1. 解释器判据改为**实执行**：跑一条最小 Python 片段（打印版本号 + 关键包版本）。能跑 = PASS；跑不了 = **BLOCKER，置 `requiredOk=false`**。
2. 退出码分级：
   - `0` = 可开工（无 BLOCKER）
   - `2` = 存在 BLOCKER（可开工但有降级项 / 不可开工）
   - `1` = 脚本自身无法完成检查
3. 输出末尾固定打印 `SUMMARY: ok=N warn=N blocker=N` 与 `BLOCKERS:` 列表，便于机器消费与人读。
4. 保持**只读**：不 pip、不建环境、不下载、不删改任何文件（AGENTS.md §3）。
5. 保留原有全部检查项与文案风格，新增的用 `BLOCKER` 状态词而非 `WARN`。

## 验收

- 今天这台机器上运行 → **必须非零退出**，且 Python 出现在 `BLOCKERS:` 里。
- 旧的真·只读性质保持：脚本内不得出现 `pip`、`Install`、`New-Item`、`Remove-Item`、`Invoke-WebRequest`。

## 备注

今天必须红，这是回归基线。修好之后如果还绿，说明判据没生效。
