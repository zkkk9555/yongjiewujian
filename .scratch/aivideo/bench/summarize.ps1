$o = Join-Path $PSScriptRoot 'out'
$rows = @()
Get-ChildItem $o -Filter '*.err' | Where-Object { $_.Length -gt 0 } | ForEach-Object {
  $bn = $_.BaseName
  $cfg = $bn -replace '_r\d+_\d+$',''
  $t = (Get-Content $_.FullName | Where-Object { $_ -match 'time=' } | Select-Object -Last 1)
  if ($t -and $t -match 'speed=\s*([\d.]+)x') {
    $sp = [double]$matches[1]
    $rows += [pscustomobject]@{ cfg = $cfg; wall = [math]::Round(30 / $sp, 1); sp = $sp }
  }
}
$agg = $rows | Group-Object cfg | ForEach-Object {
  $w = @($_.Group.wall | Sort-Object)
  [pscustomobject]@{ cfg = $_.Name; n = $w.Count; min = $w[0]; med = $w[[int][math]::Floor($w.Count/2)]; max = $w[-1] }
}
$agg | Sort-Object med | Format-Table -AutoSize | Out-String -Width 120
Write-Output 'wall = seconds to render ONE 30 s segment (30 / ffmpeg speed=). Lower is better.'