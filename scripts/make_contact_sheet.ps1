param(
    [Parameter(Mandatory = $true)]
    [string]$InputDir,
    [string]$Pattern = '*.jpg',
    [Parameter(Mandatory = $true)]
    [string]$Output,
    [int]$Columns = 5,
    [int]$ThumbWidth = 320,
    [int]$ThumbHeight = 180,
    [int]$MaxPerSheet = 50
)

$ErrorActionPreference = 'Continue'

$files = @(Get-ChildItem -LiteralPath $InputDir -Filter $Pattern -File | Sort-Object Name)
if ($files.Count -eq 0) {
    Write-Output ("[FAIL] no images matching {0} in {1}" -f $Pattern, $InputDir)
    exit 1
}

# FFmpeg comes from the shared resolver, never from a hardcoded path.  This
# script used to point at the WinGet Links directory, which no longer holds an
# ffmpeg, so the contact-sheet tool -- the one sanctioned way to stay inside the
# 50-image-per-request red line -- did not run at all.
. (Join-Path $PSScriptRoot 'resolve_ffmpeg.ps1')

$pair = Resolve-FfmpegPair
if (-not $pair) {
    Write-Output ('[FAIL] no candidate directory holds BOTH ffmpeg.exe and ffprobe.exe; searched: ' + ((Get-FfmpegCandidateList) -join ' | '))
    Write-Output '        Fix the FFmpeg install location, then retry. Do not fall back to reading raw frames one by one.'
    exit 1
}
$ffmpeg = $pair.Ffmpeg

$batch = @($files | Select-Object -First $MaxPerSheet)
$n = $batch.Count
$rows = [int][Math]::Ceiling($n / [double]$Columns)

$inputs = @()
foreach ($f in $batch) { $inputs += @('-i', $f.FullName) }

$scales = @()
$labels = @()
for ($i = 0; $i -lt $n; $i++) {
    $scales += ("[{0}]scale={1}:{2}[s{0}]" -f $i, $ThumbWidth, $ThumbHeight)
    $labels += ("[s{0}]" -f $i)
}
$cells = @()
for ($i = 0; $i -lt $n; $i++) {
    $col = $i % $Columns
    $row = [int][Math]::Floor($i / $Columns)
    $cells += ("{0}_{1}" -f ($col * $ThumbWidth), ($row * $ThumbHeight))
}
$filter = ($scales -join ';') + ';' + ($labels -join '') + ("xstack=inputs={0}:layout={1}[out]" -f $n, ($cells -join '|'))

& $ffmpeg -y @inputs -filter_complex $filter -map "[out]" -frames:v 1 $Output
if ($LASTEXITCODE -ne 0) {
    Write-Output '[FAIL] ffmpeg contact-sheet render failed. Keep the per-round-new budget and read thumbnails directly instead.'
    exit 1
}

Write-Output ("[PASS] contact sheet: {0} ({1} frames, {2}x{3}, counts as 1 image)" -f $Output, $n, $Columns, $rows)
if ($files.Count -gt $MaxPerSheet) {
    Write-Output ("[NOTE] {0} files remain for the next sheet." -f ($files.Count - $MaxPerSheet))
}

exit 0
