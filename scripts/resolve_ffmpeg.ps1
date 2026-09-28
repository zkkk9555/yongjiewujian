<#
    resolve_ffmpeg.ps1  --  the SINGLE SOURCE OF TRUTH for locating FFmpeg.

    Why this file exists
    --------------------
    A candidate table that lives inside one script can only ever serve that one
    script.  Three other scripts each grew their own hardcoded ffmpeg path, all
    of them pointing at a WinGet install that has since been removed, so the
    contact-sheet tool and both 4K master scripts were dead on arrival.  See
    .scratch/fix-dead-ffmpeg-and-4k-render-path/spec.md.

    Two ways to use it
    ------------------
    1. Dot-source it from another PowerShell script, then call the function:

           . (Join-Path $PSScriptRoot 'resolve_ffmpeg.ps1')
           $pair = Resolve-FfmpegPair
           if (-not $pair) { ... }
           & $pair.Ffmpeg ...

       Nothing is printed; only Resolve-FfmpegPair and $script:FfmpegCandidates
       are defined.

    2. Run it with -Emit to get shell-consumable KEY=VALUE lines.  This is how
       the bash scripts consume it:

           powershell -NoProfile -ExecutionPolicy Bypass -File resolve_ffmpeg.ps1 -Emit

       Output (exit 0):
           FFMPEG=<absolute path>
           FFPROBE=<absolute path>
           DIR=<directory holding both>
       On failure: one [FAIL] line on stderr, exit 1.

    FFmpeg and FFprobe are only useful as a PAIR, so a candidate directory
    counts only when it holds BOTH executables.  PATH is probed first because a
    real installation on PATH is the most specific answer available.

    This script never installs, downloads, or modifies anything.  It only reads.
#>

[CmdletBinding()]
param(
    [switch]$Emit
)

$ErrorActionPreference = 'Continue'

# Resolve against the PROJECT root, not the caller's location, so the answer is
# the same whether we were dot-sourced or run from another directory.  When this
# file is dot-sourced, $PSScriptRoot is this file's own directory.
$ProjectRoot = Split-Path -Parent $PSScriptRoot

# Order matters: first candidate holding BOTH executables wins.  Kept as a table
# rather than a single path so the workflow survives ffmpeg being reinstalled
# somewhere else -- that is the entire failure mode this file was written to end.
$script:FfmpegCandidates = @(
    (Join-Path $env:LOCALAPPDATA 'Microsoft\WinGet\Links'),
    (Join-Path $ProjectRoot '.video-tools\LosslessCut\resources'),
    (Join-Path $ProjectRoot '.video-tools\ffmpeg\bin'),
    'C:\ffmpeg\bin',
    'C:\Program Files\ffmpeg\bin'
)

function Resolve-FfmpegPair {
    <#
        Returns a pscustomobject with Directory / Ffmpeg / Ffprobe, or $null when
        no candidate location holds both executables.  A version probe is NOT
        performed here; callers that need liveness use Get-ToolVersion.
    #>
    $pathHit = $null
    $pathCmd = Get-Command ffmpeg, ffprobe -ErrorAction SilentlyContinue
    if ($pathCmd) {
        $f = $pathCmd | Where-Object { $_.Name -eq 'ffmpeg' } | Select-Object -First 1
        $p = $pathCmd | Where-Object { $_.Name -eq 'ffprobe' } | Select-Object -First 1
        if ($f -and $p) { $pathHit = Split-Path -Parent $f.Source }
    }
    $candidates = @()
    if ($pathHit) { $candidates += $pathHit }
    $candidates += $script:FfmpegCandidates

    foreach ($dir in $candidates) {
        if (-not $dir) { continue }
        $ffmpeg = Join-Path $dir 'ffmpeg.exe'
        $ffprobe = Join-Path $dir 'ffprobe.exe'
        if ((Test-Path -LiteralPath $ffmpeg) -and (Test-Path -LiteralPath $ffprobe)) {
            return [pscustomobject]@{
                Directory = $dir
                Ffmpeg    = $ffmpeg
                Ffprobe   = $ffprobe
            }
        }
    }
    return $null
}

function Get-FfmpegCandidateList {
    <#  The searched locations, for error messages that have to be actionable.  #>
    return $script:FfmpegCandidates
}

# ---------------------------------------------------------------------------
# -Emit mode.  Skipped entirely when dot-sourced.
# ---------------------------------------------------------------------------

if ($Emit) {
    # The project root contains non-ASCII characters, and PowerShell 5.1 writes
    # redirected stdout in the console OEM code page, which mangles them for any
    # consumer reading the pipe.  Force UTF-8 on the way out.
    try { [Console]::OutputEncoding = [System.Text.Encoding]::UTF8 } catch { }

    $pair = Resolve-FfmpegPair
    if (-not $pair) {
        [Console]::Error.WriteLine('[FAIL] no candidate directory holds BOTH ffmpeg.exe and ffprobe.exe; searched: ' + ($script:FfmpegCandidates -join ' | '))
        exit 1
    }
    Write-Output ('FFMPEG=' + $pair.Ffmpeg)
    Write-Output ('FFPROBE=' + $pair.Ffprobe)
    Write-Output ('DIR=' + $pair.Directory)
    exit 0
}
