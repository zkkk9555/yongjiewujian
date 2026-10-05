$B = Join-Path $PSScriptRoot 'bench.ps1'
$V_LANCZOS = 'fps=60,scale=3840:2160:flags=lanczos,setsar=1,format=yuv420p'
$E_BASE = '-preset p7 -tune hq -profile:v high -level:v 5.2 -rc vbr -b:v 18M -maxrate 28M -bufsize 56M -g 120 -bf 2 -spatial-aq 1 -temporal-aq 1 -aq-strength 8 -pix_fmt yuv420p -r 60 -fps_mode cfr'

Write-Output '=== NOISE CALIBRATION: identical baseline config 4x, 30s segment ==='
& $B -Name 'n_base' -VF $V_LANCZOS -ENC $E_BASE -Repeat 4

Write-Output '=== does the no-op fps=60 filter cost anything? ==='
& $B -Name 'n_nofps' -VF 'scale=3840:2160:flags=lanczos,setsar=1,format=yuv420p' -ENC $E_BASE -Repeat 2

Write-Output '=== scaler flag cost (same output size, 4K) ==='
& $B -Name 'n_bilinear' -VF 'scale=3840:2160:flags=fast_bilinear,setsar=1,format=yuv420p' -ENC $E_BASE -Repeat 2
& $B -Name 'n_bicubic'   -VF 'scale=3840:2160:flags=bicubic,setsar=1,format=yuv420p' -ENC $E_BASE -Repeat 2

Write-Output '=== full-GPU filter chain: hwaccel cuda + scale_cuda (no setsar: source SAR is already 1:1) ==='
& $B -Name 'n_cudascale' -VF 'scale_cuda=3840:2160:format=yuv420p' -ENC $E_BASE -Repeat 2 `
     -Iopt '-hwaccel cuda -hwaccel_output_format cuda'