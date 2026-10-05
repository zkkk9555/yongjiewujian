$B = Join-Path $PSScriptRoot 'bench.ps1'
$E_BASE = '-preset p7 -tune hq -profile:v high -level:v 5.2 -rc vbr -b:v 18M -maxrate 28M -bufsize 56M -g 120 -bf 2 -spatial-aq 1 -temporal-aq 1 -aq-strength 8 -pix_fmt yuv420p -r 60 -fps_mode cfr'
$V_FAST = 'scale=3840:2160:flags=fast_bilinear,format=yuv420p'
$V_BICUBIC = 'scale=3840:2160:flags=bicubic,format=yuv420p'
$V_SLOW = 'fps=60,scale=3840:2160:flags=lanczos,setsar=1,format=yuv420p'

Write-Output '=== F. re-verify p7 outlier + decode-only floor, interleaved 3x each ==='
& $B -Name 'f_baseline_current' -VF $V_SLOW    -ENC $E_BASE -Repeat 3
& $B -Name 'f_p7_bilinear'    -VF $V_FAST    -ENC $E_BASE -Repeat 3
& $B -Name 'f_p4_bilinear'    -VF $V_FAST    -ENC ($E_BASE -replace '-preset p7','-preset p4') -Repeat 3
& $B -Name 'f_p4_bicubic'     -VF $V_BICUBIC -ENC ($E_BASE -replace '-preset p7','-preset p4') -Repeat 3
# decode-only floor: no encoder at all, proves how much is I/O+HEVC decode
$null = $FF2 = (Get-ChildItem 'C:\Project' -Recurse -Filter 'ffmpeg.exe' -Depth 4 -ErrorAction SilentlyContinue | Where-Object { $_.FullName -like '*LosslessCut*' } | Select-Object -First 1).FullName
$SRC2 = (Get-ChildItem 'E:\OBS' -Filter '2026-10-04 15*.mp4' | Select-Object -First 1).FullName
foreach ($r in 1..3) {
  $sw = [Diagnostics.Stopwatch]::StartNew()
  $p = Start-Process -FilePath $FF2 -ArgumentList ('-hide_banner -v error -stats_period 5 -stats -ss 600 -to 630 -i "' + $SRC2 + '" -an -f null -') -NoNewWindow -PassThru -RedirectStandardError "$env:TEMP\dec.r$r.err"
  $p.WaitForExit(); $sw.Stop()
  $t = (Get-Content "$env:TEMP\dec.r$r.err" -ErrorAction SilentlyContinue | Where-Object { $_ -match 'time=' } | Select-Object -Last 1)
  Write-Output ("DECODE_ONLY rep{0} wall={1:N2}s  {2}" -f $r, $sw.Elapsed.TotalSeconds, ($t -replace '\s+',' '))
}

Write-Output '=== G. parallelism on the CURRENT baseline chain (8 segments, jobs=1/2/4/6) ==='
& $B -Name 'g_baseline_j1' -VF $V_SLOW -ENC $E_BASE -Full240 -Jobs 1
& $B -Name 'g_baseline_j2' -VF $V_SLOW -ENC $E_BASE -Full240 -Jobs 2
& $B -Name 'g_baseline_j4' -VF $V_SLOW -ENC $E_BASE -Full240 -Jobs 4
& $B -Name 'g_baseline_j8' -VF $V_SLOW -ENC $E_BASE -Full240 -Jobs 8