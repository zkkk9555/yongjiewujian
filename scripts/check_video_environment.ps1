<#
    check_video_environment.ps1  --  READ-ONLY preflight for roughcut tasks.

    Verdicts are based on what actually RUNS, not on what merely EXISTS on disk.
    A file that is present but cannot be started is a BLOCKER, not a PASS.

    This script never installs, never creates an environment, never downloads,
    never deletes. It only reads and executes version probes.

    Exit codes:
      0  ready        -- no blockers, a roughcut task can start
      2  blocked      -- at least one BLOCKER; see the BLOCKERS list
      1  incomplete   -- the check itself could not be completed
#>

[CmdletBinding()]
param(
    [switch]$Json,
    [switch]$SkipPackageProbe
)

$ErrorActionPreference = 'Continue'
$ProjectRoot = Split-Path -Parent $PSScriptRoot

# FFmpeg/FFprobe resolution lives in ONE place (resolve_ffmpeg.ps1) so this
# script, the contact-sheet tool and the two bash master scripts cannot drift
# apart again.  Dot-sourcing defines Resolve-FfmpegPair and
# $script:FfmpegCandidates in this script's scope and prints nothing.
. (Join-Path $PSScriptRoot 'resolve_ffmpeg.ps1')

$script:Blockers = New-Object System.Collections.ArrayList
$script:Warns    = New-Object System.Collections.ArrayList
$script:Passes   = New-Object System.Collections.ArrayList
$script:Notes    = New-Object System.Collections.ArrayList

function Add-Result {
    param(
        [ValidateSet('PASS', 'WARN', 'BLOCKER', 'NOTE')]
        [string]$State,
        [string]$Name,
        [string]$Detail
    )
    $line = "[{0}] {1}: {2}" -f $State, $Name, $Detail
    if (-not $Json) { Write-Output $line }
    switch ($State) {
        'PASS'    { [void]$script:Passes.Add("$Name :: $Detail") }
        'WARN'    { [void]$script:Warns.Add("$Name :: $Detail") }
        'BLOCKER' { [void]$script:Blockers.Add("$Name :: $Detail") }
        default   { [void]$script:Notes.Add("$Name :: $Detail") }
    }
}

# NOTE: the FFmpeg/FFprobe candidate table and Resolve-FfmpegPair are NOT
# defined here -- they come from resolve_ffmpeg.ps1, dot-sourced at the top of
# this file.  Do not reintroduce a local copy; that duplication is the bug this
# refactor exists to remove (see .scratch/fix-dead-ffmpeg-and-4k-render-path/).

function Get-ToolVersion {
    param([string]$Exe, [string]$Flag = '-version')
    try {
        $global:LASTEXITCODE = $null
        $out = & $Exe $Flag -hide_banner 2>&1 | Out-String
        if ($LASTEXITCODE -ne 0) { return "present but did not run (exit=$LASTEXITCODE)" }
        $first = ($out -split "`r?`n" | Where-Object { $_.Trim() } | Select-Object -First 1)
        return $first.Trim()
    } catch {
        return "present but could not be started: $($_.Exception.Message)"
    }
}

# ---------------------------------------------------------------------------
# Python candidate resolution.  Resolve only -- never create an environment.
# ---------------------------------------------------------------------------

$script:PythonCandidates = @(
    (Join-Path $ProjectRoot '.video-tools\venv\Scripts\python.exe'),
    (Join-Path $env:LOCALAPPDATA 'Programs\Python\Python313\python.exe'),
    (Join-Path $env:LOCALAPPDATA 'Programs\Python\Python312\python.exe'),
    (Join-Path $env:LOCALAPPDATA 'Programs\Python\Python311\python.exe'),
    'C:\Python313\python.exe',
    'C:\Python312\python.exe',
    'C:\Python311\python.exe'
)

function Resolve-Python {
    <#
        Order is deliberate: the project venv FIRST.  It is the canonical entry
        (AGENTS.md section 2) and it is the only candidate whose failure yields
        a diagnostic worth acting on ("venv base interpreter is missing").
        PATH goes LAST so a Microsoft Store stub never masks the real cause.
    #>
    $candidates = New-Object System.Collections.ArrayList
    foreach ($c in $script:PythonCandidates) { [void]$candidates.Add($c) }
    $onPath = Get-Command python -ErrorAction SilentlyContinue
    if ($onPath) { [void]$candidates.Add($onPath.Source) }
    foreach ($c in $candidates) {
        if ($c -and (Test-Path -LiteralPath $c)) { return $c }
    }
    return $null
}

<#
    The decisive test.  A sentinel is printed by the interpreter itself, so if
    the interpreter cannot start we get no sentinel and we KNOW it is dead --
    as opposed to guessing from a file listing.
#>
function Test-InterpreterRuns {
    param([string]$Exe)
    $sentinel = 'PREFLIGHT_PY_SENTINEL_OK'
    $code = "import sys; print('$sentinel', sys.version.split()[0])"
    try {
        $global:LASTEXITCODE = $null
        $out = & $Exe -c $code 2>&1 | Out-String
    } catch {
        return [pscustomobject]@{ Ok = $false; Reason = $_.Exception.Message; Version = $null }
    }
    if ($out -match [regex]::Escape($sentinel)) {
        $m = [regex]::Match($out, [regex]::Escape($sentinel) + '\s+(\S+)')
        return [pscustomobject]@{
            Ok      = $true
            Reason  = $null
            Version = if ($m.Success) { $m.Groups[1].Value } else { 'unknown' }
        }
    }
    $reason = ($out -split "`r?`n" | Where-Object { $_.Trim() } | Select-Object -First 1)
    if (-not $reason) { $reason = 'no output; interpreter produced neither sentinel nor error' }
    return [pscustomobject]@{ Ok = $false; Reason = $reason.Trim(); Version = $null }
}

# ---------------------------------------------------------------------------
# Run the checks
# ---------------------------------------------------------------------------

if (-not $Json) {
    Write-Output "ProjectRoot: $ProjectRoot"
    Write-Output 'READ-ONLY preflight. Installs nothing, creates no environment, downloads nothing.'
    Write-Output ''
}

# --- Python: resolve, then prove it runs -----------------------------------

$pythonExe = Resolve-Python
$pythonOk = $false

if (-not $pythonExe) {
    Add-Result 'BLOCKER' 'python interpreter' 'no python.exe found in any candidate location'
} else {
    $probe = Test-InterpreterRuns -Exe $pythonExe
    if ($probe.Ok) {
        $pythonOk = $true
        $isProjectVenv = $pythonExe -like (Join-Path $ProjectRoot '*')
        $kind = if ($isProjectVenv) { 'project venv' } else { 'external' }
        Add-Result 'PASS' 'python interpreter' "runs, $kind, Python $($probe.Version) :: $pythonExe"
    } else {
        $isProjectVenv = $pythonExe -like (Join-Path $ProjectRoot '*')
        $hint = ''
        if ($isProjectVenv) {
            # ...\.video-tools\venv\Scripts\python.exe -> ...\.video-tools\venv\pyvenv.cfg
            $venvRoot = Split-Path -Parent (Split-Path -Parent $pythonExe)
            $cfg = Join-Path $venvRoot 'pyvenv.cfg'
            if (Test-Path -LiteralPath $cfg) {
                # NB: must not be named $home -- that collides with PowerShell's
                # read-only $HOME automatic variable and silently throws.
                $homeLine = (Get-Content -LiteralPath $cfg | Where-Object { $_ -like 'home*' } | Select-Object -First 1)
                $homePath = ($homeLine -replace '^home\s*=\s*', '').Trim()
                if ($homePath -and -not (Test-Path -LiteralPath $homePath)) {
                    $hint = " | venv base interpreter is MISSING (was): $homePath"
                }
            }
        }
        Add-Result 'BLOCKER' 'python interpreter' "EXISTS but CANNOT START: $($probe.Reason)$hint :: $pythonExe"
    }
}

if ($pythonOk) {
    foreach ($tool in @(
        @{ Name = 'auto-editor CLI'; Path = (Join-Path $ProjectRoot '.video-tools\venv\Scripts\auto-editor.exe') },
        @{ Name = 'PySceneDetect CLI'; Path = (Join-Path $ProjectRoot '.video-tools\venv\Scripts\scenedetect.exe') }
    )) {
        if (Test-Path -LiteralPath $tool.Path) {
            Add-Result 'PASS' $tool.Name $tool.Path
        } else {
            Add-Result 'WARN' $tool.Name "not present (optional CLI wrapper) :: $($tool.Path)"
        }
    }
} else {
    Add-Result 'WARN' 'auto-editor CLI' 'skipped: no runnable python'
    Add-Result 'WARN' 'PySceneDetect CLI' 'skipped: no runnable python'
}

# --- Package probe (only meaningful when python actually runs) -------------

if ($pythonOk -and -not $SkipPackageProbe) {
    # NB: no double quotes in this snippet.  PowerShell 5.1 rebuilds the native
    # command line and will truncate the argument at the first embedded ", so a
    # normal f-string here silently becomes a SyntaxError and the whole probe
    # reports "exit=1".  Single quotes only.
    $pkgCode = @'
import importlib.metadata as m
for p in ['faster-whisper','scenedetect','auto-editor','ctranslate2','librosa','opentimelineio']:
    try: print('  ' + p + '=' + m.version(p))
    except Exception: print('  ' + p + '=MISSING')
'@
    try {
        $global:LASTEXITCODE = $null
        $pkgOut = & $pythonExe -c $pkgCode 2>&1 | Out-String
        if ($LASTEXITCODE -eq 0) {
            Add-Result 'NOTE' 'package versions' 'read from runnable interpreter'
            if (-not $Json) { Write-Output $pkgOut.TrimEnd() }
        } else {
            Add-Result 'WARN' 'package versions' "probe failed (exit=$LASTEXITCODE)"
        }
    } catch {
        Add-Result 'WARN' 'package versions' $_.Exception.Message
    }
} elseif ($pythonOk) {
    Add-Result 'NOTE' 'package versions' 'skipped via -SkipPackageProbe'
} else {
    Add-Result 'WARN' 'package versions' 'unavailable: no runnable python'
}

# --- Whisper model cache (data only; survives a broken interpreter) ---------

$ModelRoot = Join-Path $ProjectRoot '.video-tools\models'
$LargeV3 = Join-Path $ModelRoot 'models--Systran--faster-whisper-large-v3'
if (Test-Path -LiteralPath $LargeV3) {
    Add-Result 'PASS' 'faster-whisper model cache' $LargeV3
} else {
    Add-Result 'WARN' 'faster-whisper model cache' "not present :: $LargeV3"
}

# --- LosslessCut -----------------------------------------------------------

$LosslessCut = Join-Path $ProjectRoot '.video-tools\LosslessCut\LosslessCut.exe'
if (Test-Path -LiteralPath $LosslessCut) {
    Add-Result 'PASS' 'LosslessCut' $LosslessCut
} else {
    Add-Result 'WARN' 'LosslessCut' "not present :: $LosslessCut"
}

# --- FFmpeg / FFprobe: resolved, paired, version-probed -------------------

$pair = Resolve-FfmpegPair
if ($pair) {
    $ffVer = Get-ToolVersion -Exe $pair.Ffmpeg
    $fpVer = Get-ToolVersion -Exe $pair.Ffprobe
    Add-Result 'PASS' 'FFmpeg resolved' "$($pair.Ffmpeg) :: $ffVer"
    Add-Result 'PASS' 'FFprobe resolved' "$($pair.Ffprobe) :: $fpVer"
} else {
    Add-Result 'BLOCKER' 'FFmpeg/FFprobe' "no candidate directory holds BOTH ffmpeg.exe and ffprobe.exe; searched: $($script:FfmpegCandidates -join ' | ')"
}

# --- Script encoding guard ----------------------------------------------------
#
# PowerShell 5.1 decodes a BOM-less script with the ANSI code page, so every
# non-ASCII character in it becomes mojibake.  That is cosmetic when the file
# only has Chinese in comments -- but if a *path literal* goes mojibake, the
# script creates a garbage directory next to the real project instead of
# writing where it was told.  That actually happened here once, so check it.
#
# ASCII-only source below on purpose.

$ScriptsDir = Join-Path $ProjectRoot 'scripts'
$badEncoding = New-Object System.Collections.ArrayList
foreach ($f in (Get-ChildItem -LiteralPath $ScriptsDir -File -Filter '*.ps1' -ErrorAction SilentlyContinue)) {
    $bytes = [System.IO.File]::ReadAllBytes($f.FullName)
    $hasBom = ($bytes.Length -ge 3 -and $bytes[0] -eq 0xEF -and $bytes[1] -eq 0xBB -and $bytes[2] -eq 0xBF)
    $nonAscii = 0
    foreach ($x in $bytes) { if ($x -gt 127) { $nonAscii++ } }
    if ($nonAscii -gt 0 -and -not $hasBom) { [void]$badEncoding.Add($f.Name) }
}
if ($badEncoding.Count -gt 0) {
    Add-Result 'WARN' 'script encoding' ("these scripts contain non-ASCII but have NO UTF-8 BOM; PowerShell 5.1 will read their Chinese as mojibake, and any Chinese path literal in them will point somewhere wrong: " + ($badEncoding -join ', '))
    Add-Result 'NOTE' 'script encoding' 'fix: re-save as UTF-8 WITH BOM (see docs/TROUBLESHOOTING.md). The project scripts must be pure ASCII or BOM-carrying.'
}

# --- Stray-directory guard ---------------------------------------------------
#
# Everything the workflow produces belongs under 123\<N>.<material>.  A sibling
# directory next to the project root means something wrote outside its sandbox
# -- historically a mojibake path.  Identify the real project by what is inside
# it, never by its name (the name is exactly what may be corrupted).
$ParentRoot = Split-Path -Parent $ProjectRoot
$strays = New-Object System.Collections.ArrayList
foreach ($d in (Get-ChildItem -LiteralPath $ParentRoot -Directory -Force -ErrorAction SilentlyContinue)) {
    if ($d.FullName -eq $ProjectRoot) { continue }
    $isRealProject = (Test-Path (Join-Path $d.FullName 'AGENTS.md')) -and
                      (Test-Path (Join-Path $d.FullName '.video-tools')) -and
                      (Test-Path (Join-Path $d.FullName '123'))
    if (-not $isRealProject) {
        $kids = @(Get-ChildItem -LiteralPath $d.FullName -Recurse -Force -ErrorAction SilentlyContinue)
        $bytes = [int64]0
        foreach ($k in $kids) { if (-not $k.PSIsContainer) { $bytes += $k.Length } }
        [void]$strays.Add(("{0} ({1} items, {2} B)" -f $d.FullName, $kids.Count, $bytes))
    }
}
if ($strays.Count -gt 0) {
    # BLOCKER, not WARN.  This recurred repeatedly as a WARN and was ignored every
    # time, so a stray directory kept reappearing at the project root's parent.
    # Almost always it is a mojibake path: a .ps1 saved without a UTF-8 BOM makes
    # PowerShell 5.1 decode the Chinese project path as ANSI, and the whole output
    # tree lands next to the real project instead of inside it.
    Add-Result 'BLOCKER' 'stray dirs beside project' ("STOP: something wrote outside the sandbox. Directories that sit next to the project root and are not the project: " + ($strays -join ' | '))
    Add-Result 'NOTE' 'stray dirs beside project' "do NOT delete them blindly. Inspect first (a mojibake name means a script was run without a UTF-8 BOM). Then run: & 'C:\Project\永劫无间\scripts\sanitize_stray_dirs.ps1' -WhatIf   (drop -WhatIf to actually remove)"
} else {
    Add-Result 'PASS' 'no stray dirs beside project' ("{0} contains only the project" -f $ParentRoot)
}

# --- Legacy duplicate env --------------------------------------------------

$legacyVenv = Join-Path $ProjectRoot '.video-venv'
if (Test-Path -LiteralPath $legacyVenv) {
    Add-Result 'NOTE' 'legacy duplicate env' "present (do not use, do not delete without asking) :: $legacyVenv"
}

# ---------------------------------------------------------------------------
# Verdict
# ---------------------------------------------------------------------------

$summary = [pscustomobject]@{
    projectRoot    = $ProjectRoot
    python         = $pythonExe
    pythonRunnable = $pythonOk
    ffmpeg         = if ($pair) { $pair.Ffmpeg } else { $null }
    ffprobe        = if ($pair) { $pair.Ffprobe } else { $null }
    pass           = $script:Passes.Count
    warn           = $script:Warns.Count
    blocker        = $script:Blockers.Count
    blockers       = @($script:Blockers)
    warnings       = @($script:Warns)
    ready          = ($script:Blockers.Count -eq 0)
}

if ($Json) {
    $summary | ConvertTo-Json -Depth 5
} else {
    Write-Output ''
    Write-Output ("SUMMARY: ok={0} warn={1} blocker={2}" -f $script:Passes.Count, $script:Warns.Count, $script:Blockers.Count)
    if ($script:Blockers.Count -gt 0) {
        Write-Output 'BLOCKERS:'
        foreach ($b in $script:Blockers) { Write-Output "  - $b" }
        Write-Output ''
        Write-Output 'A BLOCKER means a roughcut task cannot be trusted to run correctly.'
        Write-Output 'Record it in the task directory. Do NOT install or rebuild anything'
        Write-Output 'without explicit user authorization (AGENTS.md section 3).'
    } else {
        Write-Output 'Environment is ready for a roughcut task.'
    }
}

if ($script:Blockers.Count -gt 0) { exit 2 }
exit 0
