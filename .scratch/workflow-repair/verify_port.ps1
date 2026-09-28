<#
    verify_port.ps1 — 验证 PowerShell 移植版与 Python 原版语义等价。

    做法：用任务 12/13/14/15 在 Python 尚可用时真跑出来的 validate_v*.json
    作为黄金参照，对同一份 timeline 重跑移植版，逐字段对账。

    严格只读：只读 timeline 与黄金参照，只写本 .scratch 目录。
#>
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
$ErrorActionPreference = 'Continue'

$Root     = 'C:\Project\永劫无间'
$Port     = Join-Path $Root 'scripts\validate_combat_timeline.ps1'
$OutDir   = Join-Path $Root '.scratch\workflow-repair\portverify'
New-Item -ItemType Directory -Force -Path $OutDir | Out-Null

# 黄金参照对：(timeline 相对路径, validate 相对路径)
$Pairs = @(
    @('123\12.848永劫无间 2026-08-28 22-12-40\timeline\combat_episodes_v2.json', '123\12.848永劫无间 2026-08-28 22-12-40\timeline\validate_v2.json'),
    @('123\12.848永劫无间 2026-08-28 22-12-40\timeline\combat_episodes_v3.json', '123\12.848永劫无间 2026-08-28 22-12-40\timeline\validate_v3.json'),
    @('123\13.849永劫无间2026-08-29 00-06-20\timeline\combat_episodes_v3.json',      '123\13.849永劫无间2026-08-29 00-06-20\timeline\validate_v3.json'),
    @('123\13.849永劫无间2026-08-29 00-06-20\timeline\combat_episodes_v4.json',      '123\13.849永劫无间2026-08-29 00-06-20\timeline\validate_v4.json'),
    @('123\14.852永劫无间 2026-09-18 22-01-18\timeline\combat_episodes_v1.json',     '123\14.852永劫无间 2026-09-18 22-01-18\timeline\validate_v1.json'),
    @('123\14.852永劫无间 2026-09-18 22-01-18\timeline\combat_episodes_v2.json',     '123\14.852永劫无间 2026-09-18 22-01-18\timeline\validate_v2.json'),
    @('123\15.853永劫无间 2026-09-18 22-20-16\timeline\combat_episodes_v1.json',     '123\15.853永劫无间 2026-09-18 22-20-16\timeline\validate_v1.json'),
    @('123\15.853永劫无间 2026-09-18 22-20-16\timeline\combat_episodes_v2.json',     '123\15.853永劫无间 2026-09-18 22-20-16\timeline\validate_v2.json')
)

function Get-Prop($obj, [string]$n, $def = $null) {
    if ($null -eq $obj) { return $def }
    $p = $obj.PSObject.Properties[$n]
    if ($null -eq $p) { return $def }
    return $p.Value
}

$totalDiff = 0
$rows = @()

foreach ($pair in $Pairs) {
    $tlPath = Join-Path $Root $pair[0]
    $goldPath = Join-Path $Root $pair[1]
    if (-not (Test-Path -LiteralPath $tlPath) -or -not (Test-Path -LiteralPath $goldPath)) {
        $rows += [pscustomobject]@{ Case = (Split-Path -Leaf $tlPath); Status = 'SKIP(missing)'; Diffs = '-' }
        continue
    }

    $gold = Get-Content -LiteralPath $goldPath -Raw -Encoding UTF8 | ConvertFrom-Json

    # 黄金里若含 source_duration_valid，就沿用那个值传给移植版
    $durCheck = @($gold.checks) | Where-Object { $_.name -eq 'source_duration_valid' } | Select-Object -First 1
    $outPath = Join-Path $OutDir ((Split-Path -Leaf $goldPath) + '.port.json')

    if ($null -ne $durCheck) {
        & $Port -Timeline $tlPath -SourceDuration ([double]$durCheck.source_duration) -Output $outPath | Out-Null
    } else {
        & $Port -Timeline $tlPath -Output $outPath | Out-Null
    }
    $exit = $LASTEXITCODE
    $mine = Get-Content -LiteralPath $outPath -Raw -Encoding UTF8 | ConvertFrom-Json

    $diffs = New-Object System.Collections.Generic.List[string]

    # 1) 总体 pass
    if ([bool]$gold.pass -ne [bool]$mine.pass) {
        $diffs.Add("pass: gold=$($gold.pass) mine=$($mine.pass)")
    }
    # 2) episode 数
    if ([int]$gold.episode_count -ne [int]$mine.episode_count) {
        $diffs.Add("episode_count: gold=$($gold.episode_count) mine=$($mine.episode_count)")
    }
    # 3) checks 条数
    $gc = @($gold.checks); $mc = @($mine.checks)
    if ($gc.Count -ne $mc.Count) {
        $diffs.Add("checks count: gold=$($gc.Count) mine=$($mc.Count)")
    }
    # 4) 逐条对账
    $n = [Math]::Min($gc.Count, $mc.Count)
    for ($i = 0; $i -lt $n; $i++) {
        $g = $gc[$i]; $m = $mc[$i]
        if ([string]$g.name -ne [string]$m.name) {
            $diffs.Add("[$i] name: gold='$($g.name)' mine='$($m.name)'")
            continue
        }
        if ([bool](Get-Prop $g 'pass') -ne [bool](Get-Prop $m 'pass')) {
            $diffs.Add("[$i] $($g.name) pass: gold=$(Get-Prop $g 'pass') mine=$(Get-Prop $m 'pass')")
        }
        foreach ($f in @('source_start','source_end','engage_start','outcome_time','program_sum','start','end')) {
            $gv = Get-Prop $g $f; $mv = Get-Prop $m $f
            if ($null -eq $gv -and $null -eq $mv) { continue }
            if ($null -eq $gv -or $null -eq $mv) { $diffs.Add("[$i] $($g.name) ${f}: one-null gold=$gv mine=$mv"); continue }
            $gd = [double]$gv; $md = [double]$mv
            if ([Math]::Abs($gd - $md) -gt 0.0005) {
                $diffs.Add("[$i] $($g.name) ${f}: gold=$gd mine=$md")
            }
        }
        foreach ($f in @('category','complete','needs_review','valid_range','within_source','monotonic_non_overlapping','overlaps_selected')) {
            $gv = Get-Prop $g $f; $mv = Get-Prop $m $f
            if ($null -eq $gv -and $null -eq $mv) { continue }
            if ([string]$gv -ne [string]$mv) { $diffs.Add("[$i] $($g.name) ${f}: gold='$gv' mine='$mv'") }
        }
    }
    # 5) warnings
    $gw = @($gold.warnings); $mw = @($mine.warnings)
    if ($gw.Count -ne $mw.Count) {
        $diffs.Add("warnings count: gold=$($gw.Count) mine=$($mw.Count)")
    } else {
        for ($i = 0; $i -lt $gw.Count; $i++) {
            if ([string]$gw[$i] -ne [string]$mw[$i]) { $diffs.Add("warning[$i]: gold='$($gw[$i])' mine='$($mw[$i])'") }
        }
    }
    # 6) 退出码与 pass 自洽
    $expectExit = if ([bool]$mine.pass) { 0 } else { 1 }
    if ($exit -ne $expectExit) { $diffs.Add("exit code: got=$exit expected=$expectExit") }

    $totalDiff += $diffs.Count
    $rows += [pscustomobject]@{
        Case   = (Split-Path -Leaf $tlPath)
        Status = if ($diffs.Count -eq 0) { 'MATCH' } else { 'DIFF' }
        Diffs  = $diffs.Count
    }
    if ($diffs.Count -gt 0) {
        Write-Output "--- $(Split-Path -Leaf $tlPath) 的差异 ---"
        $diffs | Select-Object -First 12 | ForEach-Object { "    $_" }
    }
}

Write-Output ""
Write-Output "==================== 对账汇总 ===================="
$rows | Format-Table -AutoSize | Out-String
Write-Output "TOTAL_SEMANTIC_DIFFS = $totalDiff"
if ($totalDiff -eq 0) { Write-Output "RESULT: PASS — 移植版与 Python 原版语义等价" }
else { Write-Output "RESULT: FAIL — 存在语义差异，见上" }
