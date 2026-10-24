#Requires -Version 5.1

function Write-WinstUpdateCheckEntry {
    <#
    .SYNOPSIS
        仅检查：按版本比较结果分档（可更新 / 附加文件有更新 / 已是最新 / 本机更新）并打印报告行。
    #>
    param([hashtable]$Context, $Row, $Snap, $EntryResult, [string]$InstalledVersion, [string]$DisplayName, [hashtable]$Result, [switch]$Quiet)

    $latest = [string]$Snap.Latest
    $latestSource = [string]$Snap.LatestSource

    # 「可以更新」= 有更新版本 + 无法比较版本的两类（本机版本未知 / 软件源里没有可用的版本信息，见上）：
    # 后两类按软件源里的定义更新，列表里带着原因展示；只有「软件源里没有这个软件」与
    # 「本机版本比软件源里的更新」留给人工确认（列在无法比较里）。
    if (-not $Snap.Comparable) {
        $Result.Updatable++
        $EntryResult.Action = 'check'
        $EntryResult.Message = '本机版本未知'
    } elseif ($Snap.Cmp -gt 0) {
        $Result.Updatable++
        $EntryResult.Action = 'check'
    } elseif ($Snap.Cmp -eq 0) {
        # 版本相同、但配套文件有变化 → 单列一档「附加文件有更新」：
        # 不算版本升级、不计入「可更新到 x.y」，但要让用户看见并能选择只更新这些文件
        $companionInfo = Get-WinstRowCompanionInfo -Context $Context -Row $Row
        if ($companionInfo -and $companionInfo.CompanionsOnly) {
            $Result.Updatable++
            $EntryResult.Action = 'files'
            $EntryResult.Message = ('附加文件有更新（{0} 个）' -f $companionInfo.ChangedCount)
            $EntryResult.CompanionCount = [int]$companionInfo.ChangedCount
            $EntryResult.CompanionNames = @($companionInfo.Names)
        } else {
            $Result.UpToDate++
            $EntryResult.Action = 'latest'
        }
    } else {
        $Result.Unknown++
        $EntryResult.Action = 'newer'
        $EntryResult.Message = '本机版本比软件源里的更新'
    }

    if ($Quiet) { return }

    if ($EntryResult.Action -eq 'check') {
        $installedText = $InstalledVersion
        if (-not $installedText) { $installedText = '未知' }
        $latestText = $latest
        if (-not $latestText) { $latestText = '未知' }
        $sourceText = ''
        if ($latestSource) { $sourceText = ('（来自 {0}）' -f $latestSource) }
        $noteText = ''
        if ($EntryResult.Message) { $noteText = ('（{0}）' -f $EntryResult.Message) }
        Write-Host ('  {0}: 当前 {1}  →  新版本 {2}{3}  ↑{4}' -f $DisplayName, $installedText, $latestText, $sourceText, $noteText) -ForegroundColor Green
    } elseif ($EntryResult.Action -eq 'files') {
        Write-Host ('  {0}: 附加文件有更新（{1} 个）: {2}（主包已是最新 {3}）' -f $DisplayName, $EntryResult.CompanionCount, ($EntryResult.CompanionNames -join '、'), $InstalledVersion) -ForegroundColor Green
    } elseif ($EntryResult.Action -eq 'latest') {
        Write-Host ('  {0}: 已是最新版本（{1}）。' -f $DisplayName, $InstalledVersion) -ForegroundColor Gray
    } else {
        Write-Host ('  {0}: {1}（本机 {2}，软件源 {3}）。' -f $DisplayName, $EntryResult.Message, $InstalledVersion, $latest) -ForegroundColor DarkYellow
    }
}
