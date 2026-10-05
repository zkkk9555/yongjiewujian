# Contended-machine runner: min-of-N trials, contention recorded per trial.
# usage: powershell -File sweep.ps1 -Audio <wav> -OutDir <dir> -Trials N
param(
  [Parameter(Mandatory=$true)][string]$Audio,
  [string]$OutDir = 'C:\Project\永劫无间\.scratch\aivideo\asr_bench\out300',
  [int]$Trials = 3
)
$ErrorActionPreference = 'Continue'
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
$py = 'C:\Project\永劫无间\.video-tools\venv\Scripts\python.exe'
$b  = 'C:\Project\永劫无间\.scratch\aivideo\asr_bench'
New-Item -ItemType Directory -Force -Path $OutDir | Out-Null

# label, model, compute_type, beam, vad, hotwords
$cfgs = @(
  @{n='base_largev3_fp16_b5_vad';   m='large-v3'; c='float16';    b=5; v=1; h=''},
  @{n='largev3_fp16_b1_vad';        m='large-v3'; c='float16';    b=1; v=1; h=''},
  @{n='largev3_fp16_b5_novad';      m='large-v3'; c='float16';    b=5; v=0; h=''},
  @{n='medium_fp16_b5_vad';         m='medium';   c='float16';    b=5; v=1; h=''},
  @{n='small_fp16_b5_vad';          m='small';    c='float16';    b=5; v=1; h=''},
  @{n='tiny_fp16_b5_vad';           m='tiny';     c='float16';    b=5; v=1; h=''},
  @{n='turbo_fp16_b5_vad';          m='mobiuslabsgmbh/faster-whisper-large-v3-turbo'; c='float16'; b=5; v=1; h=''}
)

$rows = @()
for ($t = 1; $t -le $Trials; $t++) {
  foreach ($cfg in $cfgs) {
    $ffN = @(Get-Process ffmpeg -ErrorAction SilentlyContinue).Count
    $cpu = (Get-CimInstance Win32_Processor).LoadPercentage
    $out = & $py "$b\bench_fw.py" $Audio $OutDir ("{0}__t{1}" -f $cfg.n, $t) $cfg.m $cfg.c $cfg.b $cfg.v $cfg.h 2>&1 | Select-Object -Last 1
    $j = $null
    try { $j = $out | ConvertFrom-Json } catch { }
    if ($j) {
      $rows += [pscustomobject]@{
        cfg = $cfg.n; trial = $t; ffmpeg = $ffN; cpuload = $cpu
        load_s = $j.model_load_s; dec_s = $j.decode_wall_s; tot_s = $j.total_wall_s
        rf = $j.realtime_factor; segs = $j.segments; logp = $j.mean_avg_logprob
        file = ("{0}__t{1}.json" -f $cfg.n, $t)
      }
      Write-Host ("[t{0}] {1,-26} ffmpeg={2} cpu={3,3}% load={4,6}s dec={5,7}s rf={6,6}x segs={7}" -f `
        $t, $cfg.n, $ffN, $cpu, $j.model_load_s, $j.decode_wall_s, $j.realtime_factor, $j.segments)
    } else {
      Write-Host ("[t{0}] {1,-26} FAILED: {2}" -f $t, $cfg.n, ($out -join ' '))
    }
  }
}
$rows | ConvertTo-Json -Depth 4 | Set-Content (Join-Path $OutDir 'trials.json') -Encoding UTF8
Write-Host ''
Write-Host '=== min decode wall per config (contention-robust) ==='
$rows | Group-Object cfg | ForEach-Object {
  [pscustomobject]@{
    cfg = $_.Name
    dec_min = ($_.Group.dec_s | Measure-Object -Minimum).Minimum
    dec_max = ($_.Group.dec_s | Measure-Object -Maximum).Maximum
    load_min = ($_.Group.load_s | Measure-Object -Minimum).Minimum
    rf_best = ($_.Group.rf | Measure-Object -Maximum).Maximum
    segs = $_.Group[0].segs
    logp = $_.Group[0].logp
    n = $_.Count
  }
} | Sort-Object dec_min | Format-Table -AutoSize | Out-String -Width 160 | Write-Host
