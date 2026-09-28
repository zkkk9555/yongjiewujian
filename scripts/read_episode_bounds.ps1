<#
    read_episode_bounds.ps1  --  print the cut list of a combat-episode timeline.

    Why this exists
    ---------------
    seg_render_master.sh used to carry its cut points in a `case "$JOB"` block
    with the timecodes for jobs 840/841/842 typed in by hand, and it read the
    episode count through the project venv's python.exe.  Both are dead ends:
    the venv interpreter cannot start (see the preflight BLOCKER), and hardcoded
    timecodes mean the renderer only works for the three jobs it was written for.
    The cut list already lives in the timeline JSON, so read it from there.

    PowerShell does the JSON parsing rather than grep because the timeline's
    boundary_reason / notes fields are long Chinese prose; matching
    "source_start": textually would pick up prose, and the project root path is
    non-ASCII, which invites encoding trouble on the bash side.

    Usage
    -----
        powershell -NoProfile -ExecutionPolicy Bypass -File read_episode_bounds.ps1 <timeline.json>

    Output (exit 0):
        N=<episode count>
        S=<source_start> E=<source_end>      (one line per episode, in timeline order)
        PROGRAM=<sum of (end - start)>

    Exit 1 with a [FAIL] line if the file is missing, unreadable, not JSON, or
    holds no episodes.  Exit 2 on argument errors.
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $true, Position = 0)]
    [string]$Timeline
)

$ErrorActionPreference = 'Stop'

try { [Console]::OutputEncoding = [System.Text.Encoding]::UTF8 } catch { }

if (-not (Test-Path -LiteralPath $Timeline -PathType Leaf)) {
    [Console]::Error.WriteLine("[FAIL] timeline not found: $Timeline")
    exit 1
}

# Read as UTF-8 explicitly.  Get-Content without -Encoding decodes with the ANSI
# code page on PowerShell 5.1, which corrupts the Chinese prose in this file and
# then fails to parse the JSON.
try {
    $raw = [System.IO.File]::ReadAllText($Timeline, [System.Text.Encoding]::UTF8)
} catch {
    [Console]::Error.WriteLine("[FAIL] cannot read timeline: $($_.Exception.Message)")
    exit 1
}

try {
    $data = $raw | ConvertFrom-Json
} catch {
    [Console]::Error.WriteLine("[FAIL] timeline is not valid JSON: $($_.Exception.Message)")
    exit 1
}

# The production schema (naraka-combat-roughcut-qa/v1) names the array
# combat_episodes.  A bare top-level array and the shorter "episodes" key are
# accepted too, because hand-written test timelines in the wild use them.
$episodes = $null
if ($data -is [System.Array]) {
    $episodes = $data
} elseif ($null -ne $data.PSObject.Properties['combat_episodes']) {
    $episodes = $data.combat_episodes
} elseif ($null -ne $data.PSObject.Properties['episodes']) {
    $episodes = $data.episodes
}

if ($null -eq $episodes -or $episodes.Count -eq 0) {
    [Console]::Error.WriteLine('[FAIL] no combat_episodes array found in timeline')
    exit 1
}

$total = 0.0
$lines = New-Object System.Collections.ArrayList
$i = 0
foreach ($ep in $episodes) {
    $i++
    $hasS = $null -ne $ep.PSObject.Properties['source_start']
    $hasE = $null -ne $ep.PSObject.Properties['source_end']
    if (-not ($hasS -and $hasE)) {
        [Console]::Error.WriteLine("[FAIL] episode #$i is missing source_start/source_end; cannot cut it")
        exit 1
    }
    $s = [double]$ep.source_start
    $e = [double]$ep.source_end
    if ($e -le $s) {
        [Console]::Error.WriteLine(("[FAIL] episode #{0} ({1}) has source_end {2} <= source_start {3}; refusing to render a negative-length segment" -f $i, $ep.id, $e, $s))
        exit 1
    }
    [void]$lines.Add(('S={0} E={1}' -f $s, $e))
    $total += ($e - $s)
}

Write-Output ('N=' + $episodes.Count)
foreach ($l in $lines) { Write-Output $l }
Write-Output ('PROGRAM=' + [math]::Round($total, 3))
exit 0
