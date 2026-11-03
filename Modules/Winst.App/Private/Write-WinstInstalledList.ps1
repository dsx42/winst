#Requires -Version 5.1

function Write-WinstInstalledList {
    <#
    .SYNOPSIS
        `winst list --installed`（默认）：列出已安装的软件（逐条含版本 / 安装位置 / 安装方式 / 来源）。
    .OUTPUTS
        [int] 退出码
    #>
    param([hashtable]$Context)

    # 先读台账拿到要展示的软件，再按需刷新它们的版本信息，
    # 保证「可更新」标注是当前值；台账为空（没有已装软件）时不做任何刷新
    $ledgerIds = @(Get-WinstDisplayIds -Ids (Read-WinstInstalledKeys -Context $Context))
    $refresh = Update-WinstDisplaySources -Context $Context -Ids $ledgerIds
    Write-WinstRefreshErrors -Errors $refresh.Errors

    $overview = Get-WinstInstalledOverview -Context $Context
    if (-not $overview.Ok) {
        Write-Host ''
        Write-Host ('  {0}' -f $overview.Error) -ForegroundColor Red
        return 1
    }
    if ($overview.Warning) { Write-Host ('  提示: {0}' -f $overview.Warning) -ForegroundColor Yellow }

    # Where-Object 过滤掉 $null 条目：列表函数一旦返回 $null，@() 会把它变成一个「空条目」→ 渲染时报错
    $items = @($overview.Items | Where-Object { $null -ne $_ })
    Write-Host ''
    if ($items.Count -eq 0) {
        Write-Host '  安装记录里还没有已安装的软件。' -ForegroundColor Yellow
        Write-Host '  提示: 如果软件已经装在这台电脑上，可用 winst repair 重新扫描找回。' -ForegroundColor DarkGray
        return 0
    }

    $index = 0
    $hasGrouped = [bool](@($items | Where-Object { [string]$_['Group'] }).Count)
    $lastGroup = ''
    foreach ($item in $items) {
        $index++
        $lastGroup = Write-WinstGroupHeading -Group ([string]$item['Group']) -LastGroup $lastGroup -ShowUngrouped:$hasGrouped
        Write-WinstInstalledRow -Item $item -Number $index
    }

    Write-Host ''
    $summary = Get-WinstInstalledSummary -Items $items
    Write-Host ('  {0}' -f $summary.Text) -ForegroundColor $summary.Color
    Write-Host ('  共 {0} 个已安装软件。更新: winst update [<id>|--all]    卸载: winst uninstall <id>' -f $items.Count) -ForegroundColor DarkGray
    return 0
}
