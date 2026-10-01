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

    退出码：0 = 编号与命名都干净；1 = 有问题
#>

[CmdletBinding()]
param(
    [switch]$Json
)

$ErrorActionPreference = 'Stop'
try { [Console]::OutputEncoding = [System.Text.Encoding]::UTF8 } catch { }

$here = Split-Path -Parent $MyInvocation.MyCommand.Path
$root = Split-Path -Parent $here
$tasksRoot = Join-Path $root '123'

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
foreach ($num in ($byNumber.Keys | Sort-Object)) {
    $group = $byNumber[$num]
    if ($group.Count -le 1) { continue }
    # 全都非空的那不算撞（理论上不会），只要有一个是空壳就说明是残留
    $empty = @($group | Where-Object {
        @(Get-ChildItem -LiteralPath $_.Dir.FullName -Recurse -File -Force -ErrorAction SilentlyContinue).Count -eq 0
    })
    if ($group.Count -gt 1) {
        $detail = ($group | ForEach-Object { $_.Dir.Name }) -join ' | '
        $msg = "编号 $num 被 $($group.Count) 个目录占用：$detail"
        if ($empty.Count -gt 0) {
            [void]$problems.Add("DUP_NUMBER_EMPTY: $msg  —— 其中 $($empty.Count) 个是 0 文件的空壳，属误建残留")
        } else {
            [void]$notes.Add("DUP_NUMBER: $msg  —— 都不是空目录，人工确认哪个有效")
        }
    }
}

# --- 检查 2：素材名疑似被截断（空格分段数异常 / 缺日期）----------------------
# 已知错名形态：`<游戏名> <HH-MM-SS>`（少日期段）。
# 判定：名字里含 `HH-MM-SS` 时间戳，但前面没有 `YYYY-MM-DD` 日期段。
foreach ($num in ($byNumber.Keys | Sort-Object)) {
    foreach ($entry in $byNumber[$num]) {
        $stem = $entry.Stem
        $hasTime = $stem -match '\d{2}-\d{2}-\d{2}'
        $hasDate = $stem -match '\d{4}-\d{2}-\d{2}'
        if ($hasTime -and -not $hasDate) {
            [void]$problems.Add(("STEM_TRUNCATED: {0}  —— 名字里有 HH-MM-SS 但没有 YYYY-MM-DD 日期段，疑似按空格切分取首尾时吞掉了日期" -f $entry.Dir.Name))
        }
    }
}

# --- 检查 3：0 文件的空壳任务目录 ------------------------------------------
foreach ($num in ($byNumber.Keys | Sort-Object)) {
    foreach ($entry in $byNumber[$num]) {
        $files = @(Get-ChildItem -LiteralPath $entry.Dir.FullName -Recurse -File -Force -ErrorAction SilentlyContinue)
        if ($files.Count -eq 0) {
            $subdirs = @(Get-ChildItem -LiteralPath $entry.Dir.FullName -Recurse -Directory -Force -ErrorAction SilentlyContinue).Count
            [void]$problems.Add(("EMPTY_TASK_DIR: {0}  —— 0 个文件（{1} 个空子目录），不是一次真正的剪辑留下的" -f $entry.Dir.Name, $subdirs))
        }
    }
}

$maxNum = if ($byNumber.Count -gt 0) { ($byNumber.Keys | Measure-Object -Maximum).Maximum } else { 0 }

if ($Json) {
    [PSCustomObject]@{
        schema = 'naraka-task-numbering-check/v1'
        tasks_root = $tasksRoot
        task_dirs = $taskDirs.Count
        max_number = $maxNum
        next_number = $maxNum + 1
        problems = @($problems)
        notes = @($notes)
        pass = ($problems.Count -eq 0)
    } | ConvertTo-Json -Depth 5
} else {
    Write-Output "123\ 任务目录: $($taskDirs.Count) 个，最大编号 $maxNum，下一个取 $($maxNum + 1)"
    if ($problems.Count -eq 0) {
        Write-Output '[PASS] 编号唯一、命名完整、没有空壳目录'
    } else {
        foreach ($p in $problems) { Write-Output "  [VIOLATION] $p" }
    }
    foreach ($n in $notes) { Write-Output "  [NOTE] $n" }
}

exit ($(if ($problems.Count -eq 0) { 0 } else { 1 }))
