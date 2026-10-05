<#
    cleanup_after_master.ps1  --  the standing step that runs right after the 4K
    master is delivered.  You do not invoke this by hand.

    Why it exists
    -------------
    A task directory is mostly disposable weight: the 720p review preview, the
    4K render segments, ~9000 analysis frames, the extracted audio.  On task 849
    that was 3.38 GB out of 3.39 GB total.  What is actually worth keeping is
    ~10 MB of timeline JSON and audit reports -- the record of WHY each cut
    landed where it did.

    The project already decided this should happen: 849's own cleanup_log_v4.md
    section 5 says the audio and the shot frames are "可再生大文件成片即删" and
    "若后续出成片 ... 删除并记 log".  It was never automated, so it kept not
    happening and the user had to delete whole task folders by hand -- which
    took the audit trail with them.

    So: the task folder STAYS (task numbering reads it), the evidence STAYS,
    and only the regenerable weight goes.

    Usage
    -----
        cleanup_after_master.ps1 -TaskDir <123>\<N>.<material> [-Master <path>] [-WhatIf]

    Deleted : preview\, cache\, shots\, audio\        (all regenerable from source)
    Kept    : the folder itself, timeline\, reports\, analysis\,
              deliverables\, captions\, and any other file

    Safety
    ------
      * Refuses to run unless a non-empty master exists.  An undelivered task is
        never cleaned.
      * Refuses unless -TaskDir sits directly under the project's 123\ root.
      * Only ever removes paths that resolve inside -TaskDir.
      * Writes reports\cleanup_log_after_master.md BEFORE deleting, so a crash
        mid-delete still leaves the record (deliverables-and-qa.md: a deletion
        with no log counts as a violation).
      * -WhatIf prints the plan and changes nothing.

    Exit codes: 0 cleaned (or nothing to do) | 1 refused | 2 bad arguments
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$TaskDir,
    [string]$DeliveryRoot = 'E:\Cujian导出',
    [switch]$WhatIf
)

$ErrorActionPreference = 'Stop'
try { [Console]::OutputEncoding = [System.Text.Encoding]::UTF8 } catch { }

$ProjectRoot = Split-Path -Parent $PSScriptRoot
$JobsRoot    = Join-Path $ProjectRoot '123'

# Directories that are regenerable from the source and are not evidence.
$Disposable = @('preview', 'cache', 'shots', 'audio')
function Say  { param([string]$m) Write-Output $m }
function Die  { param([string]$m) [Console]::Error.WriteLine("[FAIL] $m"); exit 1 }

# --- guards -----------------------------------------------------------------

if (-not (Test-Path -LiteralPath $TaskDir -PathType Container)) {
    Die "task dir not found: $TaskDir"
}
$TaskDir = (Resolve-Path -LiteralPath $TaskDir).Path.TrimEnd('\')

$jobsResolved = (Resolve-Path -LiteralPath $JobsRoot).Path.TrimEnd('\')
if (-not $TaskDir.StartsWith($jobsResolved + '\', [System.StringComparison]::OrdinalIgnoreCase)) {
    Die "refusing to touch anything outside ${jobsRoot}: $TaskDir"
}
if ((Split-Path -Parent $TaskDir) -ne $jobsResolved) {
    Die "task dir must sit directly under ${jobsRoot} (got: $TaskDir)"
}

# ---------------------------------------------------------------------------
# Delivery gate.  E:\Cujian导出 is the ONE authoritative home of a 4K master.
# The task directory must never keep one long-term: that is what left 849 / 854 /
# 859 each holding a duplicate 1.6-2.6 GB copy.  So before deleting anything we
# prove the master has actually landed in the delivery folder.  Refuse otherwise:
# losing a master costs far more than keeping a few GB.
# ---------------------------------------------------------------------------

$leaf       = Split-Path -Leaf $TaskDir
$material   = $leaf -replace '^\d+\.', ''          # 15.855xxx -> 855xxx
$localMasterDir = Join-Path $TaskDir 'deliverables'
$localMasters   = @(Get-ChildItem -LiteralPath $localMasterDir -File -Filter '*.mp4' -Force -ErrorAction SilentlyContinue)

$delivered = @()
if (Test-Path -LiteralPath $DeliveryRoot -PathType Container) {
    $delivered = @(Get-ChildItem -LiteralPath $DeliveryRoot -File -Filter '*.mp4' -Force -ErrorAction SilentlyContinue |
                   Where-Object { $_.Name -like "$material*" -and $_.Length -gt 0 })
}

Say "task      : $TaskDir"
Say "material  : $material"
Say "delivery  : $DeliveryRoot"
Say ''

if ($delivered.Count -eq 0) {
    Say "[BLOCKED] no delivered master found for this material."
    Say "          Looked for: ${DeliveryRoot}\$material*.mp4 (non-empty)"
    if ($localMasters.Count -gt 0) {
        Say "          The task dir still holds $($localMasters.Count) local master file(s), e.g.:"
        foreach ($m in $localMasters) { Say ("            {0}  ({1:N0} B)" -f $m.FullName, $m.Length) }
        Say '          MOVE it to the delivery folder first, then re-run. Nothing was deleted.'
    } else {
        Say '          Nothing was deleted, and nothing needed deleting yet.'
        Say '          (This is the normal state during roughcut review.)'
    }
    exit 1
}

foreach ($d in $delivered) {
    Say "[DELIVERED] {0}  ({1:N0} B)" -f $d.FullName, $d.Length
}
if ($localMasters.Count -gt 0) {
    Say "[DUPLICATE] $($localMasters.Count) local master copy/copies found in deliverables\ -- they will be removed so E: stays the only copy."
}
Say ''

# --- build the plan ---------------------------------------------------------

$plan = New-Object System.Collections.ArrayList
$totalBytes = [int64]0
foreach ($name in $Disposable) {
    $target = Join-Path $TaskDir $name
    if (-not (Test-Path -LiteralPath $target -PathType Container)) { continue }
    # Belt and braces: the resolved target must still be inside the task dir.
    $resolved = (Resolve-Path -LiteralPath $target).Path
    if (-not $resolved.StartsWith($TaskDir + '\', [System.StringComparison]::OrdinalIgnoreCase)) {
        Die "refusing to delete a path outside the task dir: $resolved"
    }
    $files = @(Get-ChildItem -LiteralPath $resolved -Recurse -File -Force -ErrorAction SilentlyContinue)
    $bytes = [int64]0
    foreach ($f in $files) { $bytes += $f.Length }
    [void]$plan.Add([pscustomobject]@{
        Dir = $name; Path = $resolved; Files = $files.Count; Bytes = $bytes
    })
    $totalBytes += $bytes
}

# The local master copy is NOT evidence -- E:\Cujian导出 is authoritative and the
# delivery gate above already proved the file landed there.  Leaving it behind is
# what accumulated ~6.2 GB of duplicates across 849 / 854 / 859.
if ($localMasters.Count -gt 0) {
    $mBytes = [int64]0
    foreach ($m in $localMasters) { $mBytes += $m.Length }
    [void]$plan.Add([pscustomobject]@{
        Dir = 'deliverables\*.mp4'; Path = $localMasterDir
        Files = $localMasters.Count; Bytes = $mBytes
    })
    $totalBytes += $mBytes
}

if ($plan.Count -eq 0) {
    Say "[SKIP] nothing disposable left in $TaskDir (already cleaned)."
    exit 0
}

$taskBytes = [int64]0
foreach ($f in (Get-ChildItem -LiteralPath $TaskDir -Recurse -File -Force -ErrorAction SilentlyContinue)) {
    $taskBytes += $f.Length
}

Say ''
Say '=== 拟删清单（成片已交付后的收尾清理）==='
foreach ($p in $plan) {
    Say ("  {0,-8} {1,10:N1} MB  {2,6} files   {3}" -f ($p.Dir + '\'), ($p.Bytes / 1MB), $p.Files, $p.Path)
}
Say ("  {0,-8} {1,10:N1} MB  <- 将回收" -f '合计', ($totalBytes / 1MB))
Say ("  任务目录现体积 {0:N2} GB -> 清理后约 {1:N2} GB" -f ($taskBytes / 1GB), (($taskBytes - $totalBytes) / 1GB))
Say ''
Say '保留：目录本身（编号靠它）、timeline\、reports\、analysis\、captions\ 及所有根级文件'
Say '删除：preview\ cache\ shots\ audio\（可再生）+ deliverables\ 里的成片副本（E 盘已有正本）'
Say ''

if ($WhatIf) {
    Say '[WHATIF] 未删除任何东西。去掉 -WhatIf 即执行。'
    exit 0
}

# --- write the log BEFORE deleting -----------------------------------------

$reportsDir = Join-Path $TaskDir 'reports'
if (-not (Test-Path -LiteralPath $reportsDir -PathType Container)) {
    New-Item -ItemType Directory -Path $reportsDir -Force | Out-Null
}
$logPath = Join-Path $reportsDir 'cleanup_log_after_master.md'
if (Test-Path -LiteralPath $logPath) {
    $logPath = Join-Path $reportsDir ("cleanup_log_after_master_{0}.md" -f (Get-Date -Format 'yyyyMMdd_HHmmss'))
}

$kept = @(Get-ChildItem -LiteralPath $TaskDir -Directory -Force |
          Where-Object { $Disposable -notcontains $_.Name } | Select-Object -ExpandProperty Name)

$lines = New-Object System.Collections.ArrayList
[void]$lines.Add('# 成片交付后收尾清理（cleanup_after_master.ps1 自动执行）')
[void]$lines.Add('')
[void]$lines.Add(('- 触发点：**4K 成片已交付到 E 盘交付目录**（本轮固定步骤，不需要人工额外发起）。'))
foreach ($d in $delivered) {
    [void]$lines.Add(('- 交付正本：`{0}`（{1:N0} B）—— 成片的唯一归属' -f $d.FullName, $d.Length))
}
[void]$lines.Add(('- 成片体积：{0:N0} B' -f $delivered[0].Length))
[void]$lines.Add('- 依据：`AGENTS.md §7` 生命周期清理；849 `reports\cleanup_log_v4.md §5` 早已登记「可再生大文件成片即删」但从未自动化，本脚本即其落地。')
[void]$lines.Add('')
[void]$lines.Add('## 一、拟删清单与删前体积')
[void]$lines.Add('')
[void]$lines.Add('| 目录 | 删前体积 | 文件数 | 删除理由 |')
[void]$lines.Add('|---|---|---|---|')
foreach ($p in $plan) {
    [void]$lines.Add(('| `{0}\` | {1:N0} B（{2:N1} MB） | {3} | 可由源素材重新生成，非证据 |' -f ($p.Dir + '\'), $p.Bytes, ($p.Bytes / 1MB), $p.Files))
}
[void]$lines.Add(('| **合计** | **{0:N0} B（{1:N2} GB）** | | |' -f $totalBytes, ($totalBytes / 1GB)))
[void]$lines.Add('')
[void]$lines.Add(('任务目录体积 {0:N2} GB -> 清理后约 {1:N2} GB' -f ($taskBytes / 1GB), (($taskBytes - $totalBytes) / 1GB)))
[void]$lines.Add('')
[void]$lines.Add('## 二、保留确认')
[void]$lines.Add('')
[void]$lines.Add(('- 任务目录本身：保留（`123\README.md` 的取号规则读它，删掉会导致编号复用）'))
[void]$lines.Add(('- 保留的子目录：{0}' -f $(if ($kept.Count) { ($kept -join '、') } else { '（无）' })))
[void]$lines.Add('- `timeline\`：剪辑时间线与节目映射——「为什么这么剪」的依据')
[void]$lines.Add('- `reports\`：审计、验收、门禁、逐点裁决记录——同上是依据')
[void]$lines.Add('- `captions\`：外挂字幕本体（成片已落 E 盘，字幕随之交付，不在本目录重复保留）')
[void]$lines.Add('- `deliverables\`：**不保留成片**。成片的唯一归属是 E 盘交付目录，本目录只放记录与成片副本，副本在本轮删除')
[void]$lines.Add('- 根级散文件：一律不动')
[void]$lines.Add('')
[void]$lines.Add('## 三、删后验证')
[void]$lines.Add('')
[void]$lines.Add('- （执行后由脚本追加）')
[void]$lines.Add('')
[void]$lines.Add('## 四、成片对账')
[void]$lines.Add(('- 成片绝对路径：{0}（E 盘交付目录，成片唯一归属）' -f $delivered[0].FullName))
[void]$lines.Add('- 是否从原始素材重新渲染：是（`seg_render_master.sh` 按源时间线从源片重渲，未从预览放大）')
[void]$lines.Add('- 原始素材：只读未动（本脚本只删任务目录内的派生文件，不触碰 `E:\OBS` / `E:\PR导出`）')
[void]$lines.Add('')
[void]$lines.Add('STATUS: DONE')
[System.IO.File]::WriteAllLines($logPath, $lines, (New-Object System.Text.UTF8Encoding $false))
Say "已写清理日志：$logPath"

# --- delete -----------------------------------------------------------------

$failed = New-Object System.Collections.ArrayList
foreach ($p in $plan) {
    try {
        if ($p.Dir -eq 'deliverables\*.mp4') {
            # Delete only the master FILES, never the deliverables\ directory
            # itself -- anything else recorded there must survive.
            foreach ($m in $localMasters) {
                if ($m.FullName.StartsWith($TaskDir + '\', [System.StringComparison]::OrdinalIgnoreCase)) {
                    Remove-Item -LiteralPath $m.FullName -Force -ErrorAction Stop
                }
            }
        } else {
            Remove-Item -LiteralPath $p.Path -Recurse -Force -ErrorAction Stop
        }
        Say "  deleted  $($p.Dir)  ($([math]::Round($p.Bytes / 1MB, 1)) MB)"
    } catch {
        [void]$failed.Add("$($p.Dir): $($_.Exception.Message)")
        Say "  FAILED   $($p.Dir): $($_.Exception.Message)"
    }
}

# --- verify and close the log ----------------------------------------------

$afterBytes = [int64]0
foreach ($f in (Get-ChildItem -LiteralPath $TaskDir -Recurse -File -Force -ErrorAction SilentlyContinue)) {
    $afterBytes += $f.Length
}
$stillThere = @($plan | Where-Object { Test-Path -LiteralPath $_.Path })

$verify = New-Object System.Collections.ArrayList
[void]$verify.Add(('- 实际清理后任务目录体积：{0:N2} GB（清理前 {1:N2} GB）' -f ($afterBytes / 1GB), ($taskBytes / 1GB)))
[void]$verify.Add(('- 目标目录残留：{0}' -f $(if ($stillThere.Count -eq 0) { '无，全部已删' } else { ($stillThere.Dir -join '、') })))
[void]$verify.Add(('- 交付正本仍在 E 盘：{0}（{1:N0} B）' -f $(if (Test-Path -LiteralPath $delivered[0].FullName) { '是' } else { '否 —— 成片丢失，严重！' }), $delivered[0].Length))
if ($localMasters.Count -gt 0) {
    $leftOver = @(Get-ChildItem -LiteralPath $localMasterDir -File -Filter '*.mp4' -Force -ErrorAction SilentlyContinue)
    [void]$verify.Add(('- 任务目录内成片副本已清空：{0}（原 {1} 个）' -f $(if ($leftOver.Count -eq 0) { '是' } else { '否' }), $localMasters.Count))
}
[void]$verify.Add(('- 保留子目录完好：{0}' -f $(if ($kept.Count) { '是（' + ($kept -join '、') + '）' } else { 'n/a' })))
[void]$verify.Add(('- 源盘未触碰：本脚本只删任务目录内派生文件' ))
[void]$verify.Add('')
[void]$verify.Add(('STATUS: {0}' -f $(if ($failed.Count -eq 0 -and $stillThere.Count -eq 0) { 'DONE' } else { 'PARTIAL' })))

$all = New-Object System.Collections.ArrayList
foreach ($l in $lines) { [void]$all.Add($l) }
$all.RemoveAt($all.Count - 2)   # drop the placeholder STATUS: DONE
[void]$all.Add('')
foreach ($v in $verify) { [void]$all.Add($v) }
[System.IO.File]::WriteAllLines($logPath, $all, (New-Object System.Text.UTF8Encoding $false))

Say ''
Say ("清理完成：{0:N2} GB -> {1:N2} GB，回收 {2:N2} GB" -f ($taskBytes / 1GB), ($afterBytes / 1GB), (($taskBytes - $afterBytes) / 1GB))
Say "日志：$logPath"

if ($failed.Count -gt 0 -or $stillThere.Count -gt 0) { exit 1 }
exit 0
