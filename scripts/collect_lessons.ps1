<#
    collect_lessons.ps1  --  扫描所有任务目录的经验文件，列出还没吸收进工作流的经验。

    为什么要有这个
    --------------
    项目的「落盘」这半边一直是通的：每局的经验都写在任务目录的
    reports\workflow_notes_*.md 里，规则里也明确要求子 Agent 只记这一个文件
    （见 roughcut-launch.md 派工强制字段）。

    断掉的是另一半：**没有汇总入口、没有待升级清单、没有归并留痕。**
    结果是经验确实记下来了、也确实进了工作流规则，但中间那步不可见 ——
    你无法知道某条经验到底升级了没有，只能全文搜索 skill 里的任务号去猜。
    而且 workflow_notes 的覆盖率只有一半（十个任务目录里 5 份），
    命名还混用目录号和素材号（_849 / _15 / _17 / _19 / _863）。

    这个脚本把中间那层补上：扫出所有经验源，标出哪些已在 POOL 里吸收过、
    哪些还没有。跑完打印一张待升级清单。

    用法
    ----
        & scripts\collect_lessons.ps1              # 扫描并打印待升级清单
        & scripts\collect_lessons.ps1 -PoolPath D:\other\POOL.md   # 指定池文件
        & scripts\collect_lessons.ps1 -Write        # 把新候选追加进 POOL.md 的待升级表

    退出码：0 正常（可能有待升级项，那不是错误）；1 参数错；2 池文件找不到
#>

[CmdletBinding()]
param(
    [string]$PoolPath = '',
    [switch]$Write,
    [string]$TasksRoot = ''
)

$ErrorActionPreference = 'Stop'
try { [Console]::OutputEncoding = [System.Text.Encoding]::UTF8 } catch { }

$here = Split-Path -Parent $MyInvocation.MyCommand.Path
$root = Split-Path -Parent $here
if (-not $PoolPath) { $PoolPath = Join-Path $root 'docs\lessons\POOL.md' }
if (-not $TasksRoot) { $TasksRoot = Join-Path $root '123' }

if (-not (Test-Path -LiteralPath $PoolPath -PathType Leaf)) {
    [Console]::Error.WriteLine("[FAIL] pool file not found: $PoolPath")
    exit 2
}

function Write-Section([string]$title) {
    Write-Output ''
    Write-Output "=== $title ==="
}

# ---------------------------------------------------------------------------
# 1. 收集经验源文件
# ---------------------------------------------------------------------------
# 两种来源都要收：
#   a) 任务目录 reports\workflow_notes*.md      —— 每局的常规沉淀
#   b) docs\lessons\*.md                        —— 用户/Agent 写的专题复盘
# 只收 .md；正文里带 lesson/教训/坑/根因/规则 等标记的才当作候选，避免把
# 纯渲染日志、字幕映射表这类文件也拖进来。
$candidates = New-Object System.Collections.ArrayList

if (Test-Path -LiteralPath $TasksRoot -PathType Container) {
    $taskDirs = @(Get-ChildItem -LiteralPath $TasksRoot -Directory -Force -ErrorAction SilentlyContinue |
                  Where-Object { $_.Name -match '^\d+\.' })
    foreach ($dir in $taskDirs) {
        $notes = @(Get-ChildItem -LiteralPath $dir.FullName -Recurse -File -Filter 'workflow_notes*.md' -Force -ErrorAction SilentlyContinue)
        foreach ($n in $notes) {
            [void]$candidates.Add([PSCustomObject]@{
                Source    = $dir.Name
                File      = $n.FullName
                Bytes     = $n.Length
                Kind      = 'workflow_notes'
                # 命名合规：应为 workflow_notes_<任务目录号>.md
                NameOk    = ($n.BaseName -eq ('workflow_notes_' + ($dir.Name -replace '^(\d+)\..*$', '$1')))
            })
        }
    }
}

$lessonsDir = Join-Path $root 'docs\lessons'
if (Test-Path -LiteralPath $lessonsDir -PathType Container) {
    foreach ($f in Get-ChildItem -LiteralPath $lessonsDir -File -Filter '*.md' -Force -ErrorAction SilentlyContinue) {
        if ($f.Name -eq 'POOL.md') { continue }
        # 专题复盘的文件名带日期+任务号，如 2026-10-01_864-审片反馈与教训.md。
        # 把任务号抽出来当来源键，否则来源写成 "docs\lessons" 就永远和池里的
        # "864" 对不上，已吸收的会被反复报成待升级。
        $key = 'docs\lessons'
        if ($f.BaseName -match '^\d{4}-\d{2}-\d{2}_(\d+)') { $key = $Matches[1] }
        [void]$candidates.Add([PSCustomObject]@{
            Source = $key
            File   = $f.FullName
            Bytes  = $f.Length
            Kind   = '专题复盘'
            NameOk = $true
        })
    }
}

Write-Section '经验源清单'
Write-Output ("  扫描目录: {0}" -f $TasksRoot)
Write-Output ("  找到经验源: {0} 个" -f $candidates.Count)
foreach ($c in $candidates) {
    $flag = if ($c.NameOk) { '' } else { '  <-- 命名不合规（应为 workflow_notes_<任务目录号>）' }
    Write-Output ("    [{0,-11}] {1,-44} {2,8:N0} B{3}" -f $c.Kind, $c.Source, $c.Bytes, $flag)
}

# ---------------------------------------------------------------------------
# 2. 读池子，算出哪些已吸收
# ---------------------------------------------------------------------------
$poolRaw = [System.IO.File]::ReadAllText($PoolPath, [System.Text.Encoding]::UTF8)

function Normalize-LessonText([string]$text) {
    if ($null -eq $text) { return '' }
    # 去掉 markdown 强调、行内代码、编号前缀与全部标点空白，只留实词，
    # 这样「### 坑 1：.ps1 缺 UTF-8 BOM」和池里的一句话能对上。
    $t = $text -replace '`', '' -replace '\*\*', '' -replace '\*', ''
    $t = $t -replace '^\s*#{1,6}\s*', ''
    $t = $t -replace '^\s*[Tt]?\d+\s*[·.、:：]\s*', ''
    $t = $t -replace '^\s*[Rr]\d+\s*[·.、]\s*', ''
    $t = $t -replace '^\s*(坑|教训|根因|规则|经验)\s*\d*\s*[·.、:：]?\s*', ''
    # 括号里几乎总是**本任务专属的细节**，不是教训本身：863 的
    # 「坑 1：.ps1 缺 UTF-8 BOM（seg1/seg2/seg3/seg4/seg6/seg10 全部撞上）」
    # 剥掉括号后主干「ps1缺utf8bom」就能和池里的转述对上；
    # 不剥的话路号会把 needle 撑稀释，重叠率掉到 36%，永远判不出已吸收。
    $t = $t -replace '（[^）]*）', ''
    $t = $t -replace '\([^)]*\)', ''
    $t = $t -replace '[^\p{L}\p{Nd}]', ''
    return $t.ToLowerInvariant()
}

function Test-Absorbed([string]$title, $texts) {
    $needle = Normalize-LessonText $title
    if ($needle.Length -lt 6) { return $false }
    # 先走快路径：完整包含。
    foreach ($hay in $texts) {
        if ($hay.Length -ge 6 -and ($hay.Contains($needle) -or $needle.Contains($hay))) { return $true }
    }
    # 慢路径：字符二元组重叠。池子里的「教训」列多数是**转述**，不是原样复制，
    # 精确包含匹配不上（863「坑 1」那条就因为转述时丢掉了括号里的路号而漏判）。
    # 二元组能容忍转述的增删，只要主干词还在就判为已吸收。
    $needleBigrams = New-Object System.Collections.Generic.HashSet[string]
    for ($i = 0; $i -lt $needle.Length - 1; $i++) {
        [void]$needleBigrams.Add($needle.Substring($i, 2))
    }
    if ($needleBigrams.Count -eq 0) { return $false }
    $best = 0.0
    foreach ($hay in $texts) {
        $hit = 0
        foreach ($bg in $needleBigrams) { if ($hay.Contains($bg)) { $hit++ } }
        $ratio = $hit / $needleBigrams.Count
        if ($ratio -gt $best) { $best = $ratio }
        if ($best -ge 0.65) { return $true }
    }
    return ($best -ge 0.65)
}

$absorbedIds = New-Object System.Collections.Generic.HashSet[string]
foreach ($m in [regex]::Matches($poolRaw, '\|\s*(L-\d{3})\s*\|')) {
    [void]$absorbedIds.Add($m.Groups[1].Value)
}
$absorbedSources = New-Object System.Collections.Generic.HashSet[string]
foreach ($m in [regex]::Matches($poolRaw, '\|\s*L-\d{3}\s*\|[^|]*\|\s*([^|]+?)\s*\|')) {
    [void]$absorbedSources.Add($m.Groups[1].Value.Trim())
}
# 教训正文也拿来匹配。只按「来源」匹配不可靠：同一批经验可能从任务目录的
# workflow_notes 和 docs\lessons 的专题复盘两个地方被扫到，来源键不一致，
# 已吸收的会被反复报成待升级 —— 那是池子最没用的一种状态。
$absorbedTexts = New-Object System.Collections.ArrayList
foreach ($m in [regex]::Matches($poolRaw, '(?m)^\|\s*L-\d{3}\s*\|[^|]*\|([^|]*)\|')) {
    [void]$absorbedTexts.Add((Normalize-LessonText $m.Groups[1].Value))
}

Write-Section '吸收状态'
Write-Output ("  池中已收录条目: {0} 条" -f $absorbedIds.Count)

# ---------------------------------------------------------------------------
# 3. 抽取候选教训
# ---------------------------------------------------------------------------
# 抽标题里带教训味的小节：## 坑 / ## 教训 / ## 根因 / ## 规则 / ### R1 / ## Lesson ...
$lessonPattern = '(?m)^\s{0,4}#{2,4}\s*(?:[Tt]?\d*\s*)?(?:坑|教训|根因|规则|经验|lesson|LESSON|Lesson|R\d)[^\r\n]*'
$worthPattern = '(?m)^\s{0,4}#{2,4}\s*(?:坑\s*\d|教训|根因|规则|经验|LESSON|Lesson)'

$found = New-Object System.Collections.ArrayList
foreach ($c in $candidates) {
    try {
        $text = [System.IO.File]::ReadAllText($c.File, [System.Text.Encoding]::UTF8)
    } catch { continue }
    $hits = @([regex]::Matches($text, $lessonPattern))
    if ($hits.Count -eq 0) { continue }
    # 逐条判断：一份经验源里可能只吸收了一部分，用首个标题代表整份会漏报。
    foreach ($h in $hits) {
        $title = $h.Value.Trim()
        [void]$found.Add([PSCustomObject]@{
            Source = $c.Source
            Kind   = $c.Kind
            Title  = $title
            InPool = ($absorbedSources.Contains($c.Source) -or (Test-Absorbed $title $absorbedTexts))
            File   = $c.File
        })
    }
}

$pending = @($found | Where-Object { -not $_.InPool })
$covered = @($found | Where-Object { $_.InPool })

Write-Section '待升级（该收纳的）'
if ($pending.Count -eq 0) {
    Write-Output '  （空）所有经验源的教训都已在池中标记为吸收。'
} else {
    Write-Output ("  共 {0} 条，来自 {1} 个未收录的经验源：" -f $pending.Count,
        (@($pending | Select-Object -ExpandProperty Source -Unique).Count))
    $i = 0
    foreach ($p in $pending) {
        $i++
        Write-Output ("    {0,2}. [{1}] {2}" -f $i, $p.Source, $p.Title)
    }
    Write-Output ''
    Write-Output '  逐条决定去向（吸收到哪个文件的哪条规则 / 判为一次性），'
    Write-Output '  然后回填 docs\lessons\POOL.md 并把状态改成 已吸收。'
    Write-Output '  没写「吸收去向」的不算吸收 —— 否则下次收纳会重复提出来。'
}

Write-Section '覆盖情况'
$totalTaskDirs = @(Get-ChildItem -LiteralPath $TasksRoot -Directory -Force -ErrorAction SilentlyContinue |
                   Where-Object { $_.Name -match '^\d+\.' }).Count
$withNotes = @($candidates | Where-Object { $_.Kind -eq 'workflow_notes' } | Select-Object -ExpandProperty Source -Unique).Count
Write-Output ("  任务目录总数        : {0}" -f $totalTaskDirs)
Write-Output ("  有 workflow_notes 的: {0}" -f $withNotes)
Write-Output ("  缺 workflow_notes 的: {0}" -f ($totalTaskDirs - $withNotes))
if ($totalTaskDirs -gt $withNotes) {
    $have = @($candidates | Where-Object { $_.Kind -eq 'workflow_notes' } | Select-Object -ExpandProperty Source)
    foreach ($d in (Get-ChildItem -LiteralPath $TasksRoot -Directory -Force -ErrorAction SilentlyContinue |
                     Where-Object { $_.Name -match '^\d+\.' })) {
        if ($have -notcontains $d.Name) { Write-Output ("    缺: {0}" -f $d.Name) }
    }
}
$badName = @($candidates | Where-Object { -not $_.NameOk })
if ($badName.Count -gt 0) {
    Write-Output ("  命名不合规          : {0} 个（应改为 workflow_notes_<任务目录号>）" -f $badName.Count)
}

# ---------------------------------------------------------------------------
# 4. 可选：把待升级项追加进池子
# ---------------------------------------------------------------------------
if ($Write) {
    if ($pending.Count -eq 0) {
        Write-Output ''
        Write-Section '写入'
        Write-Output '  没有新候选，未改动 POOL。'
        exit 0
    }
    $marker = '<!-- collect_lessons.ps1 会把新发现的候选追加到这里下面，并标注 待升级 -->'
    $lines = New-Object System.Collections.ArrayList
    foreach ($p in $pending) {
        [void]$lines.Add(("| L-??? | {0} | {1} | 待升级 |  |" -f $p.Source, ($p.Title -replace '^\s*#+\s*', '')))
    }
    $block = ($lines -join "`r`n")
    if ($poolRaw -notmatch [regex]::Escape($marker)) {
        [Console]::Error.WriteLine('[FAIL] POOL.md 里找不到待升级区的锚点标记，拒绝写入（不猜位置）')
        exit 1
    }
    $updated = $poolRaw.Replace($marker, $marker + "`r`n" + $block)
    [System.IO.File]::WriteAllText($PoolPath, $updated, (New-Object System.Text.UTF8Encoding $false))
    Write-Section '写入'
    Write-Output ("  已把 {0} 条候选追加到待升级表（编号留空 L-??? 待你分配）" -f $pending.Count)
    Write-Output ("  文件: {0}" -f $PoolPath)
}

exit 0
