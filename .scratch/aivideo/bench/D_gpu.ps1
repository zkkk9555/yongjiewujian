$B = Join-Path $PSScriptRoot 'bench.ps1'
$E_BASE = '-preset p7 -tune hq -profile:v high -level:v 5.2 -rc vbr -b:v 18M -maxrate 28M -bufsize 56M -g 120 -bf 2 -spatial-aq 1 -temporal-aq 1 -aq-strength 8 -pix_fmt yuv420p -r 60 -fps_mode cfr'
# Same as $E_BASE but WITHOUT -pix_fmt yuv420p: that flag forces CPU frames and breaks
# any cuda filter chain (nvenc does accept AV_PIX_FMT_CUDA).
$E_NOPF = $E_BASE -replace ' -pix_fmt yuv420p',''

Write-Output '=== D. full-GPU chain: -hwaccel cuda + scale_cuda straight into h264_nvenc ==='
& $B -Name 'd_cudascale' -VF 'scale_cuda=3840:2160:format=yuv420p' -ENC $E_NOPF -Repeat 2 -Iopt '-hwaccel cuda -hwaccel_output_format cuda'
& $B -Name 'd_cudascale_nvf' -VF 'scale_cuda=3840:2160:format=yuv420p' -ENC $E_NOPF -Repeat 2 -Iopt '-hwaccel cuda -hwaccel_output_format cuda -noaccurate_seek'

Write-Output '=== E. NVENC preset sweep on the cheap CPU chain (fast_bilinear, no fps=60) ==='
$V_FAST = 'scale=3840:2160:flags=fast_bilinear,format=yuv420p'
& $B -Name 'e_p7hq' -VF $V_FAST -ENC $E_BASE -Repeat 2
& $B -Name 'e_p5hq' -VF $V_FAST -ENC ($E_BASE -replace '-preset p7','-preset p5') -Repeat 2
& $B -Name 'e_p4hq' -VF $V_FAST -ENC ($E_BASE -replace '-preset p7','-preset p4') -Repeat 2
& $B -Name 'e_p1hq' -VF $V_FAST -ENC ($E_BASE -replace '-preset p7','-preset p1') -Repeat 2
& $B -Name 'e_p4_noaq' -VF $V_FAST -ENC (($E_BASE -replace '-preset p7','-preset p4') -replace ' -spatial-aq 1 -temporal-aq 1 -aq-strength 8','') -Repeat 2
& $B -Name 'e_p4_ll_look0' -VF $V_FAST -ENC '-preset p4 -tune ll -profile:v high -rc vbr -b:v 18M -maxrate 28M -bufsize 56M -g 30 -bf 0 -rc-lookahead 0 -pix_fmt yuv420p -r 60 -fps_mode cfr' -Repeat 2