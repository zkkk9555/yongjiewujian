<#
    new_task_dir.ps1  --  建任务目录的**唯一合法入口**（2026-10-22 立）

    为什么要它
    ----------
    原来的规则是「看 123\ 下现有任务目录的最大编号，往后排 1」——
    那是一个**读**操作，不是**分配**操作。两个对话挨着开，各自读到同一个 max，
    就各自建了同一个号（2026-10-22 实测：34.888 与 34.889 同时用了 34）。
    而 `check_task_numbering.ps1` 当时把撞号只判成 NOTE，所以既不阻止发生、
    发生之后也不报警——两条保险都没有。

    这个脚本把「读」换成「分配」：加锁、幂等、单调、留索引。

    用法
    ----
        & scripts\new_task_dir.ps1 -Material '889永劫无间 2026-10-15 22-11-13'
        & scripts\new_task_dir.ps1 -Material 'E:\PR导出\889永劫无间 2026-10-15 22-11-13.mp4' -DryRun
        & scripts\new_task_dir.ps1 -Backfill          # 把已有目录补进索引

    输出
    ----
        CREATED: C:\Project\永劫无间\123\37.xxx      ← 新建
        REUSE:   C:\Project\永劫无间\123\35.xxx      ← 同一素材已有目录，直接复用（不新建）
        WARN 素材号倒序：887 排在 889 之后（用户规则：数字越大的素材往后排）

    退出码：0 = 成功（新建或复用）；1 = 参数错 / 取号失败。

    规矩
    ----
      * 目录名 = **源文件名去扩展名**，原样照抄（`123\README.md` 的建目录铁律）。
      * 同一素材**只允许一个任务目录**：第二个对话来要同一个素材 → REUSE，不新建。
      * 编号只增不重置；取号在锁内完成，并发不会撞。
      * 索引写 `123\index.tsv`（编号⇥素材⇥创建时间⇥备注），`check_task_numbering.ps1` 会核它。
#>

[CmdletBinding()]
param(
    [Parameter()][string]$Material = '',
    [switch]$DryRun,
    [switch]$Backfill,
    [int]$LockTimeoutSec = 30,
    # 指向别的根（测试用）；默认是本项目的 123\。
    [Parameter()][string]$TasksRoot = ''
)

$ErrorActionPreference = 'Stop'
try { [Console]::OutputEncoding = [System.Text.Encoding]::UTF8 } catch { }

$here = Split-Path -Parent $MyInvocation.MyCommand.Path
$root = Split-Path -Parent $here
if (-not $TasksRoot) { $TasksRoot = Join-Path $root '123' }
$tasksRoot = $TasksRoot
$indexPath = Join-Path $tasksRoot 'index.tsv'
$lockPath = Join-Path $tasksRoot '.seq.lock'

if (-not (Test-Path -LiteralPath $tasksRoot -PathType Container)) {
    Write-Output "[FAIL] tasks root not found: $tasksRoot"
    exit 1
}

# --- 素材名归一化：去扩展名、去首尾空白 -----------------------------------------
# 目录名铁律（123\README.md）：目录名必须等于「源文件名去扩展名」。
# 本项目历史上有一个目录把 `.mp4` 也带进去了（30.884…mp4），所以这里**只做去扩展名**，
# 不做别的加工——加工就是当年吞掉日期的那个坑。
function Normalize-Material([string]$name) {
    $n = $name.Trim()
    if ($n -match '[\\/]$') { $n = $n.TrimEnd('\', '/') }
    $leaf = Split-Path -Leaf $n
    $ext = [System.IO.Path]::GetExtension($leaf)
    if ($ext -and $ext -match '^\.(mp4|mkv|mov|avi|webm|m4v)$') {
        $leaf = $leaf.Substring(0, $leaf.Length - $ext.Length)
    }
    return $leaf
}

# --- 读现有任务目录 -------------------------------------------------------------
function Get-TaskDirs {
    $out = New-Object System.Collections.ArrayList
    foreach ($d in @(Get-ChildItem -LiteralPath $tasksRoot -Directory -Force -ErrorAction SilentlyContinue)) {
        if ($d.Name -match '^(\d+)\.(.+)$') {
            [void]$out.Add([PSCustomObject]@{
                Num      = [int]$Matches[1]
                DirName  = $d.Name
                Material = $Matches[2]
                Full     = $d.FullName
                Created  = $d.CreationTime.ToString('s')
            })
        }
    }
    return $out
}

# --- 素材号（文件名开头的整数，888/889/890…）--------------------------------------
function Get-MaterialNumber([string]$material) {
    if ($material -match '^\s*(\d+)') { return [int]$Matches[1] }
    return $null
}

# --- 索引读写 -------------------------------------------------------------------
function Read-Index {
    $rows = New-Object System.Collections.ArrayList
    if (Test-Path -LiteralPath $indexPath -PathType Leaf) {
        foreach ($line in @(Get-Content -LiteralPath $indexPath -Encoding UTF8 -ErrorAction SilentlyContinue)) {
            if (-not $line.Trim()) { continue }
            if ($line.StartsWith('#')) { continue }
            $p = $line -split "`t"
            if ($p.Count -ge 3) {
                [void]$rows.Add([PSCustomObject]@{ Num = [int]$p[0]; Material = $p[1]; Created = $p[2]; Note = $(if ($p.Count -ge 4) { $p[3] } else { '' }) })
            }
        }
    }
    return $rows
}

function Write-IndexRow([int]$num, [string]$material, [string]$created, [string]$note) {
    $header = "# 任务目录索引（由 scripts\new_task_dir.ps1 维护）`r`n# 编号`t素材`t创建时间`t备注"
    if (-not (Test-Path -LiteralPath $indexPath -PathType Leaf)) {
        [System.IO.File]::WriteAllText($indexPath, $header + "`r`n", (New-Object System.Text.UTF8Encoding($false)))
    }
    $line = "{0}`t{1}`t{2}`t{3}" -f $num, $material, $created, $note
    [System.IO.File]::AppendAllText($indexPath, $line + "`r`n", (New-Object System.Text.UTF8Encoding($false)))
}

# --- 取锁：两个对话同时开就串行 -----------------------------------------------
function Enter-SequenceLock([int]$timeoutSec) {
    $deadline = (Get-Date).AddSeconds($timeoutSec)
    while ($true) {
        try {
            return [System.IO.File]::Open($lockPath, [System.IO.FileMode]::OpenOrCreate, [System.IO.FileAccess]::ReadWrite, [System.IO.FileShare]::None)
        } catch [System.IO.IOException] {
            if ((Get-Date) -gt $deadline) { return $null }
            Start-Sleep -Milliseconds 120
        }
    }
}

# ============================ -Backfill =========================================
if ($Backfill) {
    $lock = Enter-SequenceLock $LockTimeoutSec
    if ($null -eq $lock) { Write-Output "[FAIL] could not take the sequence lock within $LockTimeoutSec s"; exit 1 }
    try {
        $rows = Read-Index
        $known = @{}
        foreach ($r in $rows) { $known["$($r.Num)|$($r.Material)"] = $true }
        $added = 0
        foreach ($d in Get-TaskDirs) {
            if (-not $known.ContainsKey("$($d.Num)|$($d.Material)")) {
                if (-not $DryRun) { Write-IndexRow $d.Num $d.Material $d.Created 'backfill' }
                $added++
            }
        }
        Write-Output ("BACKFILL: {0} row(s) added (index now {1} rows)" -f $added, ((Read-Index).Count))
    } finally { $lock.Close(); $lock.Dispose() }
    exit 0
}

# ============================ 建目录 ============================================
if (-not $Material) {
    Write-Output "[FAIL] -Material is required (e.g. -Material '889永劫无间 2026-10-15 22-11-13')"
    exit 1
}

$material = Normalize-Material $Material
if (-not $material) { Write-Output '[FAIL] material name is empty after normalization'; exit 1 }
if ($material -match '[\\/:*?"<>|]') {
    Write-Output "[FAIL] material name has characters that are illegal in a Windows path: $material"
    exit 1
}

$lock = Enter-SequenceLock $LockTimeoutSec
if ($null -eq $lock) {
    Write-Output "[FAIL] could not take the sequence lock within $LockTimeoutSec s — another session is allocating; retry"
    exit 1
}
try {
    $dirs = Get-TaskDirs

    # 1) 幂等：同一素材已经有目录 → 复用，不新建
    foreach ($d in $dirs) {
        if ((Normalize-Material $d.Material) -eq $material) {
            Write-Output ("REUSE: {0}" -f $d.Full)
            Write-Output ("       （同一素材已有任务目录，编号 {0}；不新建）" -f $d.Num)
            exit 0
        }
    }

    # 2) 单调取号：max + 1，占用则继续 +1
    $maxNum = 0
    foreach ($d in $dirs) { if ($d.Num -gt $maxNum) { $maxNum = $d.Num } }
    $num = $maxNum + 1
    $tries = 0
    while ($tries -lt 100) {
        $taken = $false
        foreach ($d in $dirs) { if ($d.Num -eq $num) { $taken = $true; break } }
        if (-not $taken) { break }
        $num++
        $tries++
    }
    if ($tries -ge 100) { Write-Output '[FAIL] could not find a free task number after 100 attempts'; exit 1 }

    $dirName = "{0}.{1}" -f $num, $material
    $full = Join-Path $tasksRoot $dirName

    # 3) 素材顺序：用户规则「数字越大的素材往后排」
    $newMatNum = Get-MaterialNumber $material
    if ($null -ne $newMatNum -and $dirs.Count -gt 0) {
        $last = $dirs | Sort-Object Num -Descending | Select-Object -First 1
        $lastMatNum = Get-MaterialNumber $last.Material
        if ($null -ne $lastMatNum -and $newMatNum -lt $lastMatNum) {
            Write-Output ("WARN 素材号倒序：{0}（{1}）排在 {2}（{3}）之后——用户规则是「数字越大的素材往后排」。" -f $material, $newMatNum, $last.Material, $lastMatNum)
            Write-Output ("     历史编号不能重排，本任务仍然取号 {0}；若这不符合预期，改用别的素材顺序。" -f $num)
        }
    }

    if ($DryRun) {
        Write-Output ("DRY-RUN: would create {0}" -f $full)
        exit 0
    }

    # 4) 建目录 + 写索引（都在锁内）
    New-Item -ItemType Directory -Path $full -Force | Out-Null
    Write-IndexRow $num $material (Get-Date).ToString('s') 'new_task_dir.ps1'

    Write-Output ("CREATED: {0}" -f $full)
    Write-Output ("        （编号 {0}；下一个取 {1}）" -f $num, ($num + 1))
} finally {
    $lock.Close()
    $lock.Dispose()
}

exit 0
