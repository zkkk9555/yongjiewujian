<#
    sanitize_stray_dirs.ps1  --  remove the mojibake directories that this project
    accidentally created NEXT TO its own root instead of under 123\.

    Why this exists
    ---------------
    A .ps1 file saved as UTF-8 WITHOUT a BOM is decoded by PowerShell 5.1 with the
    ANSI code page (936 / GBK on this machine).  A Chinese project path in the source
    then turns into GBK mojibake, and any New-Item / Set-Content using that string
    builds its tree next to the real project:

        C:\Project\<mojibake>\123\<N>.<material>\...

    The preflight reports this as a BLOCKER (it used to be a WARN and got ignored, so
    it kept coming back).  This script is the cleanup the note points at.

    What it deletes -- and what it must never delete
    -------------------------------------------------
    ONLY directories whose name round-trips (ANSI bytes -> strict UTF-8) back to this
    project's own name.  That is a proof of provenance, not a guess: nothing else can
    produce that exact string.

    The first version of this script deleted every directory sitting next to the
    project when given -Remove.  C:\Project\ is a SHARED parent -- it holds the user's
    other projects and whatever empty folder they chose to make -- so the documented
    remediation would have destroyed unrelated work.  Its predicate was "the name has
    >= 4 CJK characters", which matches 云山巨城 and 全自动跑 perfectly well.

    The judgement now lives in mojibake_guard.ps1, shared with the preflight so the two
    can never disagree about what counts as ours.  This file only decides what to do
    with each verdict.

    Usage
    -----
        & scripts\sanitize_stray_dirs.ps1              # report only, changes nothing
        & scripts\sanitize_stray_dirs.ps1 -Remove      # delete ONLY our mojibake dirs

    Directories that are not ours are always listed with the reason they were skipped.
    They are never deleted, not even when empty and not even with -Remove.

    Exit codes: 0 done (or nothing of ours to clean) | 1 refused / partial | 2 bad arguments
#>

[CmdletBinding()]
param(
    [switch]$Remove,
    [string]$ProjectRoot
)

$ErrorActionPreference = 'Continue'
try { [Console]::OutputEncoding = [System.Text.Encoding]::UTF8 } catch { }

function Say { param([string]$m) Write-Output $m }

if (-not $ProjectRoot) { $ProjectRoot = Split-Path -Parent $PSScriptRoot }
if (-not (Test-Path -LiteralPath $ProjectRoot -PathType Container)) {
    [Console]::Error.WriteLine("[FAIL] project root not found: $ProjectRoot")
    exit 2
}
. (Join-Path $PSScriptRoot 'mojibake_guard.ps1')

$scan = $null
try {
    $scan = Get-ProjectMojibakeDirs -ProjectRoot $ProjectRoot
} catch {
    [Console]::Error.WriteLine("[FAIL] $($_.Exception.Message)")
    exit 2
}

Say "Project root : $($scan.ProjectRoot)"
Say "Scanning     : $($scan.ParentRoot)"
Say ''

# --- our mojibake ----------------------------------------------------------

if ($scan.Ours.Count -eq 0) {
    Say '[PASS] 没有本项目的乱码目录，无需清理。'
} else {
    $totalBytes = [int64]0
    Say '=== 拟删除（本项目自己的路径被按 ANSI 读坏后产生的目录）==='
    foreach ($p in $scan.Ours) {
        $bytes = Measure-DirBytes -Path $p.Path
        $totalBytes += $bytes
        $kids = @(Get-ChildItem -LiteralPath $p.Path -Recurse -Force -ErrorAction SilentlyContinue)
        Say ("  {0}" -f $p.Path)
        Say ("     {0} 项 / {1:N1} MB" -f $kids.Count, ($bytes / 1MB))
        Say ("     名字码位: {0}" -f (Format-CodePoints -Text $p.Name))
        Say ("     判据    : {0}" -f $p.Reason)
        $sample = @(Get-ChildItem -LiteralPath $p.Path -Recurse -Force -File -ErrorAction SilentlyContinue |
                    Select-Object -First 3)
        foreach ($smp in $sample) { Say ("       e.g. {0}" -f $smp.FullName) }
    }
    Say ("  合计 {0:N1} MB" -f ($totalBytes / 1MB))
    Say ''
    Say '[NOTE] 删掉之后请把肇事的那个 .ps1 重存为 UTF-8 with BOM，否则它会再造一个。'
    Say ''
}

# --- everything else: report, never touch -----------------------------------

if ($scan.Foreign.Count -gt 0 -or $scan.ProjectItself.Count -gt 0) {
    Say '=== 不动（不是本项目的乱码，与本次清理无关）==='
    foreach ($p in $scan.ProjectItself) {
        Say ("  [项目本体] {0}" -f $p.Path)
    }
    foreach ($p in $scan.Foreign) {
        Say ("  [别的目录] {0}" -f $p.Path)
        Say ("       保留原因: {0}" -f $p.Reason)
    }
    Say ''
}

if (-not $Remove) {
    Say '[WHATIF] 未删除任何东西。'
    if ($scan.Ours.Count -gt 0) {
        Say '        确认上面「拟删除」清单无误后，加 -Remove 真正执行：'
        Say "        & '$PSCommandPath' -Remove"
    }
    exit 0
}

if ($scan.Ours.Count -eq 0) {
    Say '[DONE] 没有可删的东西 —— 上面列出的目录一个都没动。'
    exit 0
}

# --- delete our mojibake only ------------------------------------------------

$failed = New-Object System.Collections.ArrayList
foreach ($p in $scan.Ours) {
    # Re-verify immediately before deleting.  Cheap, and it means the verdict that
    # authorises the delete is the one computed at delete time, not a stale copy.
    $recheck = Test-ProjectMojibakeDir -Dir (Get-Item -LiteralPath $p.Path) -ProjectRoot $scan.ProjectRoot
    if (-not $recheck.IsProjectMojibake) {
        [void]$failed.Add("$($p.Path): verdict changed on recheck -- skipped")
        Say "  SKIPPED  $($p.Path): $($recheck.Reason)"
        continue
    }
    try {
        Remove-Item -LiteralPath $p.Path -Recurse -Force -ErrorAction Stop
        Say "  removed  $($p.Path)"
    } catch {
        [void]$failed.Add("$($p.Path): $($_.Exception.Message)")
        Say "  FAILED   $($p.Path): $($_.Exception.Message)"
    }
}

$stillThere = @($scan.Ours | Where-Object { Test-Path -LiteralPath $_.Path })
$stillCount = $stillThere.Count
Say ''
if ($failed.Count -eq 0 -and $stillCount -eq 0) {
    Say "[DONE] 清理完成。重跑 scripts\check_video_environment.ps1 应回到 blocker=0。"
    exit 0
}
Say "[PARTIAL] 仍有 $stillCount 个未清掉，请手工检查。"
exit 1