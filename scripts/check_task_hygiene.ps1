<#
    check_task_hygiene.ps1  --  task-directory hygiene gate.

    A task directory must not accumulate loose weight at its root, and must not
    keep more than two versions of the preview or the timeline.  Violations are
    hard failures; shot-frame residue is reported as INFO only, because those are
    deliberately kept until the freeze gate clears them.

    Exit codes:
      0  clean (no hard violations; INFO-SHOT rows may still be printed)
      1  hard violations present
      2  task dir not found

    NOTE: rebuilt 2026-09-29 after an editing accident truncated the previous
    file to 3 bytes (no backup existed).  Behaviour is reproduced from the
    documented spec, the original grep-level line inventory, and the recorded
    output of task 849; it is not a byte-for-byte recovery.
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$TaskDir
)

$ErrorActionPreference = 'Continue'

Write-Output "TaskDir: $TaskDir"

if (-not (Test-Path -LiteralPath $TaskDir -PathType Container)) {
    Write-Output ("[FAIL] task dir not found: {0}" -f $TaskDir)
    exit 2
}

# NB: keep this file saved as UTF-8 WITH BOM.  PowerShell 5.1 decodes a BOM-less
# file with the ANSI code page, which turns every non-ASCII char in these
# messages into mojibake.  Worse, if a *path* literal ever goes mojibake like
# this, the script writes to a garbage directory instead of the real one.
# See docs/TROUBLESHOOTING.md -> 脚本里的中文全变乱码.

$violations = New-Object System.Collections.ArrayList

# --- 1. 任务根散文件：jpg/mp4/srt 必须为 0（§2.7 全部落子目录）--------------
$rootLoose = @(Get-ChildItem -LiteralPath $TaskDir -File -Force -ErrorAction SilentlyContinue |
               Where-Object { $_.Name -match '\.(jpg|jpeg|png|mp4|srt)$' })
foreach ($f in $rootLoose) {
    [void]$violations.Add(("ROOT_LOOSE:{0}" -f $f.FullName))
}

# --- 2. 0 字节日志/清单：多为误当成"应该删的 log"（Mid-run cleanup）----------
$zeroLogs = @(Get-ChildItem -Recurse -LiteralPath $TaskDir -File -Force -ErrorAction SilentlyContinue |
              Where-Object { $_.Length -eq 0 -and $_.Name -match '\.(log|txt)$' })
foreach ($f in $zeroLogs) {
    [void]$violations.Add(("ZERO_BYTE:{0}" -f $f.FullName))
}

# --- 2b. timeline\ 只放时间线数据：图片/视频属于 shots\，放错就永远删不掉 ------
# 起因：18.860 把 2351 张取证帧（667.8 MB）写进了 timeline\evidence_v*\。因为 timeline\
# 是收尾清理的"保留项"，这 614 MB 永远不会被回收，任务目录再也瘦不下来。
# 取证帧的唯一正确位置是 shots\。这里判硬违规，不只是提示。
$tlRoot = Join-Path $TaskDir 'timeline'
$tlStray = @()
if (Test-Path -LiteralPath $tlRoot -PathType Container) {
    # Only media is a violation.  Build scripts (.py/.ps1) and notes under
    # timeline\evidence_v*\ are legitimate task evidence -- a previous revision of
    # this check flagged them too, which was wrong.
    $tlStray = @(Get-ChildItem -Recurse -LiteralPath $tlRoot -File -Force -ErrorAction SilentlyContinue |
                 Where-Object { $_.Extension -match '^\.(jpg|jpeg|png|gif|bmp|webp|tif|tiff|mp4|mkv|mov|webm|avi)$' })
    foreach ($f in $tlStray) {
        [void]$violations.Add(("MISCABLED_TIMELINE:{0}  (取证帧/媒体应放 shots\,不是 timeline\)" -f $f.FullName))
    }
}

# --- 3. 旧预览：只留相邻两版（vN-1 及更早判 STALE_PREVIEW）--------------------
$pvNums = @(Get-ChildItem -LiteralPath (Join-Path $TaskDir 'preview') -File -Force -ErrorAction SilentlyContinue |
            ForEach-Object {
                if ($_.Name -match '-review-v(\d+)\.mp4$') { [int]$Matches[1] }
                elseif ($_.Name -match '-review-v(\d+)\.') { [int]$Matches[1] }
            } | Sort-Object -Unique)
$staleNums = $pvNums | Select-Object -SkipLast 2
foreach ($n in $staleNums) {
    [void]$violations.Add(("STALE_PREVIEW:*-review-v{0}.mp4(+concat/decode)" -f $n))
}

# --- 4. 旧时间线：只留相邻两版（vN-1 及更早判 STALE_TIMELINE）------------------
$epNums = @(Get-ChildItem -LiteralPath (Join-Path $TaskDir 'timeline') -File -Force -ErrorAction SilentlyContinue |
            ForEach-Object {
                if ($_.Name -match 'combat_episodes_v(\d+)\.json$') { [int]$Matches[1] }
            } | Sort-Object -Unique)
$staleNums = $epNums | Select-Object -SkipLast 2
foreach ($n in $staleNums) {
    [void]$violations.Add(("STALE_TIMELINE:combat_episodes_v{0}.json" -f $n))
}

# --- 5. shots\ 零散取证帧：只提示，不判 FAIL -----------------------------------
# 散帧与 0 字节日志 / 旧预览 / 旧时间线不同，是"预计将来清理、当前预期存在"。
# 按 SHOT_STRAY 提示输出即可，整条 exit 0；不计入 violations。
$shotFiles = @(Get-ChildItem -Recurse -LiteralPath (Join-Path $TaskDir 'shots') -File -Force -ErrorAction SilentlyContinue)
$shotStray = @($shotFiles | Where-Object { $_.Name -match '^verify_.*\.md$' -or $_.Extension -eq '.ps1' -or $_.Name -match '^audio_.*\.log$' })
if ($shotStray.Count -gt 0) {
    Write-Output ("[INFO-SHOT] {0} stray file(s) under shots\ (freeze-later cleanups, not failures):" -f $shotStray.Count)
    foreach ($f in $shotStray) { Write-Output ("  " + $f.FullName) }
}

# --- 汇总 ----------------------------------------------------------------------

Write-Output ("Checks: root-loose/zero-byte/misplaced-timeline/stale-preview/stale-timeline (+shot-info)")
foreach ($v in $violations) { Write-Output ("  [VIOLATION] " + $v) }

if ($violations.Count -eq 0) {
    Write-Output "[PASS] hygiene clean (hard gates)."
    exit 0
}

Write-Output ("Total hard violations: {0} ([INFO-SHOT] rows above are freeze-later cleanups, not failures)" -f $violations.Count)
exit 1
