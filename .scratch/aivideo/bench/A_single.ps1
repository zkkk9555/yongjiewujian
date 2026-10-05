$B = Join-Path $PSScriptRoot 'bench.ps1'
$V_BASE = 'fps=60,scale=3840:2160:flags=lanczos,setsar=1,format=yuv420p'
$E_BASE = '-preset p7 -tune hq -profile:v high -level:v 5.2 -rc vbr -b:v 18M -maxrate 28M -bufsize 56M -g 120 -bf 2 -spatial-aq 1 -temporal-aq 1 -aq-strength 8 -pix_fmt yuv420p -r 60 -fps_mode cfr'

Write-Output '=== A. single 30s segment [600,630): isolating the 1440p->2160p upscale cost ==='
& $B -Name 'a1_lanczos_p7hq'  -VF $V_BASE -ENC $E_BASE -Single30
& $B -Name 'a2_fastbilin_p7hq' -VF 'fps=60,scale=3840:2160:flags=fast_bilinear,setsar=1,format=yuv420p' -ENC $E_BASE -Single30
& $B -Name 'a3_noscale_p7hq'  -VF 'fps=60,setsar=1,format=yuv420p' -ENC ($E_BASE -replace '-b:v 18M','-b:v 12M') -Single30
& $B -Name 'a4_cudascale_p7hq' -VF 'fps=60,scale_cuda=3840:2160:format=yuv420p,setsar=1' -ENC $E_BASE -Single30
& $B -Name 'a5_noscale_p1'     -VF 'fps=60,setsar=1,format=yuv420p' -ENC '-preset p1 -tune hq -profile:v high -rc vbr -b:v 12M -maxrate 18M -bufsize 24M -g 120 -bf 2 -pix_fmt yuv420p -r 60 -fps_mode cfr' -Single30