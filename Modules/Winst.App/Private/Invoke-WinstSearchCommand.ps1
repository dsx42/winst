#Requires -Version 5.1

function Invoke-WinstSearchCommand {
    <#
    .SYNOPSIS
        CLI：winst search <关键字> [<关键字>...] —— 搜索全部软件源，按 id 输出（含来源与版本）。
    .DESCRIPTION
        多个关键字（空格分隔）走「整串优先、搜不到再分别搜索并合并去重」的同一套规则。
    .OUTPUTS
        [int] 退出码
    #>
    param(
        [Parameter(Mandatory = $true)][hashtable]$Context,
        [string[]]$Arguments = @()
    )

    $keyword = ''
    if ($Arguments -and $Arguments.Count -gt 0) {
        $tokens = @()
        foreach ($one in @($Arguments)) {
            $text = ([string]$one).Trim()
            if ($text) { $tokens += $text }
        }
        $keyword = ($tokens -join ' ')
    }
    if (-not $keyword) {
        Write-Host ''
        Write-Host '  用法: winst search <关键字> [<关键字>...]' -ForegroundColor Yellow
        Write-Host '  示例: winst search jdk        （也可一次搜多个: winst search jdk21 jdk25）' -ForegroundColor Gray
        return 1
    }

    # 先按缓存搜出要展示的软件，再按需刷新这些软件的版本信息，
    # 刷新有成果时用新数据重新搜索展示——不把软件源里所有软件都解析一遍
    $lookup = Search-WinstRowsWithRefresh -Context $Context -Keyword $keyword -Quiet
    $searched = $lookup.Searched

    $rows = @($searched.Rows)
    $state = (Read-WinstState -InstallRoot $Context.InstallRoot).State

    Write-Host ''
    if ($searched.Merged -and $rows.Count -gt 0) {
        Write-Host ('  没有整体匹配「{0}」的软件，已按 {1} 个关键字分别搜索并合并结果。' -f $keyword, @($searched.Keywords).Count) -ForegroundColor DarkGray
    }
    if ($rows.Count -eq 0) {
        Write-Host ('  没有找到和「{0}」有关的软件。' -f $keyword) -ForegroundColor Yellow
        return 0
    }

    $index = 0
    $downloadTypeCount = 0
    $hasGrouped = [bool](@($rows | Where-Object { [string]$_['Group'] }).Count)
    $lastGroup = ''
    foreach ($row in $rows) {
        $index++
        $lastGroup = Write-WinstGroupHeading -Group ([string]$row['Group']) -LastGroup $lastGroup -ShowUngrouped:$hasGrouped
        $installedVersion = ''
        $installedDir = ''
        $ledger = Get-WinstInstalledApp -State $state -Id ([string]$row['Id'])
        if ($ledger) {
            $installedVersion = Get-EntryString -Entry $ledger -Key 'version'
            $installedDir = Get-EntryString -Entry $ledger -Key 'installDir'
        }
        Write-Host ('  {0}) {1}  ({2})' -f $index, [string]$row['Name'], [string]$row['Id']) -NoNewline -ForegroundColor White
        if ($installedVersion) {
            Write-Host ('    已安装 {0}' -f $installedVersion) -NoNewline -ForegroundColor Green
            $upgradeHint = Get-WinstUpgradeHint -Row $row -InstalledVersion $installedVersion
            if ($upgradeHint) { Write-Host ('  {0}' -f $upgradeHint) -ForegroundColor Green } else { Write-Host '' }
        } else {
            Write-Host ''
        }
        if ($installedDir) { Write-Host ('     安装路径: {0}' -f $installedDir) -ForegroundColor Gray }
        if ((Get-WinstRowType -Row $row) -eq 'download') {
            $downloadTypeCount++
            Write-Host '     类型: 只下载软件包，不安装到电脑（下载 / 更新软件包 / 删除软件包）' -ForegroundColor DarkGray
        }
        Write-Host ('     来源: {0}' -f (Get-WinstRowSourceText -Row $row)) -ForegroundColor Gray
        if ([string]$row['Description']) { Write-Host ('     说明: {0}' -f [string]$row['Description']) -ForegroundColor DarkGray }
    }
    Write-Host ''
    $footer = ('  共 {0} 个软件。安装: winst install <id>' -f $rows.Count)
    if ($downloadTypeCount -gt 0) { $footer += ('    「仅下载」类型（{0} 个）: winst download <id> 下载 / 更新软件包' -f $downloadTypeCount) }
    Write-Host $footer -ForegroundColor DarkGray
    return 0
}
