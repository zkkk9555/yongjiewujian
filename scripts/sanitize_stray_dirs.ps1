<#
    sanitize_stray_dirs.ps1  --  remove the damaged directories that this project
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
    Two tiers, BOTH requiring proof, never a guess:

    Tier 1 -- NAME PROOF.  The directory name round-trips (ANSI bytes -> strict
    UTF-8) back to this project's own name.  Nothing else can produce that exact
    string, so the whole tree goes.

    Tier 2 -- DOUBLE WITNESS on a codec-impossible name.  Some names cannot come from
    ANY GBK text (they contain U+FFFD, the loss marker).  No round trip can identify
    them, so identity needs two independent witnesses agreeing: (A) the tree carries
    this project's own subtree fingerprint (a `123\` child, exactly where our BOM-bug
    artifacts clone it), and (B) something inside decodes to text containing our exact
    project name.  AND EVEN THEN this tier removes only the EMPTY clone the BOM bug
    builds -- empty `123\` leaf shells, nothing else, no matter how small.  A
    double-witness directory that carries ANY file anywhere is reported and left alone.

    The first version of this script deleted every directory sitting next to the
    project when given -Remove.  C:\Project\ is a SHARED parent -- it holds the user's
    other projects and whatever empty folder they chose to make -- so the documented
    remediation would have destroyed unrelated work.  Its predicate was "the name has
    >= 4 CJK characters", which matches 云山巨城 and 全自动跑 perfectly well.

    The judgement lives in mojibake_guard.ps1, shared with the preflight so the three
    can never disagree about what counts as ours.  This file only decides what to do
    with each verdict.

    Usage
    -----
        & scripts\sanitize_stray_dirs.ps1              # report only, changes nothing
        & scripts\sanitize_stray_dirs.ps1 -Remove      # delete ONLY proven-ours artifacts

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

# --- tier 1: name proof --------------------------------------------------------

if ($scan.Ours.Count -eq 0) {
    Say '[PASS] 没有本项目的乱码目录，无需清理。'
} else {
    $totalBytes = [int64]0
    Say '=== 拟删除·一档（名字反解即本项目：整树删）==='
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
    Say '[NOTE] 删掉之后请把肇事的那个 .ps1 重存为 UTF-8 with BOM，否则它会再长出来。'
    Say ''
}

# --- tier 2: double witness on codec-impossible names ---------------------------

$prunable = New-Object System.Collections.ArrayList
if ($scan.CorruptProven.Count -gt 0) {
    Say '=== 拟处理·二档（名字已坏到无编码能解释：只删空壳）==='
    foreach ($p in $scan.CorruptProven) {
        $w = $p.CorruptWitness
        Say ("  {0}" -f $p.Path)
        Say ("     名字码位: {0}" -f (Format-CodePoints -Text $p.Name))
        Say ("     见证 A : {0}" -f $w.WitnessA)
        Say ("     见证 B : {0}" -f $w.WitnessB)
        Say ("     内容   : {0} 个文件 / {1:N1} MB" -f $w.Contents.FileCount, ($w.Contents.Bytes / 1MB))
        if ($w.Contents.FileCount -eq 0 -and $w.Contents.EmptyLeafShells.Count -gt 0) {
            [void]$prunable.Add($p)
            Say '     处置   : 只删下面的空壳叶子，其余不动'
            foreach ($leaf in $w.Contents.EmptyLeafShells) { Say ("       - {0}" -f $leaf) }
        } else {
            Say '     处置   : 树里有实质内容，整树保留，只报告'
        }
    }
    Say ''
}

# --- everything else: report, never touch --------------------------------------

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
    if ($scan.Ours.Count -gt 0 -or $prunable.Count -gt 0) {
        Say '        确认上面「拟删除/拟处理」清单无误后，加 -Remove 真正执行：'
        Say "        & '$PSCommandPath' -Remove"
    }
    # A double-witness tree that carries real work is itself a BLOCKER-grade finding:
    # it needs a human, and "no -Remove given" must not look like "all clear".
    $heavy = @($scan.CorruptProven | Where-Object { $_.CorruptWitness.Contents.FileCount -gt 0 })
    if ($heavy.Count -gt 0) { exit 1 }
    exit 0
}

if ($scan.Ours.Count -eq 0 -and $prunable.Count -eq 0) {
    Say '[DONE] 没有可删的东西 —— 上面列出的目录一个都没动。'
    $heavy = @($scan.CorruptProven | Where-Object { $_.CorruptWitness.Contents.FileCount -gt 0 })
    if ($heavy.Count -gt 0) { exit 1 }
    exit 0
}

# --- delete: tier 1 whole trees -------------------------------------------------

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

# --- prune: tier 2 empty leaf shells only ----------------------------------------

foreach ($p in $prunable) {
    # Re-run the double-witness check at delete time: the recheck re-inventories the
    # tree, so a file created after the report turns the plan into a skip.
    $recheck = Test-NameCorruptDir -DirPath $p.Path -ProjectName (Split-Path -Leaf $scan.ProjectRoot)
    if (-not $recheck.IsOurs -or $recheck.Contents.FileCount -gt 0) {
        $why = if (-not $recheck.IsOurs) { $recheck.Reason } else { 'tree gained files since the report -- left alone' }
        [void]$failed.Add("$($p.Path): became non-prunable on recheck -- skipped")
        Say "  SKIPPED  $($p.Path): $why"
        continue
    }
    foreach ($leaf in $recheck.Contents.EmptyLeafShells) {
        $full = Join-Path $p.Path $leaf
        try {
            # One more guard at the point of no return: the target must still be an
            # empty directory, never a file, never something that grew content.
            $it = Get-Item -LiteralPath $full -ErrorAction Stop
            if (-not $it.PSIsContainer) { throw 'not a directory any more' }
            if (@(Get-ChildItem -LiteralPath $full -Force -ErrorAction Stop).Count -gt 0) { throw 'no longer empty' }
            Remove-Item -LiteralPath $full -Force -ErrorAction Stop
            Say "  pruned   $full"
        } catch {
            [void]$failed.Add("$($full): $($_.Exception.Message)")
            Say "  FAILED   $($full): $($_.Exception.Message)"
        }
    }
}

$stillThere = @($scan.Ours | Where-Object { Test-Path -LiteralPath $_.Path })
$stillCount = $stillThere.Count
Say ''
if ($failed.Count -eq 0 -and $stillCount -eq 0) {
    Say "[DONE] 清理完成。重跑 scripts\check_video_environment.ps1 应回到 blocker=0。"
    # A double-witness tree that carries real files is reported and left standing by
    # design -- but it still needs a human, so say so and refuse the clean exit.
    # (Same rule as the two early exits above; this is the path taken when tier-1
    # or tier-2 actually deleted something in the same run.)
    $heavy = @($scan.CorruptProven | Where-Object { $_.CorruptWitness.Contents.FileCount -gt 0 })
    if ($heavy.Count -gt 0) {
        Say ("[REVIEW] {0} 个二档目录树里有实质内容，已保留未删，需要人工裁决：" -f $heavy.Count)
        foreach ($h in $heavy) { Say ("       {0} ({1} 个文件)" -f $h.Path, $h.CorruptWitness.Contents.FileCount) }
        exit 1
    }
    exit 0
}
Say "[PARTIAL] 仍有 $stillCount 个未清掉，请手工检查。"
exit 1