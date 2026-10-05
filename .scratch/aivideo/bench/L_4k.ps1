$B = Join-Path $PSScriptRoot 'bench.ps1'
$E_BASE  = '-preset p7 -tune hq -profile:v high -level:v 5.2 -rc vbr -b:v 18M -maxrate 28M -bufsize 56M -g 120 -bf 2 -spatial-aq 1 -temporal-aq 1 -aq-strength 8 -pix_fmt yuv420p -r 60 -fps_mode cfr'
$V_SLOW  = 'fps=60,scale=3840:2160:flags=lanczos,setsar=1,format=yuv420p'   # exactly what seg_render_master.sh does today
$V_NOFPS = 'scale=3840:2160:flags=lanczos,setsar=1,format=yuv420p'          # same, minus the no-op fps=60
$V_IDENT = 'setsar=1,format=yuv420p'                                        # scale dropped: input is ALREADY 3840x2160
$E_P4_LL = '-preset p4 -tune ll -profile:v high -rc vbr -b:v 18M -maxrate 28M -bufsize 56M -g 30 -bf 0 -rc-lookahead 0 -pix_fmt yuv420p -r 60 -fps_mode cfr'

Write-Output '##### L. PRODUCTION SOURCE (E:\PR导出, true 4K H.264 3840x2160@60) #####'
Write-Output '##### round-robin, 3 rounds x 30 s segment #####'
for ($r = 1; $r -le 3; $r++) {
  Write-Output "----- round $r -----"
  & $B -Use4K -Name "l_cur_r$r"      -VF $V_SLOW  -ENC $E_BASE -Repeat 1
  & $B -Use4K -Name "l_nofps_r$r"    -VF $V_NOFPS -ENC $E_BASE -Repeat 1
  & $B -Use4K -Name "l_noscale_r$r"  -VF $V_IDENT -ENC $E_BASE -Repeat 1
  & $B -Use4K -Name "l_p4ll_r$r"     -VF $V_NOFPS -ENC $E_P4_LL -Repeat 1
}

Write-Output '##### M. parallelism on the CURRENT production chain (240 s programme) #####'
& $B -Use4K -Name 'm_cur_j1' -VF $V_SLOW -ENC $E_BASE -Full240 -Jobs 1
& $B -Use4K -Name 'm_cur_j2' -VF $V_SLOW -ENC $E_BASE -Full240 -Jobs 2
& $B -Use4K -Name 'm_cur_j4' -VF $V_SLOW -ENC $E_BASE -Full240 -Jobs 4
& $B -Use4K -Name 'm_cur_j6' -VF $V_SLOW -ENC $E_BASE -Full240 -Jobs 6

Write-Output '##### N. decode-only floor on the 4K source #####'
$FF2  = (Get-ChildItem 'C:\Project' -Recurse -Filter 'ffmpeg.exe' -Depth 4 -ErrorAction SilentlyContinue | Where-Object { $_.FullName -like '*LosslessCut*' } | Select-Object -First 1).FullName
$SRC2 = (Get-ChildItem 'E:\PR*' -Filter '809*.mp4' -ErrorAction SilentlyContinue | Select-Object -First 1).FullName
foreach ($r in 1..3) {
  $sw = [Diagnostics.Stopwatch]::StartNew()
  $p = Start-Process -FilePath $FF2 -NoNewWindow -PassThru -ArgumentList ('-hide_banner -v error -stats_period 5 -stats -ss 600 -to 630 -i "' + $SRC2 + '" -an -f null -') -RedirectStandardError "$env:TEMP\d4k.r$r.err"
  $p.WaitForExit(); $sw.Stop()
  $t = (Get-Content "$env:TEMP\d4k.r$r.err" -ErrorAction SilentlyContinue | Where-Object { $_ -match 'time=' } | Select-Object -Last 1)
  Write-Output ("DECODE_ONLY_4K rep{0} wall={1:N2}s  {2}" -f $r, $sw.Elapsed.TotalSeconds, ($t -replace '\s+',' '))
}
Write-Output '##### DONE_LMN #####'