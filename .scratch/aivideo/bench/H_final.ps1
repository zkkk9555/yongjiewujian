$B = Join-Path $PSScriptRoot 'bench.ps1'
$FF    = (Get-ChildItem 'C:\Project' -Recurse -Filter 'ffmpeg.exe' -Depth 4 -ErrorAction SilentlyContinue |
           Where-Object { $_.FullName -like '*LosslessCut*' } | Select-Object -First 1).FullName
$SRC   = (Get-ChildItem 'E:\OBS' -Filter '2026-10-04 15*.mp4' | Select-Object -First 1).FullName
$bench = Join-Path $PSScriptRoot 'out'
$proxy = Join-Path $bench 'proxy720.mp4'

$E_BASE  = '-preset p7 -tune hq -profile:v high -level:v 5.2 -rc vbr -b:v 18M -maxrate 28M -bufsize 56M -g 120 -bf 2 -spatial-aq 1 -temporal-aq 1 -aq-strength 8 -pix_fmt yuv420p -r 60 -fps_mode cfr'
$E_NOPF  = $E_BASE -replace ' -pix_fmt yuv420p',''
$V_SLOW  = 'fps=60,scale=3840:2160:flags=lanczos,setsar=1,format=yuv420p'
$V_BICUB = 'scale=3840:2160:flags=bicubic,format=yuv420p'
$V_BILIN = 'scale=3840:2160:flags=fast_bilinear,format=yuv420p'
$E_P4_LL = '-preset p4 -tune ll -profile:v high -rc vbr -b:v 18M -maxrate 28M -bufsize 56M -g 30 -bf 0 -rc-lookahead 0 -pix_fmt yuv420p -r 60 -fps_mode cfr'

# ---- round-robin so any thermal/background drift hits every config equally ----
Write-Output '##### H. round-robin finalists, 4 rounds x 30 s segment #####'
for ($r = 1; $r -le 4; $r++) {
  Write-Output "----- round $r -----"
  & $B -Name "h_base_r$r"          -VF $V_SLOW  -ENC $E_BASE  -Repeat 1
  & $B -Name "h_bicubic_p7_r$r"    -VF $V_BICUB -ENC $E_BASE  -Repeat 1
  & $B -Name "h_cuda_p7_r$r"       -VF 'scale_cuda=3840:2160:format=yuv420p' -ENC $E_NOPF -Repeat 1 -Iopt '-hwaccel cuda -hwaccel_output_format cuda'
  & $B -Name "h_bilin_p4hq_aq_r$r" -VF $V_BILIN -ENC ($E_BASE -replace '-preset p7','-preset p4') -Repeat 1
  & $B -Name "h_bilin_p4ll_r$r"    -VF $V_BILIN -ENC $E_P4_LL  -Repeat 1
}

# ---- proxy workflow: is a proxy worth it? ----
Write-Output '##### I. proxy build cost (full 2400 s source -> 720p h264) #####'
if (Test-Path $proxy) { Remove-Item $proxy -Force }
$sw = [Diagnostics.Stopwatch]::StartNew()
$p = Start-Process -FilePath $FF -NoNewWindow -PassThru -ArgumentList (
  '-hide_banner -y -v warning -stats_period 10 -stats -i "' + $SRC + '" -vf scale=1280:720:flags=fast_bilinear ' +
  '-c:v h264_nvenc -preset p5 -tune hq -rc vbr -b:v 4M -maxrate 6M -bufsize 12M -g 60 -bf 2 -pix_fmt yuv420p ' +
  '-c:a aac -b:a 160k -ar 48000 -ac 2 "' + $proxy + '"') `
  -RedirectStandardError (Join-Path $bench 'proxy_build.err')
$p.WaitForExit(); $sw.Stop()
$el = (Get-Content (Join-Path $bench 'proxy_build.err') | Where-Object { $_ -match 'time=' } | Select-Object -Last 1)
$szMB = [math]::Round((Get-Item $proxy).Length / 1MB, 1)
Write-Output ("PROXY_BUILD wall={0:N1}s  size={1}MB  ({2})" -f $sw.Elapsed.TotalSeconds, $szMB, ($el -replace '\s+',' '))

Write-Output '##### J. render one 4K segment FROM the 720p proxy vs FROM the original #####'
# same 30 s cut point, proxy is 2400 s long at 1/2 resolution
$q = '-hide_banner -y -v warning -stats_period 5 -stats -ss 600 -to 630 -i "' + $proxy + '" -vf "scale=3840:2160:flags=fast_bilinear,format=yuv420p" -c:v h264_nvenc -preset p4 -tune hq -profile:v high -rc vbr -b:v 18M -maxrate 28M -bufsize 56M -g 120 -bf 2 -spatial-aq 1 -temporal-aq 1 -aq-strength 8 -pix_fmt yuv420p -r 60 -fps_mode cfr -c:a aac -b:a 320k -ar 48000 -ac 2 "' + (Join-Path $bench 'j_proxy_render.mp4') + '"'
$sw = [Diagnostics.Stopwatch]::StartNew()
$p = Start-Process -FilePath $FF -NoNewWindow -PassThru -ArgumentList $q -RedirectStandardError (Join-Path $bench 'j_proxy_render.err')
$p.WaitForExit(); $sw.Stop()
$el = (Get-Content (Join-Path $bench 'j_proxy_render.err') | Where-Object { $_ -match 'time=' } | Select-Object -Last 1)
Write-Output ("PROXY_RENDER wall={0:N1}s  ({1})" -f $sw.Elapsed.TotalSeconds, ($el -replace '\s+',' '))

# ---- parallelism ceiling: 8 segments at jobs=1/2/4/8, clean, back to back ----
Write-Output '##### K. parallelism, current baseline chain, 240 s programme #####'
& $B -Name 'k_base_j1' -VF $V_SLOW -ENC $E_BASE -Full240 -Jobs 1
& $B -Name 'k_base_j2' -VF $V_SLOW -ENC $E_BASE -Full240 -Jobs 2
& $B -Name 'k_base_j4' -VF $V_SLOW -ENC $E_BASE -Full240 -Jobs 4
& $B -Name 'k_base_j8' -VF $V_SLOW -ENC $E_BASE -Full240 -Jobs 8
Write-Output '##### DONE #####'