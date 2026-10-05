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
        NEPISODES=<episode count>
        N=<cut-segment count>                 (N >= NEPISODES: holes split an episode)
        S=<source_start> E=<source_end>       (one line per cut segment, in timeline order)
        PROGRAM=<sum of (end - start), holes deducted>

    In-segment holes
    ----------------
    A combat episode may declare `excluded_inside` -- pauses punched out of the
    middle of one fight (a loot panel, a menu, a dead stop).  The spec makes
    leaving one un-excavated a delivery-blocking violation, and the QA gate
    deducts them, so this reader must too or the 4K master and the gate would
    disagree by exactly the excavated seconds.

    Each hole splits its episode into several contiguous cut segments, all
    emitted in order.  This script used to emit one S=/E= line per episode and
    PROGRAM = sum(end - start), which made holes structurally impossible to
    honour: the 4K master would keep the pauses AND fail verify_master.sh's
    duration check.  seg_render_master.sh needs no change -- it already cuts
    whatever S=/E= pairs it is given and concatenates them.

    This is the same rule as episode_geometry.py; that module is the Python
    side of one formula, not a second definition.  scripts/test_insegment_holes.sh
    runs both against one fixture and fails if they ever diverge.

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

# --- coverage: kept + deleted must tile the whole source --------------------
# This is the second, independent implementation of the same rule as
# qa_gate.py's `coverage_complete`.  Two implementations on purpose: qa_gate
# proves the rule, this reader proves the 4K chain actually enforces it, and
# scripts/test_coverage_gate.sh fails if they ever disagree.
#
# Measured on 864 v6 before this check existed: deleting any one of its 7 real
# battles left every gate green, the largest being 233.45 s = 35% of the
# programme.  Nothing compared kept + deleted against the source duration, so a
# whole fight could vanish and the render would simply be shorter.
#
# Stays silent (no failure) when source_duration is unknown or no deletions are
# declared, so hand-written timelines keep working.  A gate stricter than
# reality is the same disease as no gate at all.
$COVERAGE_TOLERANCE_S = 0.25
$sourceDuration = $null
if (-not ($data -is [System.Array]) -and $null -ne $data.PSObject.Properties['source_duration']) {
    $sd = 0.0
    if ([double]::TryParse([string]$data.source_duration, [ref]$sd) -and $sd -gt 0) { $sourceDuration = $sd }
}
$deletions = New-Object System.Collections.ArrayList
if (-not ($data -is [System.Array]) -and $null -ne $data.PSObject.Properties['deleted_intervals'] -and $null -ne $data.deleted_intervals) {
    foreach ($d in @($data.deleted_intervals)) {
        if ($null -eq $d -or $null -eq $d.PSObject.Properties['start'] -or $null -eq $d.PSObject.Properties['end']) { continue }
        $ds = 0.0; $de = 0.0
        if ([double]::TryParse([string]$d.start, [ref]$ds) -and [double]::TryParse([string]$d.end, [ref]$de) -and $de -gt $ds) {
            # PSCustomObject, never a bare pair: a pipeline unrolls a collection
            # whose element IS an array, which is the bug documented further down.
            [void]$deletions.Add([PSCustomObject]@{ Start = $ds; End = $de })
        }
    }
}
if ($null -ne $sourceDuration -and $deletions.Count -gt 0) {
    $spans = New-Object System.Collections.ArrayList
    foreach ($ep in $episodes) {
        if ($null -eq $ep.PSObject.Properties['source_start'] -or $null -eq $ep.PSObject.Properties['source_end']) { continue }
        [void]$spans.Add([PSCustomObject]@{ Start = [double]$ep.source_start; End = [double]$ep.source_end })
    }
    foreach ($d in $deletions) { [void]$spans.Add($d) }

    $over = $null
    foreach ($s in $spans) {
        if ($s.End -gt ($sourceDuration + $COVERAGE_TOLERANCE_S)) {
            [Console]::Error.WriteLine(("[FAIL] coverage: span [{0},{1}] runs past source_duration {2}" -f $s.Start, $s.End, $sourceDuration))
            exit 1
        }
    }
    # A second that is both kept and declared deleted is a double declaration:
    # the render will show it while the ledger says it was cut.  Checked before
    # the union walk because merging would silently absorb the disagreement.
    foreach ($ep in $episodes) {
        if ($null -eq $ep.PSObject.Properties['source_start'] -or $null -eq $ep.PSObject.Properties['source_end']) { continue }
        $es = [double]$ep.source_start
        $ee = [double]$ep.source_end
        foreach ($d in $deletions) {
            $overlap = [math]::Min($ee, $d.End) - [math]::Max($es, $d.Start)
            if ($overlap -gt $COVERAGE_TOLERANCE_S) {
                [Console]::Error.WriteLine(("[FAIL] coverage: kept [{0},{1}] also declared deleted [{2},{3}] by {4}s" -f `
                    $es, $ee, $d.Start, $d.End, [math]::Round($overlap, 2)))
                exit 1
            }
        }
    }
    $mS = New-Object System.Collections.ArrayList
    $mE = New-Object System.Collections.ArrayList
    foreach ($s in ($spans | Sort-Object Start)) {
        $last = $mS.Count - 1
        if ($mS.Count -gt 0 -and $s.Start -le ($mE[$last] + 0.000000001)) {
            if ($s.End -gt $mE[$last]) { $mE[$last] = $s.End }
        } else {
            [void]$mS.Add($s.Start)
            [void]$mE.Add($s.End)
        }
    }
    $offenders = New-Object System.Collections.ArrayList
    if ($mS[0] -gt $COVERAGE_TOLERANCE_S) {
        [void]$offenders.Add(("[0.00,{0}] {1}s" -f $mS[0], [math]::Round($mS[0], 2)))
    }
    for ($k = 0; $k -lt $mS.Count - 1; $k++) {
        $gap = $mS[$k + 1] - $mE[$k]
        if ($gap -gt $COVERAGE_TOLERANCE_S) {
            [void]$offenders.Add(("[{0},{1}] {2}s" -f $mE[$k], $mS[$k + 1], [math]::Round($gap, 2)))
        }
    }
    $tail = $sourceDuration - $mE[$mE.Count - 1]
    if ($tail -gt $COVERAGE_TOLERANCE_S) {
        [void]$offenders.Add(("[{0},{1}] {2}s" -f ($sourceDuration - $tail), $sourceDuration, [math]::Round($tail, 2)))
    }
    if ($offenders.Count -gt 0) {
        [Console]::Error.WriteLine(("[FAIL] coverage: {0} undeclared gap(s) in [{1}s] -- kept + deleted must tile the source. First: {2}{3}" -f `
            $offenders.Count, $sourceDuration, $offenders[0], $(if ($offenders.Count -gt 1) { " (+$($offenders.Count - 1) more)" } else { '' })))
        [Console]::Error.WriteLine('[FAIL] a battle may have been dropped from the timeline without being declared deleted')
        exit 1
    }
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

    # --- collect and validate this episode's in-segment holes -----------------
    # Holes are carried as PSCustomObject, never as a bare @(start, end) pair.
    # A PowerShell pipeline unrolls a collection whose element IS an array, so a
    # list of pairs piped into Sort-Object arrives as loose scalars: one hole
    # becomes two, $h[1] is $null, and the merge silently emits a duplicate cut
    # segment.  That produced PROGRAM=1228.5 instead of 1090.5 on task 861.
    # Objects survive the pipeline intact, so use objects.
    $holes = New-Object System.Collections.ArrayList
    if ($null -ne $ep.PSObject.Properties['excluded_inside'] -and $null -ne $ep.excluded_inside) {
        foreach ($h in @($ep.excluded_inside)) {
            if ($null -eq $h -or $null -eq $h.PSObject.Properties['start'] -or $null -eq $h.PSObject.Properties['end']) {
                [Console]::Error.WriteLine(("[FAIL] episode #{0} ({1}) has a malformed excluded_inside entry; each hole needs start and end" -f $i, $ep.id))
                exit 1
            }
            $hs = [double]$h.start
            $he = [double]$h.end
            if ($he -le $hs) {
                [Console]::Error.WriteLine(("[FAIL] episode #{0} ({1}) hole [{2},{3}] has end <= start" -f $i, $ep.id, $hs, $he))
                exit 1
            }
            if ($hs -lt $s -or $he -gt $e) {
                [Console]::Error.WriteLine(("[FAIL] episode #{0} ({1}) hole [{2},{3}] falls outside episode bounds [{4},{5}]" -f $i, $ep.id, $hs, $he, $s, $e))
                exit 1
            }
            [void]$holes.Add([PSCustomObject]@{ Start = $hs; End = $he })
        }
    }

    # Merge overlapping/adjacent holes so the walk below stays simple.
    # Two parallel ArrayLists of doubles, not a list of pairs: assigning into a
    # nested indexer of an ArrayList element is unreliable on PowerShell 5.1
    # (it throws NullReferenceException), which cost one debugging round.
    $mStart = New-Object System.Collections.ArrayList
    $mEnd = New-Object System.Collections.ArrayList
    foreach ($h in ($holes | Sort-Object Start)) {
        $last = $mStart.Count - 1
        if ($mStart.Count -gt 0 -and $h.Start -le $mEnd[$last]) {
            if ($h.End -gt $mEnd[$last]) { $mEnd[$last] = $h.End }
        } else {
            [void]$mStart.Add($h.Start)
            [void]$mEnd.Add($h.End)
        }
    }

    $covered = 0.0
    for ($k = 0; $k -lt $mStart.Count; $k++) { $covered += ($mEnd[$k] - $mStart[$k]) }
    if ($mStart.Count -gt 0 -and $covered -ge ($e - $s)) {
        [Console]::Error.WriteLine(("[FAIL] episode #{0} ({1}) holes cover the whole episode [{2},{3}]; nothing would be left to render" -f $i, $ep.id, $s, $e))
        exit 1
    }

    # --- emit the cut segments this episode actually becomes ------------------
    if ($mStart.Count -eq 0) {
        [void]$lines.Add(('S={0} E={1}' -f $s, $e))
        $total += ($e - $s)
    } else {
        $cursor = $s
        for ($k = 0; $k -lt $mStart.Count; $k++) {
            if ($mStart[$k] -gt $cursor) {
                [void]$lines.Add(('S={0} E={1}' -f $cursor, $mStart[$k]))
                $total += ($mStart[$k] - $cursor)
            }
            if ($mEnd[$k] -gt $cursor) { $cursor = $mEnd[$k] }
        }
        if ($cursor -lt $e) {
            [void]$lines.Add(('S={0} E={1}' -f $cursor, $e))
            $total += ($e - $cursor)
        }
    }
}

Write-Output ('NEPISODES=' + $episodes.Count)
# N is the cut-segment count, which is what seg_render_master.sh compares its
# parsed pair count against.  It equals NEPISODES when no holes are declared.
Write-Output ('N=' + $lines.Count)
foreach ($l in $lines) { Write-Output $l }
Write-Output ('PROGRAM=' + [math]::Round($total, 3))
exit 0
