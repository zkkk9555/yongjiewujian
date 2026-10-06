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
        RecoveredName     = $null
        CodePage          = $null
        Reason            = ''
    }

    if ($Dir.FullName.TrimEnd('\') -ieq $projectRoot) {
        $result.IsProjectItself = $true
        $result.Reason = 'this IS the project directory'
        return $result
    }

    if (Test-Path -LiteralPath (Join-Path $Dir.FullName '.git')) {
        $result.Reason = 'contains .git -- a real repository, never ours to delete'
        return $result
    }

    $round = Test-NameIsMojibakeOf -Name $Dir.Name -Expected $projectName
    $result.RecoveredName = $round.Recovered
    $result.CodePage = $round.CodePage

    if (-not $round.Matched) {
        $result.Reason = $round.Note
        return $result
    }

    $result.IsProjectMojibake = $true
    $result.Reason = "name is this project's own path mis-decoded as ANSI (codepage $($round.CodePage))"
    return $result
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