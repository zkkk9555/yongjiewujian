<#
    test_new_task_dir.ps1  --  scripts\new_task_dir.ps1 与 check_task_numbering.ps1 的回归测试

    为什么要有这个
    --------------
    2026-10-22 出了「两个 34」的撞号事故：两个对话挨着开，各自读到同一个 max，
    各自建了同一个号。修法是把「读 max+1」换成「加锁分配」。
    **但加锁这件事只有跑过才知道它真的加锁** —— 所以必须有并发用例，
    而且必须能证伪：两个并发调用必须拿到**不同**的号。

    用法
    ----
        & scripts\test_new_task_dir.ps1

    退出码：0 = 全过；1 = 有用例失败（失败明细打印在后面）
#>

[CmdletBinding()]
param()

$ErrorActionPreference = 'Continue'
try { [Console]::OutputEncoding = [System.Text.Encoding]::UTF8 } catch { }

$here = Split-Path -Parent $MyInvocation.MyCommand.Path
$root = Split-Path -Parent $here
$alloc = Join-Path $here 'new_task_dir.ps1'
$checker = Join-Path $here 'check_task_numbering.ps1'

$script:fail = 0
$script:pass = 0

function Assert-True([bool]$cond, [string]$name, [string]$detail = '') {
    if ($cond) {
        $script:pass++
        Write-Output ("  [PASS] {0}" -f $name)
    } else {
        $script:fail++
        Write-Output ("  [FAIL] {0} {1}" -f $name, $detail)
    }
}

function New-Sandbox([string]$name) {
    $p = Join-Path ([System.IO.Path]::GetTempPath()) ("naraka_seq_test_" + $name + "_" + [guid]::NewGuid().ToString('N').Substring(0, 8))
    New-Item -ItemType Directory -Path $p -Force | Out-Null
    return $p
}

Write-Output '=== 分配器回归测试 ==='

# --- T1 空根：第一个号是 1 ----------------------------------------------------
$sb = New-Sandbox 't1'
try {
    $out = & $alloc -Material '001素材A 2026-01-01 00-00-00' -TasksRoot $sb 2>&1 | Out-String
    $dirs = @(Get-ChildItem -LiteralPath $sb -Directory -ErrorAction SilentlyContinue)
    Assert-True ($dirs.Count -eq 1) 'T1 空根只建一个目录' "实际 $($dirs.Count)"
    Assert-True ($dirs[0].Name -eq '1.001素材A 2026-01-01 00-00-00') 'T1 第一个编号是 1' "实际 $($dirs[0].Name)"
} finally { Remove-Item -LiteralPath $sb -Recurse -Force -ErrorAction SilentlyContinue }

# --- T2 单调递增 --------------------------------------------------------------
$sb = New-Sandbox 't2'
try {
    & $alloc -Material '010素材B 2026-01-01 00-00-00' -TasksRoot $sb *> $null
    & $alloc -Material '011素材C 2026-01-01 00-00-00' -TasksRoot $sb *> $null
    $out = & $alloc -Material '012素材D 2026-01-01 00-00-00' -TasksRoot $sb 2>&1 | Out-String
    Assert-True ($out -match 'CREATED' -and $out -match '\\3\.012素材D') 'T2 第三个号是 3（max+1）' $out.Trim()
} finally { Remove-Item -LiteralPath $sb -Recurse -Force -ErrorAction SilentlyContinue }

# --- T3 幂等：同一素材跑两次，第二次必须 REUSE --------------------------------
$sb = New-Sandbox 't3'
try {
    & $alloc -Material '020素材E 2026-01-01 00-00-00' -TasksRoot $sb *> $null
    $out2 = & $alloc -Material '020素材E 2026-01-01 00-00-00' -TasksRoot $sb 2>&1 | Out-String
    $dirs = @(Get-ChildItem -LiteralPath $sb -Directory -ErrorAction SilentlyContinue)
    Assert-True ($out2 -match 'REUSE') 'T3 同一素材第二次返回 REUSE' $out2.Trim()
    Assert-True ($dirs.Count -eq 1) 'T3 同一素材没有多建目录' "实际 $($dirs.Count)"
} finally { Remove-Item -LiteralPath $sb -Recurse -Force -ErrorAction SilentlyContinue }

# --- T4 并发：两个进程**同时**取号，必须拿到不同号 ----------------------------
# 注意：这里必须做**真正的并发**。第一版用 Start-Job，实测两个 job 是**串行**跑的
# （启动各花 ~90 ms，第二个 job 起来时第一个已经结束）——那样的用例**把锁去掉也照样过**，
# 守不住这轮的核心前提。
# 现在用「起跑门」：两个子进程先各自写一个 ready 文件，然后**一起等 go 文件出现**，
# go 文件一出现就同时冲进分配器 → 真的在锁上撞。
$sb = New-Sandbox 't4'
$helper = Join-Path $sb '_child_alloc.ps1'
@'
param([string]$Material, [string]$TasksRoot, [string]$GoFile, [string]$ReadyFile, [string]$OutFile, [string]$Script)
Set-Content -LiteralPath $ReadyFile -Value 'ready' -Encoding ASCII
while (-not (Test-Path -LiteralPath $GoFile)) { Start-Sleep -Milliseconds 20 }
$out = & $Script -Material $Material -TasksRoot $TasksRoot 2>&1 | Out-String
Set-Content -LiteralPath $OutFile -Value $out -Encoding UTF8
'@ | Set-Content -LiteralPath $helper -Encoding UTF8
try {
    $goFile = Join-Path $sb 'go'
    $procs = @()
    foreach ($m in @('030素材F 2026-01-01 00-00-00', '031素材G 2026-01-01 00-00-00')) {
        $tag = $m.Substring(0, 3)
        $ready = Join-Path $sb ("ready_" + $tag)
        $outF = Join-Path $sb ("out_" + $tag)
        $procs += Start-Process -FilePath 'powershell.exe' -PassThru -WindowStyle Hidden -ArgumentList @(
            '-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', $helper,
            '-Material', $m, '-TasksRoot', $sb, '-GoFile', $goFile,
            '-ReadyFile', $ready, '-OutFile', $outF, '-Script', $alloc
        )
    }
    # 等两个子进程都就位（最多 20 秒）
    $deadline = (Get-Date).AddSeconds(20)
    while ((Get-ChildItem -LiteralPath $sb -Filter 'ready_*' -ErrorAction SilentlyContinue).Count -lt 2 -and (Get-Date) -lt $deadline) {
        Start-Sleep -Milliseconds 50
    }
    $readyCount = (Get-ChildItem -LiteralPath $sb -Filter 'ready_*' -ErrorAction SilentlyContinue).Count
    Assert-True ($readyCount -eq 2) 'T4 两个子进程都就位（起跑门有效）' "实际 $readyCount"
    # 放闸：两个进程从这一刻起真正同时冲进分配器
    Set-Content -LiteralPath $goFile -Value 'go' -Encoding ASCII
    $procs | ForEach-Object { $_.WaitForExit(60000) | Out-Null }
    $nums = @(Get-ChildItem -LiteralPath $sb -Directory -ErrorAction SilentlyContinue | ForEach-Object { [int]($_.Name -replace '^(\d+)\..*$', '$1') })
    Assert-True ($nums.Count -eq 2) 'T4 并发建了两个目录' "实际 $($nums.Count)"
    Assert-True (($nums | Sort-Object -Unique).Count -eq $nums.Count) 'T4 并发拿到的是两个不同的号' ("号：" + ($nums -join ','))
    $outs = @(Get-ChildItem -LiteralPath $sb -Filter 'out_*' -ErrorAction SilentlyContinue | ForEach-Object { Get-Content -LiteralPath $_.FullName -Raw -Encoding UTF8 }) -join ''
    Assert-True ($outs -match 'CREATED') 'T4 两个都报告 CREATED' ''
} finally {
    Get-Process -Name powershell -ErrorAction SilentlyContinue | Where-Object { $_.Path -and $false } | Out-Null
    Remove-Item -LiteralPath $sb -Recurse -Force -ErrorAction SilentlyContinue
}

# --- T5 索引 ------------------------------------------------------------------
$sb = New-Sandbox 't5'
try {
    & $alloc -Material '040素材H 2026-01-01 00-00-00' -TasksRoot $sb *> $null
    $idx = Join-Path $sb 'index.tsv'
    Assert-True (Test-Path -LiteralPath $idx) 'T5 索引文件已生成' ''
    $content = Get-Content -LiteralPath $idx -Raw -Encoding UTF8
    Assert-True ($content -match '040素材H') 'T5 索引里有素材名' ''
    Assert-True ($content -match "(?m)^1`t") 'T5 索引里有编号' ("索引内容：" + ($content -replace "`r?`n", ' | '))
} finally { Remove-Item -LiteralPath $sb -Recurse -Force -ErrorAction SilentlyContinue }

# --- T6 门禁能抓撞号 ----------------------------------------------------------
$sb = New-Sandbox 't6'
try {
    New-Item -ItemType Directory -Path (Join-Path $sb '7.060素材I 2026-01-01 00-00-00') -Force | Out-Null
    New-Item -ItemType Directory -Path (Join-Path $sb '7.061素材J 2026-01-01 00-00-00') -Force | Out-Null
    $out = & $checker -TasksRoot $sb 2>&1 | Out-String
    $code = $LASTEXITCODE
    Assert-True ($out -match 'DUP_NUMBER') 'T6 门禁报出 DUP_NUMBER' $out.Trim()
    Assert-True ($code -eq 1) 'T6 撞号时退出码是 1' "实际 $code"
} finally { Remove-Item -LiteralPath $sb -Recurse -Force -ErrorAction SilentlyContinue }

# --- T7 门禁能抓「目录没索引」-------------------------------------------------
$sb = New-Sandbox 't7'
try {
    New-Item -ItemType Directory -Path (Join-Path $sb '1.070素材K 2026-01-01 00-00-00') -Force | Out-Null
    $out = & $checker -TasksRoot $sb 2>&1 | Out-String
    Assert-True ($out -match 'NO_INDEX') 'T7 门禁报出 NO_INDEX / NO_INDEX_ROW' $out.Trim()
    Assert-True ($LASTEXITCODE -eq 1) 'T7 缺索引时退出码是 1' "实际 $LASTEXITCODE"
} finally { Remove-Item -LiteralPath $sb -Recurse -Force -ErrorAction SilentlyContinue }

# --- T8 素材倒序只报 NOTE -----------------------------------------------------
$sb = New-Sandbox 't8'
try {
    New-Item -ItemType Directory -Path (Join-Path $sb '1.090素材M 2026-01-01 00-00-00') -Force | Out-Null
    New-Item -ItemType Directory -Path (Join-Path $sb '2.080素材L 2026-01-01 00-00-00') -Force | Out-Null
    $out = & $checker -TasksRoot $sb 2>&1 | Out-String
    Assert-True ($out -match 'MATERIAL_ORDER') 'T8 素材倒序被报出来（NOTE）' $out.Trim()
} finally { Remove-Item -LiteralPath $sb -Recurse -Force -ErrorAction SilentlyContinue }

# --- T9 空根 + 没有索引 → 不该报违规（新克隆的仓就是这个样子）-----------------
$sb = New-Sandbox 't9'
try {
    # 模拟新克隆：123\ 只有 README.md（规则文档，已入库），没有任务目录、没有索引
    Set-Content -LiteralPath (Join-Path $sb 'README.md') -Value '# 规则文档' -Encoding UTF8
    $out = & $checker -TasksRoot $sb 2>&1 | Out-String
    Assert-True ($LASTEXITCODE -eq 0) 'T9 空根且无索引时退出码是 0' ("退出码 $LASTEXITCODE；输出：" + $out.Trim())
    Assert-True ($out -notmatch '\[VIOLATION\].*NO_INDEX') 'T9 空根时不报 NO_INDEX 违规（只出 NOTE）' $out.Trim()
} finally { Remove-Item -LiteralPath $sb -Recurse -Force -ErrorAction SilentlyContinue }

# --- T10 有任务目录但没有索引 → 硬违规 ----------------------------------------
$sb = New-Sandbox 't10'
try {
    New-Item -ItemType Directory -Path (Join-Path $sb '1.100素材N 2026-01-01 00-00-00') -Force | Out-Null
    $out = & $checker -TasksRoot $sb 2>&1 | Out-String
    Assert-True ($out -match 'NO_INDEX') 'T10 有目录没索引时报 NO_INDEX' $out.Trim()
    Assert-True ($LASTEXITCODE -eq 1) 'T10 有目录没索引时退出码是 1' "实际 $LASTEXITCODE"
} finally { Remove-Item -LiteralPath $sb -Recurse -Force -ErrorAction SilentlyContinue }

Write-Output ''
Write-Output ("=== 结果：{0} 通过 / {1} 失败 ===" -f $script:pass, $script:fail)
if ($script:fail -gt 0) { exit 1 }
exit 0
