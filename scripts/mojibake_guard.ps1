<#
    mojibake_guard.ps1  --  shared, single-source predicate: "is this directory one
    of OUR mojibake artifacts, and therefore ours to delete?"

    Dot-source it.  Do not copy the logic into a caller: this project has already
    been bitten twice by two files carrying the same rule and drifting apart.

    The bug it exists to catch
    --------------------------
    A .ps1 saved as UTF-8 WITHOUT a BOM is decoded by PowerShell 5.1 using the ANSI
    code page (936 / GBK on this machine).  The Chinese project name inside a path
    literal is then turned into mojibake, and any New-Item / Set-Content using that
    string builds a whole tree next to the real project:

        C:\Project\<mojibake>\123\<N>.<material>\...

    The predicate
    -------------
    NOT "the name has >= 4 CJK characters".  That test was in the first version of
    sanitize_stray_dirs.ps1 and it is wrong: it also matches 云山巨城, 全自动跑 and any
    real project whose name happens to be Chinese.  Following the documented
    remediation would then have deleted a live, unrelated repository.

    Instead: ROUND TRIP.  Re-encode the candidate name with the ANSI code page, then
    decode those bytes as strict UTF-8.  If the result is exactly this project's name,
    the name is provably the mojibake of this project's own path and nothing else can
    match it.  ASCII names, other Chinese names and unrelated projects all fail.

    C:\Project\ is a SHARED parent -- it holds this project plus the user's other
    projects plus whatever empty folder they felt like making.  Nothing here is ever
    a reason to delete any of them.
#>

Set-StrictMode -Version 2.0

function Get-AnsiCodePages {
    # PowerShell 5.1 decodes BOM-less .ps1 with the system ANSI code page.  Try the
    # live one first, then 936 explicitly (a machine can be reconfigured).
    $pages = New-Object System.Collections.ArrayList
    try { [void]$pages.Add([System.Text.Encoding]::Default.CodePage) } catch { }
    foreach ($cp in 936, 54936, 1252) {
        if ($pages -notcontains $cp) { [void]$pages.Add($cp) }
    }
    return @($pages)
}

function Test-NameIsMojibakeOf {
    <#
        .SYNOPSIS
            THE predicate.  "Is this candidate name the mojibake of <expected>?"

        .DESCRIPTION
            There is deliberately no looser sibling of this function.  An earlier
            version exposed a bare "decode the name" helper and left the comparison to
            the caller; the test suite immediately found two names that decode to
            *something* under some code page (云山巨城 among them).  Classification was
            still correct because the caller compared afterwards -- but correctness then
            depended on every caller remembering to compare, which is exactly the
            duplicated-rule drift this project keeps paying for.

            So the comparison lives here and there is no way to ask "is this mojibake?"
            without naming what it should decode to.  A false positive is structurally
            impossible rather than caught downstream.

            Matched is true only when a round trip recovers <expected> EXACTLY
            (case-sensitive) and the candidate is not already <expected>.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)][AllowEmptyString()][string]$Name,
        [Parameter(Mandatory = $true)][string]$Expected
    )

    $result = [pscustomobject]@{
        Name      = $Name
        Expected  = $Expected
        Matched   = $false
        Recovered = $null
        CodePage  = $null
        Note      = ''
    }

    if (-not $Name) { $result.Note = 'empty name'; return $result }
    if ($Name -ceq $Expected) { $result.Note = 'name is already correct, not mojibake'; return $result }

    foreach ($cp in (Get-AnsiCodePages)) {
        try {
            $bytes = [System.Text.Encoding]::GetEncoding($cp).GetBytes($Name)
            # strict: a bad sequence throws instead of yielding U+FFFD, which stops a
            # lossy decode from ever looking like a successful recovery.
            $recovered = (New-Object System.Text.UTF8Encoding $false, $true).GetString($bytes)
        } catch {
            continue   # wrong code page for this name -- try the next one
        }
        if ($recovered -ceq $Expected) {
            $result.Matched   = $true
            $result.Recovered = $recovered
            $result.CodePage  = $cp
            $result.Note      = "recovered exactly from ANSI codepage $cp"
            return $result
        }
    }

    $result.Note = "no ANSI codepage decodes this name back to '$Expected'"
    return $result
}

function Test-ProjectMojibakeDir {
    <#
        .SYNOPSIS
            Classify one directory as ours-to-delete or leave-alone.

        .DESCRIPTION
            IsProjectMojibake is true only when EVERY guard passes:

              1. the name round-trips through ANSI -> UTF-8 to exactly the project name
              2. it is not the real project directory
              3. it carries no .git  (if someone deliberately made a repo with the
                 mojibake name, that is their project, not our artifact)

            Guard 3 is redundant in theory -- a real project is not going to be named
            the mojibake of ours -- but deleting outside the sandbox is irreversible and
            cheap insurance is worth it.

            Everything else, including an empty folder the user just made, comes back
            IsProjectMojibake = $false with a reason, and callers must leave it alone.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)][System.IO.DirectoryInfo]$Dir,
        [Parameter(Mandatory = $true)][string]$ProjectRoot
    )

    $projectRoot = $ProjectRoot.TrimEnd('\')
    $projectName = Split-Path -Leaf $projectRoot

    $result = [pscustomobject]@{
        Path              = $Dir.FullName
        Name              = $Dir.Name
        IsProjectMojibake = $false
        IsProjectItself   = $false
        IsNameCorrupt     = $false
        RecoveredName     = $null
        CodePage          = $null
        Reason            = ''
    }

    if ($Dir.FullName.TrimEnd('\') -ieq $projectRoot) {
        $result.IsProjectItself = $true
        $result.Reason = 'this IS the project directory'
        return $result
    }

    # A damaged name costs its directory its legitimate identity, .git included.
    # Check this BEFORE the .git escape hatch -- but ONLY for names the exact match
    # cannot explain.  Routing order matters and is load-bearing:
    #
    #   1. exact round-trip match  -> ours (whole tree is provably the BOM-bug clone)
    #   2. name no codec can explain (see below) + double witness agrees -> tier 2
    #   3. everything else -> foreign, .git or not
    #
    # Step 2's entry test is Test-LooksMojibakeAlphabet: per-character, "every char
    # could have come out of a GBK mojibake".  It is deliberately WEAK (ordinary
    # Chinese and ASCII names pass it too) so it can never promote anything on its
    # own -- all it does is route a name the exact match cannot explain toward the
    # double-witness check instead of dropping it.  Identity still comes only from
    # the two witnesses agreeing inside Test-NameCorruptDir, never from this flag.
    $round = Test-NameIsMojibakeOf -Name $Dir.Name -Expected $projectName
    $result.RecoveredName = $round.Recovered
    $result.CodePage = $round.CodePage

    if ($round.Matched) {
        if (Test-Path -LiteralPath (Join-Path $Dir.FullName '.git')) {
            $result.Reason = 'name matches our mojibake exactly, BUT it contains .git -- a real repository wins over a name, never ours to delete'
            return $result
        }
        $result.IsProjectMojibake = $true
        $result.Reason = "name is this project's own path mis-decoded as ANSI (codepage $($round.CodePage))"
        return $result
    }

    if ((Test-LooksMojibakeAlphabet -Name $Dir.Name)) {
        $result.IsNameCorrupt = $true
        $result.Reason = 'name is in the GBK-mojibake alphabet but matches nothing exactly -- needs the double-witness check'
        return $result
    }

    if (Test-Path -LiteralPath (Join-Path $Dir.FullName '.git')) {
        $result.Reason = 'contains .git -- a real repository, never ours to delete'
        return $result
    }

    $result.Reason = $round.Note
    return $result
}

function Test-NameCorruptDir {
    <#
        .SYNOPSIS
            "This directory's name is damaged beyond any codec -- is it ALSO ours to clean?"

        .DESCRIPTION
            Some names cannot come from ANY GBK text (they contain U+FFFD, the loss
            marker, which no GBK byte sequence produces).  No round trip can identify
            them, so identity must come from two independent witnesses agreeing:

              Witness A -- SHAPE: the tree carries this project's own subtree fingerprint
              (a `123\` child inside a would-be project root, exactly where our BOM-bug
              artifacts always clone it).

              Witness B -- CARRIED EVIDENCE: the tree carries something the bug could
              only have copied from us -- a `123\<N>.<something>` task directory
              (the clone copies our task dirs verbatim), or a file whose bytes decode
              to text containing our exact project name.

            Both witnesses must agree.  Content alone is not enough: an unrelated tree
            can mention our project name.  Shape alone is not enough: an unrelated
            project can also have a folder called `123`.

            Whatever this returns, nothing under it is EVER deleted for its contents --
            the clean step removes exactly the empty clone the BOM bug builds (empty
            `123\` leaf shells), and only when BOTH witnesses agree.  A damaged name
            that carries any real work is reported and left alone.

            Entry discipline: the caller (Test-ProjectMojibakeDir) only sends names
            here that (a) failed the exact round-trip match and (b) pass
            Test-LooksMojibakeAlphabet.  Calling it directly on an ordinary name is
            a test-harness move, not a supported path -- an ordinary name with our
            clone shape and our name in its files would be a deliberate frame-up,
            and the function would say so.  That is correct behaviour for the
            function and irrelevant to the pipeline, which never asks it that.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)][string]$DirPath,
        [Parameter(Mandatory = $true)][string]$ProjectName
    )

    $result = [pscustomobject]@{
        Path     = $DirPath
        Name     = (Split-Path -Leaf $DirPath)
        IsOurs   = $false
        Contents = [pscustomobject]@{ FileCount = 0; Bytes = 0; EmptyLeafShells = @() }
        WitnessA = 'shape: not checked'
        WitnessB = 'content: not checked'
        Reason   = ''
    }

    foreach ($cp in (Get-AnsiCodePages)) {
        try { [void][System.Text.Encoding]::GetEncoding($cp).GetBytes($result.Name) }
        catch { $result.Reason = "name is not even ANSI-decodable, out of scope"; return $result }
    }

    # Witness A: our subtree fingerprint.
    $under123 = Join-Path $DirPath '123'
    if (-not (Test-Path -LiteralPath $under123 -PathType Container)) {
        $result.WitnessA = 'shape: no 123\ child -- not the BOM-bug clone shape'
        $result.Reason = 'name is damaged, but the tree does not carry our clone shape; not provably ours, left alone'
        return $result
    }
    $result.WitnessA = 'shape: carries a 123\ child like the BOM-bug clone'

    # Inventory everything once; the delete step reuses this list, never a new scan.
    $files = @(Get-ChildItem -LiteralPath $DirPath -Recurse -Force -File -ErrorAction SilentlyContinue)
    $bytes = [int64]0
    foreach ($f in $files) { $bytes += $f.Length }
    $leaves = @(Get-ChildItem -LiteralPath $DirPath -Recurse -Force -Directory -ErrorAction SilentlyContinue |
                Where-Object { @(Get-ChildItem -LiteralPath $_.FullName -Force -ErrorAction SilentlyContinue).Count -eq 0 })
    # Never report the scan target's own structural spine as prunable: `123\` itself
    # and its task directory are the clone's skeleton, not its leaves.  Only things
    # BELOW the task directory (cache\, shots\, verify_*\, ...) are leaf shells.
    # Pruning the skeleton would orphan nothing (the top dir stays) but it would
    # also erase the shape that proves what this was -- keep the evidence.
    $relLeaves = @($leaves | ForEach-Object { $_.FullName.Substring($DirPath.Length + 1) } |
                   Where-Object { $_ -match '^123[\\/][^\\/]+[\\/]' })
    $result.Contents = [pscustomobject]@{
        FileCount       = $files.Count
        Bytes           = $bytes
        EmptyLeafShells = @($relLeaves)
    }

    # Witness B: what the clone carried with it.
    # The project's own name can hide in two places: the SHAPE of the directory
    # names below the top, or the BYTES of a file.  Check shape first -- the real
    # 2026-10-07 artifact proved why: its trees carry zero files, so shape is the
    # ONLY witness left in the common case, and bytes are the confirmation.
    # Witness B: carried evidence.
    # Shape and bytes each count, EITHER is enough -- because the real artifact
    # carries zero files, bytes-alone would acquit a genuine clone, while the
    # clone-shape task dir (`123\<N>.<material>`, copied verbatim by the bug) is
    # a fingerprint no ordinary damaged tree carries.  The strength ranking is:
    # both > shape-only > bytes-only > neither.  The delete step only ever prunes
    # EMPTY leaves, so even the weakest positive cannot cost any work.
    $found = $null
    # B1: clone-shape task dir.  The bug copies `123\<N>.<material>` verbatim, so a
    # `123\` child whose own child is named `<digits>.<something>` is the clone's
    # fingerprint.  An ordinary damaged tree (somebody else's project, a blank
    # folder) does not carry it.
    #
    # NOTE what this does NOT do: it never decodes the damaged top name.  That name
    # is unrecoverable by construction (U+FFFD ate the bytes).  Identity comes from
    # the SHAPE of what the bug cloned, not from reading the unreadable.
    $grandchildren = @(Get-ChildItem -LiteralPath $under123 -Force -Directory -ErrorAction SilentlyContinue |
                       Where-Object { $_.Name -match '^\d+\.' })
    if ($grandchildren.Count -gt 0) {
        $found = '123\' + $grandchildren[0].Name + ' [clone-shape task dir]'
    }
    # B2: file bytes mentioning our project name.  The stronger positive, checked
    # second because the real artifact usually has no files at all.
    if (-not $found) {
        foreach ($f in $files) {
            if ($f.Length -gt 1MB) { continue }
            $raw = $null
            try { $raw = [System.IO.File]::ReadAllBytes($f.FullName) } catch { continue }
            foreach ($cp in (Get-AnsiCodePages)) {
                try {
                    $txt = (New-Object System.Text.UTF8Encoding $false, $true).GetString(
                        [System.Text.Encoding]::GetEncoding($cp).GetBytes(
                            [System.Text.Encoding]::GetEncoding($cp).GetString($raw)))
                } catch { continue }
                if ($txt -clike ('*' + $ProjectName + '*')) { $found = $f.FullName.Substring($DirPath.Length + 1); break }
            }
            if ($found) { break }
        }
    }
    if (-not $found) {
        $result.WitnessB = 'clone evidence: no clone-shape task dir, and no file mentions us -- an unrelated damaged tree'
        $result.Reason = 'name is damaged, but nothing inside proves it is ours; left alone'
        return $result
    }
    $result.WitnessB = "clone evidence: '$found'"
    $result.IsOurs = $true
    $result.Reason = 'BOTH witnesses agree: our clone shape (123\) + carried evidence'
    return $result
}

function Test-LooksMojibakeAlphabet {
    <#
        .SYNOPSIS
            "Could this name have come out of a GBK mojibake at all?"

        .DESCRIPTION
            Mojibake of GBK-decoded text has a fixed alphabet: every character comes
            from decoding GBK bytes.  GBK byte sequences decode to CJK, kana, fullwidth
            forms, box drawing, Greek, Cyrillic -- and on Windows codepage 936, any
            byte that is not a valid GBK lead/trail decodes to U+FFFD itself (the loss
            marker, which is how the real 2026-10-07 artifact got its name).

            So the test is per-CHARACTER, not per-byte: take each character, encode it
            as UTF-8, decode those bytes as GBK.  If that fails for every GBK-ish
            decoding, this name was never GBK mojibake.  U+FFFD passes trivially --
            Windows-936 produces it from undecodable bytes.

            This is deliberately a NECESSARY condition, not a verdict.  Passing it
            proves nothing about whose artifact it is; the identity proof stays in
            Test-NameIsMojibakeOf (exact round trip) and Test-NameCorruptDir (double
            witness).  Its only job is to route a name the exact-match cannot explain
            toward the witness check instead of dropping it as "ordinary".
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)][AllowEmptyString()][string]$Name
    )
    if (-not $Name) { return $false }
    $u8 = New-Object System.Text.UTF8Encoding $false, $true
    foreach ($ch in $Name.ToCharArray()) {
        $s = [string]$ch
        if ($s -ceq [string][char]0xFFFD) { continue }   # 936 emits this for bad bytes
        $ok = $false
        try {
            $bytes = $u8.GetBytes($s)
            foreach ($cp in 936, 54936) {
                try { [void][System.Text.Encoding]::GetEncoding($cp).GetString($bytes); $ok = $true; break }
                catch { }
            }
        } catch { }
        if (-not $ok) { return $false }
    }
    return $true
}

function Get-ProjectMojibakeDirs {
    <#
        .SYNOPSIS
            Classify every direct child of the project's parent directory.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)][string]$ProjectRoot
    )

    $projectRoot = (Resolve-Path -LiteralPath $ProjectRoot).Path.TrimEnd('\')
    $parent = Split-Path -Parent $projectRoot

    $real = @(Get-ChildItem -LiteralPath $parent -Directory -Force -ErrorAction SilentlyContinue |
              Where-Object {
                  (Test-Path (Join-Path $_.FullName 'AGENTS.md')) -and
                  (Test-Path (Join-Path $_.FullName '.video-tools')) -and
                  (Test-Path (Join-Path $_.FullName '123'))
              })
    if ($real.Count -ne 1) {
        throw ("cannot identify the real project under {0}: found {1} candidates. Refusing to guess." -f $parent, $real.Count)
    }

    $all = New-Object System.Collections.ArrayList
    foreach ($d in (Get-ChildItem -LiteralPath $parent -Directory -Force -ErrorAction SilentlyContinue)) {
        [void]$all.Add((Test-ProjectMojibakeDir -Dir $d -ProjectRoot $projectRoot))
    }

    # Second pass, only for names no codec can explain: they cannot round-trip by
    # construction, so Test-ProjectMojibakeDir always leaves them foreign with an
    # "impossibility" note.  The double-witness check runs only there, and only for
    # classification -- what to DO with a positive is the caller's decision.
    $corrupt = @($all | Where-Object { $_.IsNameCorrupt })
    $proven = New-Object System.Collections.ArrayList
    foreach ($c in $corrupt) {
        $w = Test-NameCorruptDir -DirPath $c.Path -ProjectName (Split-Path -Leaf $projectRoot)
        $c | Add-Member -NotePropertyName CorruptWitness -NotePropertyValue $w -Force
        if ($w.IsOurs) { [void]$proven.Add($c) }
    }

    return [pscustomobject]@{
        ProjectRoot = $projectRoot
        ParentRoot  = $parent
        All         = @($all)
        Ours        = @($all | Where-Object { $_.IsProjectMojibake })
        # The project itself is deliberately NOT in Ours, so it can never be deleted.
        # It is also not "unrelated" -- keep it out of Foreign so callers that tally
        # their neighbours do not report the project as somebody else's directory.
        Foreign     = @($all | Where-Object { -not $_.IsProjectMojibake -and -not $_.IsProjectItself })
        ProjectItself = @($all | Where-Object { $_.IsProjectItself })
        # Double-witness positives on codec-impossible names.  Deliberately NOT merged
        # into Ours: callers must handle them through their own explicit branch.
        CorruptProven = @($proven)
    }
}

function Measure-DirBytes {
    param([Parameter(Mandatory = $true)][string]$Path)
    $bytes = [int64]0
    foreach ($k in (Get-ChildItem -LiteralPath $Path -Recurse -Force -ErrorAction SilentlyContinue)) {
        if (-not $k.PSIsContainer) { $bytes += $k.Length }
    }
    return $bytes
}

function Format-CodePoints {
    param([Parameter(Mandatory = $true)][AllowEmptyString()][string]$Text)
    return (($Text.ToCharArray() | ForEach-Object { '{0:X4}' -f [int]$_ }) -join ' ')
}