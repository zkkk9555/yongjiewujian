$B = Join-Path $PSScriptRoot 'bench.ps1'
$V_LANCZOS = 'fps=60,scale=3840:2160:flags=lanczos,setsar=1,format=yuv420p'
$E_BASE = '-preset p7 -tune hq -profile:v high -level:v 5.2 -rc vbr -b:v 18M -maxrate 28M -bufsize 56M -g 120 -bf 2 -spatial-aq 1 -temporal-aq 1 -aq-strength 8 -pix_fmt yuv420p -r 60 -fps_mode cfr'

Write-Output '=== B. single 30s: GPU scale chain (hwaccel cuda) vs CPU lanczos ==='
& $B -Name 'b1_base_repeat' -VF $V_LANCZOS -ENC $E_BASE -Single30
& $B -Name 'b2_cuda_hwaccel' -VF 'scale_cuda=3840:2160:format=yuv420p,setsar=1' -ENC $E_BASE -Single30 `
     -Iopt '-hwaccel cuda -hwaccel_output_format cuda'
& $B -Name 'b3_cuda_noaccurate_seek' -VF 'scale_cuda=3840:2160:format=yuv420p,setsar=1' -ENC $E_BASE -Single30 `
     -Iopt '-hwaccel cuda -hwaccel_output_format cuda -noaccurate_seek'

Write-Output '=== C. single 30s: isolate scale cost from NVENC AQ cost (no scale, 1440p out) ==='
& $B -Name 'c1_p7hq_aq_on'   -VF 'setsar=1,format=yuv420p' -ENC $E_BASE -Single30
& $B -Name 'c2_p7hq_aq_off'  -VF 'setsar=1,format=yuv420p' -ENC ($E_BASE -replace '-spatial-aq 1 -temporal-aq 1 -aq-strength 8','') -Single30
& $B -Name 'c3_p4_aq_off'    -VF 'setsar=1,format=yuv420p' -ENC '-preset p4 -tune hq -profile:v high -rc vbr -b:v 12M -maxrate 18M -bufsize 24M -g 120 -bf 2 -pix_fmt yuv420p -r 60 -fps_mode cfr' -Single30
& $B -Name 'c4_p1_aq_off'    -VF 'setsar=1,format=yuv420p' -ENC '-preset p1 -tune hq -profile:v high -rc vbr -b:v 12M -maxrate 18M -bufsize 24M -g 120 -bf 2 -pix_fmt yuv420p -r 60 -fps_mode cfr' -Single30
& $B -Name 'c5_p1_cq19'      -VF 'setsar=1,format=yuv420p' -ENC '-preset p1 -tune hq -rc vbr -cq 19 -b:v 0 -maxrate 0 -bufsize 24M -g 120 -bf 2 -pix_fmt yuv420p -r 60 -fps_mode cfr' -Single30
& $B -Name 'c6_p1_ll_nolook' -VF 'setsar=1,format=yuv420p' -ENC '-preset p1 -tune ll -rc vbr -b:v 12M -maxrate 18M -bufsize 24M -g 30 -bf 0 -rc-lookahead 0 -spatial-aq 0 -temporal-aq 0 -pix_fmt yuv420p -r 60 -fps_mode cfr' -Single30