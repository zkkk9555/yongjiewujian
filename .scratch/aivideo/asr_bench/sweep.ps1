# Contended-machine runner: min-of-N trials, contention recorded per trial.
# ASCII-ONLY on purpose. Chinese project paths are derived from $PSScriptRoot at
# runtime; non-ASCII payloads live in hotwords.txt (UTF-8) read by Python.
# Saving this file as UTF-8 *without* BOM makes PowerShell 5.1 mis-decode any
# non-ASCII literal, which is exactly the AGENTS.md section 1 stray-dir failure.
param(
  [Parameter(Mandatory=$true)][string]$Audio,
  [string]$OutDir = '',
  [int]$Trials = 3
)
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
$b = $PSScriptRoot
$root = Split-Path (Split-Path (Split-Path $b -Parent) -Parent) -Parent   # -> project root
$py = Join-Path $root '.video-tools\venv\Scripts\python.exe'
$turbo = Join-Path $root '.video-tools\models\local\whisper-large-v3-turbo'
$hwFile = Join-Path $b 'hotwords.txt'
if (-not $OutDir) { $OutDir = Join-Path $b 'out300' }
New-Item -ItemType Directory -Force -Path $OutDir | Out-Null
Write-Host "python  = $py  (exists=$(Test-Path $py))"
Write-Host "turbo   = $turbo (exists=$(Test-Path (Join-Path $turbo 'model.bin')))"
Write-Host "audio   = $Audio"

$cfgs = @(
  @{n='base_largev3_fp16_b5_vad';  m='large-v3'; c='float16'; b=5; v=1; h=''},
  @{n='turbo_fp16_b5_vad';         m=$turbo;     c='float16'; b=5; v=1; h=''},
  @{n='small_fp16_b5_vad';         m='small';    c='float16'; b=5; v=1; h=''},
  @{n='base_largev3_b5_vad_HOT';   m='large-v3'; c='float16'; b=5; v=1; h=$hwFile},
  @{n='turbo_fp16_b1_vad';         m=$turbo;     c='float16'; b=1; v=1; h=''}
)

$rows = @()
for ($t = 1; $t -le $Trials; $t++) {
  foreach ($cfg in $cfgs) {
    $ffN = @(Get-Process ffmpeg -ErrorAction SilentlyContinue).Count
    $cpu = (Get-CimInstance Win32_Processor).LoadPercentage
    $tag  = "{0}__t{1}" -f $cfg.n, $t
    $out  = & $py (Join-Path $b 'bench_fw.py') $Audio $OutDir $tag $cfg.m $cfg.c $cfg.b $cfg.v $cfg.h 2>&1
    $j = $null
    try { $j = ($out | Select-Object -Last 1) | ConvertFrom-Json } catch { $j = $null }
    if ($j) {
      $rows += [pscustomobject]@{
        cfg=$cfg.n; trial=$t; ffmpeg=$ffN; cpuload=$cpu
        load_s=$j.model_load_s; dec_s=$j.decode_wall_s; tot_s=$j.total_wall_s
        rf=$j.realtime_factor; segs=$j.segments; logp=$j.mean_avg_logprob; file="$tag.json" }
      Write-Host ("[t{0}] {1,-26} ffmpeg={2} cpu={3,3}%  load={4,6}s  dec={5,7}s  rf={6,6}x  segs={7}" -f `
        $t,$cfg.n,$ffN,$cpu,$j.model_load_s,$j.decode_wall_s,$j.realtime_factor,$j.segments)
    } else {
      Write-Host ("[t{0}] {1,-26} FAILED: {2}" -f $t,$cfg.n, (($out | Select-Object -Last 3) -join ' | '))
    }
  }
}
$rows | ConvertTo-Json -Depth 4 | Set-Content (Join-Path $OutDir 'trials.json') -Encoding UTF8
Write-Host ''
Write-Host '=== min decode wall per config (contention-robust) ==='
$rows | Group-Object cfg | ForEach-Object {
  [pscustomobject]@{
    cfg=$_.Name
    dec_min=[math]::Round(($_.Group.dec_s|Measure-Object -Minimum).Minimum,1)
    dec_max=[math]::Round(($_.Group.dec_s|Measure-Object -Maximum).Maximum,1)
    load_min=[math]::Round(($_.Group.load_s|Measure-Object -Minimum).Minimum,1)
    rf_best=($_.Group.rf|Measure-Object -Maximum).Maximum
    segs=$_.Group[0].segs; logp=$_.Group[0].logp; n=$_.Count } } |
  Sort-Object dec_min | Format-Table -AutoSize | Out-String -Width 160 | Write-Host