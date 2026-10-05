param(
  [Parameter(Mandatory=$true)][string]$Name,
  [Parameter(Mandatory=$true)][string]$VF,
  [Parameter(Mandatory=$true)][string]$ENC,
  [string]$Iopt = '',
  [int]$Jobs = 1,
  [int]$Repeat = 1,
  [switch]$Full240
)
# ASCII-only on purpose: a .ps1 holding non-ASCII bytes without a UTF-8 BOM is read as
# ANSI by PowerShell 5.1, and any CJK path literal inside turns into mojibake (AGENTS.md sec 1).
$ErrorActionPreference = 'Stop'
$here  = $PSScriptRoot
$FF    = (Get-ChildItem 'C:\Project' -Recurse -Filter 'ffmpeg.exe' -Depth 4 -ErrorAction SilentlyContinue |
           Where-Object { $_.FullName -like '*LosslessCut*' } | Select-Object -First 1).FullName
$SRC   = (Get-ChildItem 'E:\OBS' -Filter '2026-10-04 15*.mp4' | Select-Object -First 1).FullName
$outDir = Join-Path $here 'out'
New-Item -ItemType Directory -Force -Path $outDir | Out-Null

# NOTE: use objects, NOT nested array literals -- @(@(100,130),@(300,330)) FLATTENS in
# PowerShell to @(100,130,300,330), so $SEGS[$i][0] then silently evaluates to $null.
$SEGS = @(
  [pscustomobject]@{ s = 100;  e = 130  }, [pscustomobject]@{ s = 300;  e = 330  },
  [pscustomobject]@{ s = 600;  e = 630  }, [pscustomobject]@{ s = 900;  e = 930  },
  [pscustomobject]@{ s = 1200; e = 1230 }, [pscustomobject]@{ s = 1500; e = 1530 },
  [pscustomobject]@{ s = 1800; e = 1830 }, [pscustomobject]@{ s = 2100; e = 2130 }
)
if (-not $Full240) { $SEGS = @([pscustomobject]@{ s = 600; e = 630 }) }

$sw = [Diagnostics.Stopwatch]::StartNew()
$procList = @()
for ($r = 0; $r -lt $Repeat; $r++) {
 for ($i = 0; $i -lt $SEGS.Count; $i++) {
  $tag = "$Name`_r$r`_$i"
  $out = Join-Path $outDir "$tag.mp4"
  if (Test-Path $out) { Remove-Item $out -Force }
  # One flat command-line string: Start-Process -ArgumentList (string[]) refuses to bind a
  # bare Object[] on this PowerShell. Launch ffmpeg directly -- going via cmd.exe /c
  # corrupts the CJK path of the ffmpeg binary itself.
  # -v warning (not -v error): -v error suppresses the -stats progress line, which is the
  # only in-process wall-clock reading we get. time= excludes process start + file delete.
  $q = '-hide_banner -y -v warning -stats_period 5 -stats ' + $Iopt +
       ' -ss ' + $SEGS[$i].s + ' -to ' + $SEGS[$i].e + ' -i "' + $SRC + '"' +
       ' -vf "' + $VF + '" -c:v h264_nvenc ' + $ENC +
       ' -c:a aac -b:a 320k -ar 48000 -ac 2 "' + $out + '"'
  $p = Start-Process -FilePath $FF -ArgumentList $q -NoNewWindow -PassThru `
        -RedirectStandardError (Join-Path $outDir "$tag.err") -RedirectStandardOutput (Join-Path $outDir "$tag.log")
  $procList += [pscustomobject]@{ p = $p; tag = $tag }
  while (($procList | Where-Object { -not $_.p.HasExited }).Count -ge $Jobs) { Start-Sleep -Milliseconds 150 }
 }
}
$procList | ForEach-Object { $_.p.WaitForExit() }
$sw.Stop()

$rows = foreach ($j in $procList) {
  $out = Join-Path $outDir "$($j.tag).mp4"
  $sz  = if (Test-Path $out) { [math]::Round((Get-Item $out).Length / 1MB, 1) } else { 0 }
  $errTxt = Get-Content (Join-Path $outDir "$($j.tag).err") -ErrorAction SilentlyContinue
  # ffmpeg prints "frame= ... time=00:00:30.00 ..." on the final -stats line
  $tline = ($errTxt | Where-Object { $_ -match 'time=' } | Select-Object -Last 1)
  $ffsec = if ($tline -match 'time=(\d+):(\d+):([\d.]+)') { [double]$matches[1] * 3600 + [double]$matches[2] * 60 + [double]$matches[3] } else { $null }
  $ok = ($sz -gt 0)
  $note = if ($ok) { 'ok' } else { 'FAIL: ' + (($errTxt | Where-Object { $_ -notmatch '^\s*(frame|size)' } | Select-Object -First 4) -join ' ; ') }
  [pscustomobject]@{ seg = $j.tag; ok = $ok; MB = $sz; ffSec = $ffsec; note = $note }
}
$rows | Select-Object seg, ok, MB, ffSec | Format-Table -AutoSize | Out-String -Width 160 | Write-Output
$bad = $rows | Where-Object { -not $_.ok }
if ($bad) { Write-Output "ERR: $($bad[0].note)" }
$totalMB = [math]::Round((($rows | Measure-Object MB -Sum).Sum), 1)
$sumFf = [math]::Round((($rows | Measure-Object ffSec -Sum).Sum), 1)
Write-Output ("RESULT|{0}|jobs={1}|repeat={2}|wall={3:N2}|sumFFsec={4}|outMB={5}" -f $Name, $Jobs, $Repeat, $sw.Elapsed.TotalSeconds, $sumFf, $totalMB)