<#
    test_mojibake_guard.sh / test_mojibake_guard.ps1
    Regression for the guard added 2026-10-06.

    The bug it locks down
    ---------------------
    sanitize_stray_dirs.ps1 deleted EVERY directory next to the project when given
    -Remove.  C:\Project\ is a shared parent holding the user's other projects, so the
    documented remediation would have deleted a live unrelated repository (云山巨城).
    The original predicate ("name has >= 4 CJK characters") matched it.

    This test builds a throwaway fixture under .scratch\ -- never under the real
    project parent, because creating a directory there would itself be the very bug.
#>

[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'
try { [Console]::OutputEncoding = [System.Text.Encoding]::UTF8 } catch { }

$repoRoot = Split-Path -Parent $PSScriptRoot
. (Join-Path $PSScriptRoot 'mojibake_guard.ps1')

$fixture = Join-Path $repoRoot '.scratch\mojibake-guard-test'
if (Test-Path -LiteralPath $fixture) { Remove-Item -LiteralPath $fixture -Recurse -Force }
$parent  = Join-Path $fixture 'parent'
New-Item -ItemType Directory -Path $parent -Force | Out-Null

# The mojibake name, produced the way the bug produces it: this file is UTF-8+BOM, so
# we compute it rather than hardcode it -- that also proves the round trip is real.
$realName = '永劫无间'
$mojiName = [System.Text.Encoding]::GetEncoding(936).GetString(
    (New-Object System.Text.UTF8Encoding $false, $true).GetBytes($realName))
if ($mojiName -ceq $realName) { throw 'fixture broken: mojibake equals the real name' }

function New-Dir { param([string]$Name)
    $p = Join-Path $parent $Name
    New-Item -ItemType Directory -Path $p -Force | Out-Null
    return $p
}

# the real project: identified by CONTENTS, never by name
$real = New-Dir $realName
New-Item -ItemType Directory -Path (Join-Path $real '123')     -Force | Out-Null
New-Item -ItemType Directory -Path (Join-Path $real '.video-tools') -Force | Out-Null
Set-Content -LiteralPath (Join-Path $real 'AGENTS.md') -Value 'x' -Encoding UTF8

New-Dir $mojiName                                  | Out-Null   # OURS
[void](New-Dir '云山巨城')                                                # foreign project
[void](New-Dir 'new blank folder')                                       # user made this
[void](New-Dir 'MyOtherProject')                                         # foreign, ascii
$mojiWithGit = New-Dir ($mojiName + 'X')                                # mojibake-ish BUT has .git
New-Item -ItemType Directory -Path (Join-Path $mojiWithGit '.git') -Force | Out-Null

$pass = 0; $fail = 0
function Check { param([string]$Name, [bool]$Ok, [string]$Detail)
    if ($Ok) { $script:pass++; Write-Output ("  PASS  {0}" -f $Name) }
    else     { $script:fail++; Write-Output ("  FAIL  {0}  -- {1}" -f $Name, $Detail) }
}

Write-Output '=== mojibake_guard: classification ==='
$scan = Get-ProjectMojibakeDirs -ProjectRoot $real
$ours = @($scan.Ours | ForEach-Object { $_.Name })
$foreign = @($scan.Foreign | ForEach-Object { $_.Name })

Check 'the real project is never classified as ours' `
    (-not ($ours -contains $realName)) "ours = $($ours -join ',')"
Check 'exactly one dir is ours (the mojibake)' `
    ($ours.Count -eq 1) "ours = $($ours -join ',')"
Check 'the mojibake dir IS ours' `
    ($ours -contains $mojiName) "ours = $($ours -join ',')"
Check '云山巨城 is left alone' `
    (-not ($ours -contains '云山巨城')) "ours = $($ours -join ',')"
Check 'a blank folder the user made is left alone' `
    (-not ($ours -contains 'new blank folder')) "ours = $($ours -join ',')"
Check 'an unrelated ascii project is left alone' `
    (-not ($ours -contains 'MyOtherProject')) "ours = $($ours -join ',')"
Check 'a mojibake-named dir WITH .git is left alone (guard 3)' `
    (-not ($ours -contains ($mojiName + 'X'))) "ours = $($ours -join ',')"
Check 'every foreign dir carries a reason' `
    (@($scan.Foreign | Where-Object { -not $_.Reason }).Count -eq 0) 'a foreign dir had no reason'
# The precheck reports "N unrelated directories" from this count.  If the project
# itself leaked into it, every run would claim one phantom unrelated neighbour.
Check 'the project is NOT counted as an unrelated neighbour' `
    (@($scan.Foreign | Where-Object { $_.IsProjectItself }).Count -eq 0) 'the project is in Foreign'
Check 'the neighbour tally counts only real neighbours' `
    ($scan.Foreign.Count -eq 4) ("tally = " + $scan.Foreign.Count + " (expected 4: mojibake-with-git, 云山巨城, blank folder, ascii project)")

Write-Output ''
Write-Output '=== mojibake_guard: the predicate ==='
$rt = Test-NameIsMojibakeOf -Name $mojiName -Expected $realName
Check 'the mojibake name matches the project name' `
    $rt.Matched ("note = " + $rt.Note)
Check 'round trip recovers the project name exactly' `
    ($null -ne $rt.Recovered -and $rt.Recovered -ceq $realName) ("recovered = " + $rt.Recovered)
Check '云山巨城 is NOT our mojibake (this is the regression)' `
    (-not (Test-NameIsMojibakeOf -Name '云山巨城'      -Expected $realName).Matched) 'false positive'
Check '全自动跑 is NOT our mojibake' `
    (-not (Test-NameIsMojibakeOf -Name '全自动跑' -Expected $realName).Matched) 'false positive'
Check 'an ascii project name is NOT our mojibake' `
    (-not (Test-NameIsMojibakeOf -Name 'MyProject'    -Expected $realName).Matched) 'false positive'
Check 'a name needing invalid utf8 is NOT our mojibake' `
    (-not (Test-NameIsMojibakeOf -Name ([string][char]0x00D5 + 'abc') -Expected $realName).Matched) 'false positive'
Check 'the correct name is not treated as its own mojibake' `
    (-not (Test-NameIsMojibakeOf -Name $realName -Expected $realName).Matched) 'false positive'
# CJK has no case, so exercising -ceq needs an ASCII expected value.
Check 'matching is case sensitive (ascii)' `
    (-not (Test-NameIsMojibakeOf -Name 'mYpRoJeCt' -Expected 'MyProject').Matched) 'false positive'
# one character off from the real mojibake must not match
$offByOne = $mojiName.Substring(0, $mojiName.Length - 1) + [string][char]0x6C38
Check 'a name one character off the mojibake does NOT match' `
    (-not (Test-NameIsMojibakeOf -Name $offByOne -Expected $realName).Matched) 'false positive'

Write-Output ''
Write-Output '=== END TO END: the real script, with -Remove, against the fixture ==='
# This is the assertion that matters.  Classification tests can pass while the delete
# path still does something else, and in the first version it deleted every sibling.
$sanitize = Join-Path $PSScriptRoot 'sanitize_stray_dirs.ps1'
& $sanitize -Remove -ProjectRoot $real *> $null
$removeExit = $LASTEXITCODE

Check 'the mojibake dir WAS deleted' `
    (-not (Test-Path -LiteralPath (Join-Path $parent $mojiName))) 'it survived -Remove'
Check 'the real project survived' `
    (Test-Path -LiteralPath $real) 'the project itself was deleted'
Check '云山巨城 survived -Remove  <-- the regression' `
    (Test-Path -LiteralPath (Join-Path $parent '云山巨城')) 'it was deleted by -Remove'
Check 'a blank folder the user made survived -Remove' `
    (Test-Path -LiteralPath (Join-Path $parent 'new blank folder')) 'a blank folder was deleted'
Check 'an unrelated ascii project survived -Remove' `
    (Test-Path -LiteralPath (Join-Path $parent 'MyOtherProject')) 'an unrelated project was deleted'
Check 'a mojibake-named dir WITH .git survived -Remove' `
    (Test-Path -LiteralPath $mojiWithGit) 'a real repo was deleted'
Check 'sanitize exits 0 when it did what it was asked' `
    ($removeExit -eq 0) "exit = $removeExit"

# and with nothing of ours left, -Remove must still be a no-op rather than a sweep
& $sanitize -Remove -ProjectRoot $real *> $null
Check 'a second -Remove with nothing of ours left deletes nothing' `
    ((Test-Path -LiteralPath (Join-Path $parent '云山巨城')) -and (Test-Path -LiteralPath (Join-Path $parent 'new blank folder'))) 'it deleted on an empty plan'

Write-Output ''
Write-Output ("=== {0} passed, {1} failed ===" -f $pass, $fail)

# The fixture is regenerable; leave the tree in place only when something failed so it
# can be inspected.
if ($fail -eq 0) { Remove-Item -LiteralPath $fixture -Recurse -Force -ErrorAction SilentlyContinue }
exit $(if ($fail -eq 0) { 0 } else { 1 })