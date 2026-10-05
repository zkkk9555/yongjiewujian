param(
  [Parameter(Mandatory=$true)][string]$Name,
  [Parameter(Mandatory=$true)][string]$VF,
  [Parameter(Mandatory=$true)][string]$ENC,
  [string]$Iopt = '',
  [int]$Jobs = 1,
  [switch]$Single30
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

# 8 x 30s segments spread across the 40-min source => 240 s programme, the same
# programme length the 11.8% segmented-vs-filter_complex reference was measured on.
# NOTE: use objects, NOT nested array literals -- @(@(100,130),@(300,330)) FLATTENS in
# PowerShell to @(100,130,300,330), so $SEGS[$i][0] then silently evaluates to $null.
$SEGS = @(
  [pscustomobject]@{ s = 100;  e = 130  }, [pscustomobject]@{ s = 300;  e = 330  },
  [pscustomobject]@{ s = 600;  e = 630  }, [pscustomobject]@{ s = 900;  e = 930  },
  [pscustomobject]@{ s = 1200; e = 1230 }, [pscustomobject]@{ s = 1500; e = 1530 },
  [pscustomobject]@{ s = 1800; e = 1830 }, [pscustomobject]@{ s = 2100; e = 2130 }
)
if ($Single30) { $SEGS = @([pscustomobject]@{ s = 600; e = 630 }) }

$sw = [Diagnostics.Stopwatch]::StartNew()
$procList = @()
for ($i = 0; $i -lt $SEGS.Count; $i++) {
  $tag = "$Name`_$i"
  $out = Join-Path $outDir "$tag.mp4"
  if (Test-Path $out) { Remove-Item $out -Force }
  # One flat command-line string: Start-Process -ArgumentList (string[]) refuses to
  # bind a bare Object[] on this PowerShell, so hand it a single string instead.
  $q = '-hide_banner -y -v error ' + $Iopt +
       ' -ss ' + $SEGS[$i].s + ' -to ' + $SEGS[$i].e + ' -i "' + $SRC + '"' +
       ' -vf "' + $VF + '" -c:v h264_nvenc ' + $ENC +
       ' -c:a aac -b:a 320k -ar 48000 -ac 2 "' + $out + '"'
  $p = Start-Process -FilePath $FF -ArgumentList $q -NoNewWindow -PassThru `
        -RedirectStandardError (Join-Path $outDir "$tag.err") -RedirectStandardOutput (Join-Path $outDir "$tag.log")
  $procList += [pscustomobject]@{ p = $p; tag = $tag }
  while (($procList | Where-Object { -not $_.p.HasExited }).Count -ge $Jobs) { Start-Sleep -Milliseconds 150 }
}
$procList | ForEach-Object { $_.p.WaitForExit() }
$sw.Stop()

$rows = foreach ($j in $procList) {
  $out = Join-Path $outDir "$($j.tag).mp4"
  $sz  = if (Test-Path $out) { [math]::Round((Get-Item $out).Length / 1MB, 1) } else { 0 }
  $line = (Get-Content (Join-Path $outDir "$($j.tag).log") -ErrorAction SilentlyContinue | Select-Object -Last 1)
  if ($j.p.ExitCode -ne 0) {
    $line = 'FAIL: ' + ((Get-Content (Join-Path $outDir "$($j.tag).err") -ErrorAction SilentlyContinue | Select-Object -First 4) -join ' ; ')
  }
  [pscustomobject]@{ seg = $j.tag; exit = $j.p.ExitCode; MB = $sz; last = $line }
}
$rows | Select-Object seg, exit, MB | Format-Table -AutoSize | Out-String -Width 160 | Write-Output
$bad = $rows | Where-Object { $_.exit -ne 0 }
if ($bad) { Write-Output "ERR: $($bad[0].last)" }
$totalMB = [math]::Round((($rows | Measure-Object MB -Sum).Sum), 1)
Write-Output ("RESULT|{0}|jobs={1}|wall={2:N2}|outMB={3}" -f $Name, $Jobs, $sw.Elapsed.TotalSeconds, $totalMB)


