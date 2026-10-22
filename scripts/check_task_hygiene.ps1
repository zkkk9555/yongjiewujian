<#
    check_task_hygiene.ps1  --  task-directory hygiene gate.

    A task directory must not accumulate loose weight at its root, and must not
    keep more than two versions of the preview or the timeline.  Violations are
    hard failures; shot-frame residue is reported as INFO only, because those are
    deliberately kept until the freeze gate clears them.

    Exit codes:
      0  clean (no hard violations; INFO-SHOT rows may still be printed)
      1  hard violations present
      2  task dir not found

    NOTE: rebuilt 2026-09-29 after an editing accident truncated the previous
    file to 3 bytes (no backup existed).  Behaviour is reproduced from the
    documented spec, the original grep-level line inventory, and the recorded
    output of task 849; it is not a byte-for-byte recovery.
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$TaskDir
)

$ErrorActionPreference = 'Continue'

Write-Output "TaskDir: $TaskDir"

if (-not (Test-Path -LiteralPath $TaskDir -PathType Container)) {
    Write-Output ("[FAIL] task dir not found: {0}" -f $TaskDir)
    exit 2
}

# NB: keep this file saved as UTF-8 WITH BOM.  PowerShell 5.1 decodes a BOM-less
# file with the ANSI code page, which turns every non-ASCII char in these
# messages into mojibake.  Worse, if a *path* literal ever goes mojibake like
# this, the script writes to a garbage directory instead of the real one.
# See docs/TROUBLESHOOTING.md -> 脚本里的中文全变乱码.

$violations = New-Object System.Collections.ArrayList

# --- 1. 任务根散文件：jpg/mp4/srt 必须为 0（§2.7 全部落子目录）--------------
$rootLoose = @(Get-ChildItem -LiteralPath $TaskDir -File -Force -ErrorAction SilentlyContinue |
               Where-Object { $_.Name -match '\.(jpg|jpeg|png|mp4|srt)$' })
foreach ($f in $rootLoose) {
    [void]$violations.Add(("ROOT_LOOSE:{0}" -f $f.FullName))
}

# --- 2. 0 字节日志/清单：报 INFO，不判硬违规（2026-10-22 改）--------------------
# 原来判硬违规的理由是「多为误当成应该删的 log」。实测这些 0 字节文件有两种**相反**的含义：
#   - `render_4k_stderr.log` 为 0 字节 = 渲染**没有 stderr 输出**（成功）；
#   - `adv6_namegrep.txt` 为 0 字节 = **那一次检测可能压根没跑起来**
#     （`TROUBLESHOOTING.md` T3：「任何检测日志生成后必须逐段确认它非空。空日志 = 工具没跑起来 = 结论无效」）。
# 所以这里**不能**一律当成「干净」——本条只负责**列出来**，判读归人：
# 看到 0 字节的**检测类**日志，按 T3 逐个确认它不是空跑；0 字节的 **stderr/stdout** 才是「无输出」。
# ⇒ 降为 INFO 并逐条列出；要清空它们请在收尾清理里显式记账（AGENTS.md §7.1）。
$zeroLogs = @(Get-ChildItem -Recurse -LiteralPath $TaskDir -File -Force -ErrorAction SilentlyContinue |
              Where-Object { $_.Length -eq 0 -and $_.Name -match '\.(log|txt)$' })
if ($zeroLogs.Count -gt 0) {
    Write-Output ("[INFO-ZERO] {0} zero-byte log/txt file(s) -- 逐个判读：stdout/stderr 为空 = 无输出(正常)；" + "`n" + "             检测类日志为空 = 工具可能没跑起来（见 TROUBLESHOOTING.md T3），不要默认当成成功：" -f $zeroLogs.Count)
    foreach ($f in $zeroLogs) { Write-Output ("  " + $f.FullName) }
}

# --- 2b. timeline\ 只放时间线数据：图片/视频属于 shots\，放错就永远删不掉 ------
# 起因：18.860 把 2351 张取证帧（667.8 MB）写进了 timeline\evidence_v*\。因为 timeline\
# 是收尾清理的"保留项"，这 614 MB 永远不会被回收，任务目录再也瘦不下来。
# 取证帧的唯一正确位置是 shots\。这里判硬违规，不只是提示。
$tlRoot = Join-Path $TaskDir 'timeline'
$tlStray = @()
if (Test-Path -LiteralPath $tlRoot -PathType Container) {
    # Only media is a violation.  Build scripts (.py/.ps1) and notes under
    # timeline\evidence_v*\ are legitimate task evidence -- a previous revision of
    # this check flagged them too, which was wrong.
    $tlStray = @(Get-ChildItem -Recurse -LiteralPath $tlRoot -File -Force -ErrorAction SilentlyContinue |
                 Where-Object { $_.Extension -match '^\.(jpg|jpeg|png|gif|bmp|webp|tif|tiff|mp4|mkv|mov|webm|avi)$' })
    foreach ($f in $tlStray) {
        [void]$violations.Add(("MISCABLED_TIMELINE:{0}  (取证帧/媒体应放 shots\,不是 timeline\)" -f $f.FullName))
    }
}

# --- 3. 旧预览：报 INFO，不判硬违规（2026-10-22 改）----------------------------
# 「只留相邻两版」的想法来自省磁盘。实测两件事：
#   1) 母版出完后 `scripts\cleanup_after_master.ps1` 会删掉整个 `preview\`，本条其实已无对象；
#   2) 出 4K 之前预览目录仍在，此时它正是**唯一能看的审片件**，按版本数删它没有收益。
# ⇒ 降为 INFO 并逐条列出；预览目录的删除由收尾清理统一做（有 log 记账）。
$pvNums = @(Get-ChildItem -LiteralPath (Join-Path $TaskDir 'preview') -File -Force -ErrorAction SilentlyContinue |
            ForEach-Object {
                if ($_.Name -match '-review-v(\d+)\.mp4$') { [int]$Matches[1] }
                elseif ($_.Name -match '-review-v(\d+)\.') { [int]$Matches[1] }
            } | Sort-Object -Unique)
$staleNums = $pvNums | Select-Object -SkipLast 2
if ($staleNums.Count -gt 0) {
    Write-Output ("[INFO-PREVIEW] {0} older preview version(s) (preview\ is removed wholesale by cleanup_after_master.ps1):" -f $staleNums.Count)
    foreach ($n in $staleNums) { Write-Output ("  *-review-v{0}.mp4(+concat/decode)" -f $n) }
}

# --- 4. 旧时间线：报 INFO，不判硬违规（2026-10-22 改）----------------------------
# 这里原来判硬违规，但**版本血统是证据**：冻结门禁表的「边界集与上一版逐字节相同」
# 这类结论（858 v3 就是）要靠历史版本当场比对才能复核，删掉就再也证不了。
# 体积上也不值得：一份时间线 JSON 约 0.1 MB，19 个任务目录加起来不到 10 MB。
# ⇒ 降为 INFO 并逐条列出；要瘦身请显式删除并在 `reports\cleanup_log_*.md` 里记账。
$epNums = @(Get-ChildItem -LiteralPath (Join-Path $TaskDir 'timeline') -File -Force -ErrorAction SilentlyContinue |
            ForEach-Object {
                if ($_.Name -match 'combat_episodes_v(\d+)\.json$') { [int]$Matches[1] }
            } | Sort-Object -Unique)
$staleNums = $epNums | Select-Object -SkipLast 2
if ($staleNums.Count -gt 0) {
    Write-Output ("[INFO-TIMELINE] {0} older timeline version(s) kept as version-lineage evidence (AGENTS.md 7.1 keep-list):" -f $staleNums.Count)
    foreach ($n in $staleNums) { Write-Output ("  combat_episodes_v{0}.json" -f $n) }
}

# --- 5. shots\ 零散取证帧：只提示，不判 FAIL -----------------------------------
# 散帧与 0 字节日志 / 旧预览 / 旧时间线不同，是"预计将来清理、当前预期存在"。
# 按 SHOT_STRAY 提示输出即可，整条 exit 0；不计入 violations。
$shotFiles = @(Get-ChildItem -Recurse -LiteralPath (Join-Path $TaskDir 'shots') -File -Force -ErrorAction SilentlyContinue)
$shotStray = @($shotFiles | Where-Object { $_.Name -match '^verify_.*\.md$' -or $_.Extension -eq '.ps1' -or $_.Name -match '^audio_.*\.log$' })
if ($shotStray.Count -gt 0) {
    Write-Output ("[INFO-SHOT] {0} stray file(s) under shots\ (freeze-later cleanups, not failures):" -f $shotStray.Count)
    foreach ($f in $shotStray) { Write-Output ("  " + $f.FullName) }
}

# --- 6. 经验落盘：命名必须带任务目录号，缺失要报 ------------------------------
# 这局学到了什么写在 reports\workflow_notes_<任务目录号>.md。命名过去混用过
# 目录号和素材号（_849 / _863），collect_lessons.ps1 认不出来就没法判断
# 某条是否已吸收，经验池会退化成摆设。
#
# **判据是「前缀式」而不是「完全相等」（2026-10-22 改）**：
# 一个任务目录可以合法地有多份经验（指挥层一份 + 每段一份），
# 例如 35.889 有 workflow_notes_35.md / _35_commander*.md / _35_seg1..28.md 共 32 份。
# 老判据要求文件名**恰好等于** workflow_notes_<号>.md，把这 32 份全判成违规
# ——门禁一开就是 39 条噪声，真正的错（13.849 里的 _849.md、20.863 里的 _863.md）
# 反而淹在里面。现在规则是：
#   规范名  workflow_notes_<任务目录号>.md          （本任务的主经验文件）
#   派生名  workflow_notes_<任务目录号>_<后缀>.md     （指挥层/分段等附属经验）
# 两者都以「workflow_notes_<任务目录号>」开头，都算合规。
#
# 缺 notes 是 INFO 而不是 FAIL：并发扫描或简单渲染任务本来就没经验可写，
# 判 FAIL 会制造大量噪声。真正要拦的是"写了但名字不对"——那份经验收不进池子。
# 注意括号：写成 `Split-Path -Leaf $TaskDir -match '^...'` 会被 PowerShell 解析成
# 把 -match 当参数名传给 Split-Path（ParameterBindingException），而那是非终止
# 错误 —— 脚本会照常打印 PASS，整条检查被静默跳过。必须 (Split-Path ...) 包起来。
$taskNum = ''
if ((Split-Path -Leaf $TaskDir) -match '^(\d+)\.') { $taskNum = $Matches[1] }
$reportsDir = Join-Path $TaskDir 'reports'
# 经验文件按**递归**找，与 collect_lessons.ps1 的扫描面一致（2026-10-22 改）。
# 原来只看 reports\ 顶层：落在任务根或子目录里的经验文件能绕过这道硬门。
$notesFiles = @(Get-ChildItem -LiteralPath $TaskDir -Recurse -File -Filter 'workflow_notes*.md' -Force -ErrorAction SilentlyContinue)
if ($notesFiles.Count -eq 0) {
    Write-Output "[INFO-NOTES] reports\ has no workflow_notes*.md -- if this task learned anything, write it before the directory is archived"
} elseif ($taskNum) {
    $expected = "workflow_notes_$taskNum.md"
    $namePat = "^workflow_notes_${taskNum}(_.*)?\.md$"
    $badNames = @($notesFiles | Where-Object { $_.Name -notmatch $namePat })
    foreach ($f in $badNames) {
        [void]$violations.Add(("NOTES_NAME:{0}  (应为 {1} 或 workflow_notes_{1}_<后缀>.md，否则 collect_lessons.ps1 认不出这条经验)" -f $f.Name, $taskNum))
    }
    if ($badNames.Count -eq 0) {
        Write-Output ("[INFO-NOTES] workflow notes present and correctly named: {0} (+{1} 附属文件)" -f $expected, ($notesFiles.Count - 1))
    }
}

# --- 7. 保留目录里不该有音视频（2026-10-22 立）--------------------------------
# `shots\` `cache\` `preview\` 里的媒体是**已知**的可再生重量，收尾清理会整目录删掉；
# 但**留在 `analysis\` `reports\` `timeline\` `captions\` 等保留目录里的音视频**没人管过——
# 888 的 `analysis\autoeditor_ref.mp4`（344,518,665 B / 3840×2160 / 92 s）就是这么
# 在任务结束后还占着 328.6 MiB 的（用户原话：「888 任务都结束了，为什么还有三百多兆的 video 吗」）。
#
# 判据：保留区里出现 **> 10 MB 的音视频文件** = 硬违规。
# 阈值 10 MB 是为了不误伤取证用的零头小片段（886 的 reports\ 里有一批几十 KB 的联系表）。
$keepRoots = @('analysis', 'reports', 'timeline', 'captions', 'deliverables')
$MediaExt = '^\.(mp4|mkv|avi|mov|webm|m4v|m2ts|wmv|flv|wav|mp3|m4a|aac|flac)$'
$strayBig = @(
    Get-ChildItem -LiteralPath $TaskDir -Recurse -File -Force -ErrorAction SilentlyContinue |
    Where-Object {
        $_.Extension -match $MediaExt -and $_.Length -gt 10MB -and
        -not ($keepRoots | Where-Object { $_.FullName -match ('\\' + [regex]::Escape($_) + '\\') })
    }
)
foreach ($f in $strayBig) {
    [void]$violations.Add(("STRAY_MEDIA:{0}  ({1:N1} MB)  —— 保留目录里不该留音视频：它可再生（源片在 E  盘完好，重跑一次就有），" -f $f.FullName, ($f.Length / 1MB)))
}

# --- 汇总 ----------------------------------------------------------------------

Write-Output ("Checks: root-loose/zero-byte/misplaced-timeline/stale-preview/stale-timeline (+shot-info)")
foreach ($v in $violations) { Write-Output ("  [VIOLATION] " + $v) }

if ($violations.Count -eq 0) {
    Write-Output "[PASS] hygiene clean (hard gates)."
    exit 0
}

Write-Output ("Total hard violations: {0} ([INFO-SHOT] rows above are freeze-later cleanups, not failures)" -f $violations.Count)
exit 1
