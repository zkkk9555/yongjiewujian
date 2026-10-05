$o = Join-Path $PSScriptRoot 'out'
# The .mp4 files were deleted by something outside this benchmark mid-run; the .err files
# survived and carry ffmpeg's own `elapsed=` (format H:MM:SS.mmm) and `speed=`, so
# re-derive every wall number from those instead of trusting the harness byte-count verdict.
$rows = @()
Get-ChildItem $o -Filter '*.err' | Where-Object { $_.Length -gt 0 } | ForEach-Object {
  $cfg = $_.BaseName -replace '_r\d+_\d+$',''
  $t = (Get-Content $_.FullName | Where-Object { $_ -match 'time=' } | Select-Object -Last 1)
  if (-not $t) { return }
  # elapsed=H:MM:SS.mmm  (three parts -- the earlier two-part regex silently yielded 0)
  $m = [regex]::Match($t, 'elapsed=(\d+):(\d+):(\d+(?:\.\d+)?)')
  if ($m.Success) {
    $sec = [double]$m.Groups[1].Value*3600 + [double]$m.Groups[2].Value*60 + [double]$m.Groups[3].Value
    $rows += [pscustomobject]@{ cfg = $cfg; sec = [math]::Round($sec,1) }
  }
}
$agg = $rows | Group-Object cfg | ForEach-Object {
  $w = @($_.Group.sec | Sort-Object)
  [pscustomobject]@{ cfg=$_.Name; n=$w.Count; min=$w[0]; med=$w[[int][math]::Floor($w.Count/2)]; max=$w[-1]; sum=[math]::Round(($w|Measure-Object -Sum).Sum,1) }
}
$agg | Sort-Object med | Format-Table -AutoSize | Out-String -Width 130
Write-Output 'sec = ffmpeg-reported elapsed to render ONE 30 s segment (re-derived from surviving .err)'