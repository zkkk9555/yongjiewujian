<#
    sanitize_stray_dirs.ps1  --  remove directories that were written OUTSIDE the
    project sandbox, i.e. next to the project root instead of under 123\.

    Why this exists
    ---------------
    A .ps1 file saved as UTF-8 WITHOUT a BOM is decoded by PowerShell 5.1 with the
    ANSI code page.  A Chinese project path in the source then turns into GBK
    mojibake (e.g. 永劫无间 -> six wrong characters), and any New-Item / Set-Content
    using that string builds its tree next to the real project:

        C:\Project\<mojibake>\123\<N>.<material>\...

    The preflight reports this as a BLOCKER (it used to be a WARN and got ignored,
    so it kept coming back).  This script is the cleanup the note points at.

    Safety
    ------
      * The real project is identified by WHAT IS INSIDE IT (AGENTS.md +
        .video-tools\ + 123\), never by its name -- the name is precisely the thing
        that can be corrupted.
      * -WhatIf prints the plan and changes nothing.  Default is also dry: you must
        pass -Remove to actually delete.  Deleting outside the sandbox is a
        destructive action, so it is never the default.
      * Refuses to run if fewer than two directories are present, i.e. if the
        "stray" identification would degenerate into "delete everything".
      * Only ever touches directories that are direct children of the project's
        parent and are not the project itself.

    Exit codes: 0 done (or nothing to do) | 1 refused / partial | 2 bad arguments
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
$ProjectRoot = (Resolve-Path -LiteralPath $ProjectRoot).Path.TrimEnd('\')
$ParentRoot  = Split-Path -Parent $ProjectRoot

Say "Project root : $ProjectRoot"
Say "Scanning     : $ParentRoot"
Say ''

# Identify the real project by its contents, never by its name.
function Test-IsRealProject {
    param([string]$Dir)
    return ((Test-Path (Join-Path $Dir 'AGENTS.md')) -and
            (Test-Path (Join-Path $Dir '.video-tools')) -and
            (Test-Path (Join-Path $Dir '123')))
}

$children = @(Get-ChildItem -LiteralPath $ParentRoot -Directory -Force -ErrorAction SilentlyContinue)
$real     = @($children | Where-Object { Test-IsRealProject $_.FullName })
$strays   = @($children | Where-Object { -not (Test-IsRealProject $_.FullName) })

if ($real.Count -ne 1) {
    [Console]::Error.WriteLine("[FAIL] expected exactly 1 real project under $ParentRoot, found $($real.Count). Refusing to guess.")
    exit 1
}
if ($strays.Count -eq 0) {
    Say "[PASS] nothing to clean -- $ParentRoot contains only the project."
    exit 0
}

# --- plan -------------------------------------------------------------------

$plan = New-Object System.Collections.ArrayList
$totalBytes = [int64]0
foreach ($s in $strays) {
    $items = @(Get-ChildItem -LiteralPath $s.FullName -Recurse -Force -ErrorAction SilentlyContinue)
    $files = @($items | Where-Object { -not $_.PSIsContainer })
    $bytes = [int64]0
    foreach ($f in $files) { $bytes += $f.Length }
    [void]$plan.Add([pscustomobject]@{
        Path = $s.FullName; Name = $s.Name; Items = $items.Count; Files = $files.Count; Bytes = $bytes
    })
    $totalBytes += $bytes
}

Say '=== 拟清理清单（项目沙箱之外的目录）==='
foreach ($p in $plan) {
    Say ("  {0}" -f $p.Path)
    Say ("     {0} 项 / {1} 个文件 / {2:N1} MB" -f $p.Items, $p.Files, ($p.Bytes / 1MB))
    $cps = ($p.Name.ToCharArray() | ForEach-Object { '{0:X4}' -f [int]$_ }) -join ' '
    Say ("     名字码位: {0}" -f $cps)
    $sample = @(Get-ChildItem -LiteralPath $p.Path -Recurse -Force -File -ErrorAction SilentlyContinue |
                Select-Object -First 3)
    foreach ($smp in $sample) { Say ("       e.g. {0}" -f $smp.FullName) }
}
Say ("  合计 {0:N1} MB" -f ($totalBytes / 1MB))
Say ''

$looksMojibake = @($plan | Where-Object {
    # The real project name is 4 CJK chars; mojibake of a UTF-8 path shows up as a
    # different, usually 6-character CJK run.  Flag it, do not decide it.
    ($_.Name.ToCharArray() | Where-Object { [int]$_ -gt 0x4E00 -and [int]$_ -lt 0xA000 }).Count -ge 4
})
if ($looksMojibake.Count -gt 0) {
    Say '[NOTE] 上面这些名字看着像中文路径乱码：多半是某个 .ps1 存成了 UTF-8 无 BOM，'
    Say '       PowerShell 5.1 按 ANSI 读源码把路径读坏了。删掉之后请把该脚本重存为 UTF-8 with BOM。'
    Say ''
}

if (-not $Remove) {
    Say '[WHATIF] 未删除任何东西。确认上面清单无误后，加 -Remove 真正执行：'
    Say "        & '$PSCommandPath' -Remove"
    exit 0
}

# --- delete -----------------------------------------------------------------

$failed = New-Object System.Collections.ArrayList
foreach ($p in $plan) {
    try {
        Remove-Item -LiteralPath $p.Path -Recurse -Force -ErrorAction Stop
        Say "  removed  $($p.Path)"
    } catch {
        [void]$failed.Add("$($p.Path): $($_.Exception.Message)")
        Say "  FAILED   $($p.Path): $($_.Exception.Message)"
    }
}

$stillThere = @($plan | Where-Object { Test-Path -LiteralPath $_.Path })
$stillCount = $stillThere.Count
Say ''
if ($failed.Count -eq 0 -and $stillCount -eq 0) {
    Say "[DONE] 清理完成。回收 $([math]::Round($totalBytes/1MB,1)) MB。"
    Say '       现在重跑 scripts\check_video_environment.ps1 应回到 ok=8 warn=0 blocker=0。'
    exit 0
}
Say "[PARTIAL] 仍有 $stillCount 个未清掉，请手工检查。"
exit 1
