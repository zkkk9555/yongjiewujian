param(
    [Parameter(Mandatory = $true)]
    [string]$ImageDir,
    [string]$Pattern = '*.jpg',
    [int]$AlreadySeen = 0,
    [int]$Cap = 50,
    [int]$PerRoundNew = 10
)

$ErrorActionPreference = 'Continue'

$dirItem = Get-Item -Force -LiteralPath $ImageDir -ErrorAction SilentlyContinue
if ($null -eq $dirItem) {
    Write-Output ("[FAIL] image dir not found: {0}" -f $ImageDir)
    exit 1
}

$files = @(Get-ChildItem -LiteralPath $ImageDir -Filter $Pattern -File | Sort-Object Name)
$total = $files.Count
$remaining = $Cap - $AlreadySeen

Write-Output ("ImageDir: {0}" -f $ImageDir)
Write-Output ("Pattern: {0}, TotalOnDisk: {1}" -f $Pattern, $total)
Write-Output ("Cap: {0}, AlreadySeen: {1}, Remaining: {2}" -f $Cap, $AlreadySeen, $remaining)
Write-Output ("PerRoundNew budget: {0}" -f $PerRoundNew)

if ($remaining -le 0) {
    Write-Output '[FAIL] budget exhausted. Write the verify note first, then continue in a fresh round or window with a smaller plan.'
    exit 1
}

if ($total -eq 0) {
    Write-Output '[PASS] no images to review.'
    exit 0
}

$firstRound = [Math]::Min($PerRoundNew, [Math]::Min($remaining, $total))
if ($total -le $firstRound) {
    $rounds = 1
} else {
    $rounds = 1 + [int][Math]::Ceiling(($total - $firstRound) / [double]$PerRoundNew)
}

Write-Output ("RoundsNeeded: {0}, FirstRoundNew: {1}" -f $rounds, $firstRound)

$index = 0
for ($r = 1; $r -le $rounds; $r++) {
    if ($r -eq 1) {
        $take = [Math]::Min($firstRound, $total - $index)
    } else {
        $take = [Math]::Min($PerRoundNew, $total - $index)
    }
    $first = $files[$index].Name
    $last = $files[$index + $take - 1].Name
    Write-Output ("Round {0}: {1} images [{2} .. {3}]" -f $r, $take, $first, $last)
    $index += $take
}

if ($total -gt $PerRoundNew) {
    Write-Output '[PLAN] total exceeds one round: read Round 1 only, write the verify note, then re-run this script with -AlreadySeen updated before Round 2.'
} else {
    Write-Output '[PASS] fits in one round. Read at most the listed images this round.'
}

if ($AlreadySeen -gt 0) {
    Write-Output ("[NOTE] cumulative scope: upstream counts AlreadySeen ({0}) plus new reads in one request. Keep new reads small." -f $AlreadySeen)
}

exit 0
