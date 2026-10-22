<#
    check_task_numbering.ps1  --  体检 123\ 下的任务目录编号与命名。

    为什么需要它
    ------------
    2026-10-01 在 123\ 下发现一个错名目录：

        20.863永劫无间 02-57-13        <- 少了 "2026-09-30"

    素材真名是 `863永劫无间 2026-09-30 02-57-13`（三段）。错名的成因是有人
    按空格切分后取首尾拼接（`($parts[0]) + ' ' + ($parts[-1])`）——本意是
    「去掉中间的日期」，实际把日期吞了。**逐字符完全吻合，已复现。**

    这类错误有三个特点，让它特别难被发现：

    1. **不报错。** 目录建出来了，路径也是合法的。
    2. **不留文件。** 那个目录只有 shots\v4c9\pins\ 三个空目录、0 文件。
    3. **git 看不见。** git 不跟踪空目录，所以它永远不会出现在 `git status`。

    结果它占掉了编号 20，与真正的 `20.863永劫无间 2026-09-30 02-57-13` 撞号，
    而项目里没有任何一道门禁会提它。预检的野目录检查只看 `C:\Project` 那一层，
    看得到 `123\` 内部。

    所以这个检查专门看 123\ 内部。

    用法
    ----
        & scripts\check_task_numbering.ps1
        & scripts\check_task_numbering.ps1 -Json

    退出码：0 = 没有硬违规（撞号 / 名字被截断 / 空壳目录 / 索引不一致）；1 = 有硬违规
    撞号**是硬违规**（2026-10-22 起）：`123\README.md` 的明文规则是每个目录占用一个编号，
    而 2026-10-22 那次两个对话同时开 → 各自建了 `34.x`，挂了一周没人管就是因为它只判 NOTE。
    分配器 `scripts\new_task_dir.ps1` 负责真正地分配（加锁 + 同一素材幂等 + 索引台账），
    本门负责**兜住漏网的**。
    注意：**已交付的任务目录被用户手删是允许的**（那会让索引留下孤儿行 → 只出 NOTE，不是违规）。
#>

[CmdletBinding()]
param(
    [switch]$Json,
    # 指向别的根（测试用）；默认是本项目的 123\。
    [Parameter()][string]$TasksRoot = ''
)

$ErrorActionPreference = 'Stop'
try { [Console]::OutputEncoding = [System.Text.Encoding]::UTF8 } catch { }

$here = Split-Path -Parent $MyInvocation.MyCommand.Path
$root = Split-Path -Parent $here
if (-not $TasksRoot) { $TasksRoot = Join-Path $root '123' }
$tasksRoot = $TasksRoot

$problems = New-Object System.Collections.ArrayList
$notes = New-Object System.Collections.ArrayList

if (-not (Test-Path -LiteralPath $tasksRoot -PathType Container)) {
    if ($Json) { '{"status":"no_tasks_root","tasks":0,"problems":[],"notes":[]}' | Write-Output }
    else { Write-Output '123\ 不存在 —— 没有任务目录，编号规则「从 1 开始」适用。' }
    exit 0
}

# 只认 `<数字>.<素材名>` 形态的目录；workflow_upgrade / _archive 之类不算任务目录
$taskDirs = @(Get-ChildItem -LiteralPath $tasksRoot -Directory -Force -ErrorAction SilentlyContinue |
              Where-Object { $_.Name -match '^(\d+)\.(.+)$' })

$byNumber = @{}
foreach ($d in $taskDirs) {
    if ($d.Name -notmatch '^(\d+)\.(.+)$') { continue }
    $num = [int]$Matches[1]
    $stem = $Matches[2]
    if (-not $byNumber.ContainsKey($num)) { $byNumber[$num] = New-Object System.Collections.ArrayList }
    [void]$byNumber[$num].Add([PSCustomObject]@{ Dir = $d; Stem = $stem })
}

# --- 检查 1：同一编号出现多个目录（撞号）------------------------------------
# 2026-10-22 起：**撞号是硬违规**。
# 理由：`123\README.md` 的明文规则是「每个目录占用一个编号」；而撞号之所以
# 2026-10-22 之前挂了一周没人管，就是因为它只判 NOTE。
# 病根是「取号」只是读操作（看 max+1）不是分配操作——现在由
# `scripts\new_task_dir.ps1`（加锁 + 幂等 + 索引）负责分配，本门负责**兜住漏网的**。
foreach ($num in ($byNumber.Keys | Sort-Object)) {
    $group = $byNumber[$num]
    if ($group.Count -le 1) { continue }
    $detail = ($group | ForEach-Object { $_.Dir.Name }) -join ' | '
    $msg = "编号 $num 被 $($group.Count) 个目录占用：$detail"
    $empty = @($group | Where-Object {
        @(Get-ChildItem -LiteralPath $_.Dir.FullName -Recurse -File -Force -ErrorAction SilentlyContinue).Count -eq 0
    })
    if ($empty.Count -gt 0) {
        [void]$problems.Add("DUP_NUMBER_EMPTY: $msg  —— 其中 $($empty.Count) 个是 0 文件的空壳，属误建残留")
    } else {
        [void]$problems.Add("DUP_NUMBER: $msg  —— 编号必须唯一（123\README.md：每个目录占用一个编号）。重建目录请走 scripts\new_task_dir.ps1")
    }
}

# --- 索引读取（先读，后面的检查都要用）----------------------------------------
# 索引是分配器留下的台账：编号⇥素材⇥创建时间。
# 它的用处不是好看，是**让「谁建了这个目录」可查**——目录不在索引里，
# 说明它不是走 `scripts\new_task_dir.ps1` 建的（也就是绕过了加锁取号，撞号风险最高的那种）。
$indexPath = Join-Path $tasksRoot 'index.tsv'
$indexRows = New-Object System.Collections.ArrayList
$badIndexRows = 0
if (Test-Path -LiteralPath $indexPath -PathType Leaf) {
    foreach ($line in @(Get-Content -LiteralPath $indexPath -Encoding UTF8 -ErrorAction SilentlyContinue)) {
        if (-not $line.Trim() -or $line.StartsWith('#')) { continue }
        $p = $line -split "`t"
        $n = 0
        if ($p.Count -lt 2 -or -not [int]::TryParse($p[0], [ref]$n)) {
            # 索引行坏了不能把门禁带崩（它现在会 unhandled error 直接退出，不报任何东西）。
            $badIndexRows++
            continue
        }
        [void]$indexRows.Add([PSCustomObject]@{ Num = $n; Material = $p[1] })
    }
}
$indexed = @{}
$indexedDirNums = @()
foreach ($r in $indexRows) {
    $indexed["{0}|{1}" -f $r.Num, $r.Material] = $true
    if ($indexedDirNums -notcontains $r.Num) { $indexedDirNums += $r.Num }
}
if ($badIndexRows -gt 0) {
    [void]$problems.Add("INDEX_FORMAT: index.tsv 里有 $badIndexRows 行解析不了（第一列不是整数）—— 行格式是 编号⇥素材⇥创建时间⇥备注")
}

# --- 检查 2：素材名疑似被截断（空格分段数异常 / 缺日期）----------------------
# 已知错名形态：`<游戏名> <HH-MM-SS>`（少日期段）。
# 判定：名字里含 `HH-MM-SS` 时间戳，但前面没有 `YYYY-MM-DD` 日期段。
# **只认「正好两段、且第二段是时间戳」这一种形态**（2026-10-01 事故的原样：
# `863永劫无间 2026-09-30 02-57-13` → `863永劫无间 02-57-13`）。
# 更宽的判据（只要含时间戳且不含日期）会误伤「本来就没有日期段」的合法素材名——
# 而命名铁律是「原样照抄，一个字符都不改」，不能因为门禁就逼人改名。
foreach ($num in ($byNumber.Keys | Sort-Object)) {
    foreach ($entry in $byNumber[$num]) {
        $stem = $entry.Stem
        $hasTime = $stem -match '\d{2}-\d{2}-\d{2}'
        $hasDate = $stem -match '\d{4}-\d{2}-\d{2}'
        if (-not ($hasTime -and -not $hasDate)) { continue }
        $parts = @($stem -split '\s+' | Where-Object { $_ })
        $twoSegments = ($parts.Count -eq 2 -and $parts[1] -match '^\d{2}-\d{2}-\d{2}')
        if ($twoSegments) {
            [void]$problems.Add(("STEM_TRUNCATED: {0}  —— 名字被切成两段、第二段是 HH-MM-SS，缺 YYYY-MM-DD 日期段（2026-10-01 事故形态：按空格切分取首尾把日期吞了）" -f $entry.Dir.Name))
        }
    }
}

# --- 检查 2b：目录名不该带文件扩展名（2026-10-22 立）---------------------------
# 事故：30.884 的目录叫 `30.884永劫无间 2026-10-09 18-12-51.mp4`——**带扩展名**。
# 成因不是素材有问题（源片真名就是 `884永劫无间 2026-10-09 18-12-51.mp4`，正常），
# 是**建目录那一步没去扩展名**：§「目录名 = 源文件名去扩展名」的铁律没被执行到。
# 后果一路传染：成片名成了 `884永劫无间 2026-10-09 18-12-51.mp4 cujian.mp4`。
# 现在分配器（new_task_dir.ps1）会去扩展名，这道门负责兜住手工建的目录。
foreach ($num in ($byNumber.Keys | Sort-Object)) {
    foreach ($entry in $byNumber[$num]) {
        if ($entry.Stem -match '\.(mp4|mkv|avi|mov|webm|m4v|m2ts|mts|ts|wmv|flv)$') {
            $clean = $entry.Dir.Name -replace '\.(mp4|mkv|avi|mov|webm|m4v|m2ts|mts|ts|wmv|flv)$', ''
            [void]$problems.Add(("DIR_HAS_EXTENSION: {0}  —— 目录名带了文件扩展名。目录名必须是「源文件名去扩展名」（123\README.md 建目录铁律）。改成 {1}，并同步引用" -f $entry.Dir.Name, $clean))
        }
    }
}

# --- 检查 3：0 文件的空壳任务目录 ------------------------------------------
# **有索引行 = 分配器建的**：新任务目录刚建出来时本来就是空的（分析文件还没落），
# 那不是缺陷，只是「刚开张」。所以空目录只有在**没有索引行**时才是硬违规
# （那种目录是误建/放弃的残留——2026-10-22 的 33.877 就是这种）。
foreach ($num in ($byNumber.Keys | Sort-Object)) {
    foreach ($entry in $byNumber[$num]) {
        $files = @(Get-ChildItem -LiteralPath $entry.Dir.FullName -Recurse -File -Force -ErrorAction SilentlyContinue)
        if ($files.Count -eq 0) {
            $subdirs = @(Get-ChildItem -LiteralPath $entry.Dir.FullName -Recurse -Directory -Force -ErrorAction SilentlyContinue).Count
            if ($indexedDirNums -contains $num) {
                [void]$notes.Add(("EMPTY_TASK_DIR: {0}  —— 0 个文件，但有索引行：这是分配器刚建出来、还没开始写的任务目录（正常）" -f $entry.Dir.Name))
            } else {
                [void]$problems.Add(("EMPTY_TASK_DIR: {0}  —— 0 个文件（{1} 个空子目录）且不在 index.tsv 里：不是一次真正的剪辑留下的" -f $entry.Dir.Name, $subdirs))
            }
        }
    }
}

# --- 检查 4：索引一致性（`123\index.tsv`）---------------------------------------
if (Test-Path -LiteralPath $indexPath -PathType Leaf) {
    foreach ($num in ($byNumber.Keys | Sort-Object)) {
        foreach ($entry in $byNumber[$num]) {
            # 目录名再解析一次取编号与素材名——不能写成 "$($x -replace ...,'$1')"，
            # PowerShell 的双引号串里没有 $1 反向引用，$1 会被当成空变量，
            # 键拼成 "|素材名"，于是**每一行都判成缺索引**（这个 bug 真的发生过）。
            if ($entry.Dir.Name -notmatch '^(\d+)\.(.+)$') { continue }
            $key = "{0}|{1}" -f [int]$Matches[1], $Matches[2]
            if (-not $indexed.ContainsKey($key)) {
                [void]$problems.Add(("NO_INDEX_ROW: {0}  —— 这个目录不在 index.tsv 里，说明不是走 scripts\new_task_dir.ps1 建的（绕过加锁取号就是撞号的成因）。跑一次 `& scripts\new_task_dir.ps1 -Backfill` 就能补上" -f $entry.Dir.Name))
            }
        }
    }
    foreach ($r in $indexRows) {
        $match = @($taskDirs | Where-Object { $_.Name -match ('^' + $r.Num + '\.') -and ($_.Name -replace ('^' + $r.Num + '\.'), '') -eq $r.Material })
        if ($match.Count -eq 0) {
            # 只报 NOTE 不判硬违规：**交付后的任务目录是会被用户手删的**
            # （123\README.md「出片后别删目录」是建议，不是强约束）。
            # 目录没了、索引里还留着那一行 = 正常的历史记录，不是缺陷；
            # 判硬违规会让这道门在正常流程下永远红着。
            [void]$notes.Add(("INDEX_ORPHAN: 索引里的 {0}.{1} 在盘上不存在（目录已删/改名，索引保留那一行作为历史记录）" -f $r.Num, $r.Material))
        }
    }
} else {
    # 没有索引文件：**只有在已经有任务目录时**才是问题。
    # 新克隆的仓里 `123\` 只有 README.md（规则文档，已入库），没有任务目录也没有索引——
    # 那种情况下「没有索引」是正常的，不该让预检变红。
    if ($taskDirs.Count -gt 0) {
        [void]$problems.Add("NO_INDEX: 123\index.tsv 不存在，但盘上已有 $($taskDirs.Count) 个任务目录 —— 建目录请一律走 scripts\new_task_dir.ps1（历史目录用它的 -Backfill 补进索引）")
    } else {
        [void]$notes.Add("NO_INDEX: 123\index.tsv 不存在（当前没有任务目录，属正常；建第一个目录时会自动生成）")
    }
}

# --- 检查 5：素材顺序（用户规则：数字越大的素材往后排）-------------------------
# 只报 NOTE，不判硬违规：历史编号不能重排，倒序是**流程**问题不是**数据**问题。
# 活口在分配器上——它在下发号时会当场 WARN。
$ordered = @($byNumber.Keys | Sort-Object | ForEach-Object { $_ } | ForEach-Object {
    $n = [int]$_
    $entry = $byNumber[$n] | Select-Object -First 1
    [PSCustomObject]@{ Num = $n; MatNum = $(if ($entry.Stem -match '^\s*(\d+)') { [int]$Matches[1] } else { $null }) }
})
for ($i = 1; $i -lt $ordered.Count; $i++) {
    $prev = $ordered[$i - 1]; $cur = $ordered[$i]
    if ($null -ne $prev.MatNum -and $null -ne $cur.MatNum -and $cur.MatNum -lt $prev.MatNum) {
        [void]$notes.Add(("MATERIAL_ORDER: 编号 {0} 的素材号 {1} 大于编号 {2} 的素材号 {3} —— 素材号应当递增（数字越大的素材往后排）" -f $prev.Num, $prev.MatNum, $cur.Num, $cur.MatNum))
    }
}

$maxNum = if ($byNumber.Count -gt 0) { ($byNumber.Keys | Measure-Object -Maximum).Maximum } else { 0 }
$dupCount = @($problems | Where-Object { $_ -like 'DUP_NUMBER*' }).Count

if ($Json) {
    [PSCustomObject]@{
        schema = 'naraka-task-numbering-check/v2'
        tasks_root = $tasksRoot
        task_dirs = $taskDirs.Count
        max_number = $maxNum
        next_number = ($maxNum + 1)
        # `pass` = 没有硬违规。撞号、空壳、名字被截断、索引不一致都算硬违规。
        # `unique` = 编号唯一（2026-10-22 起撞号不再只判 NOTE）。
        pass = ($problems.Count -eq 0)
        unique = ($dupCount -eq 0)
        index_rows = $indexRows.Count
        notes_count = $notes.Count
        problems = @($problems)
        notes = @($notes)
    } | ConvertTo-Json -Depth 5
} else {
    Write-Output "123\ 任务目录: $($taskDirs.Count) 个，最大编号 $maxNum，下一个取 $($maxNum + 1)"
    if ($problems.Count -eq 0) {
        Write-Output '[PASS] 编号唯一、命名完整、索引齐、没有空壳目录'
    } else {
        foreach ($p in $problems) { Write-Output "  [VIOLATION] $p" }
    }
    foreach ($n in $notes) { Write-Output "  [NOTE] $n" }
}

exit ($(if ($problems.Count -eq 0) { 0 } else { 1 }))
