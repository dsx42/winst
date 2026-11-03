#Requires -Version 5.1

function Write-WinstCachedList {
    <#
    .SYNOPSIS
        `winst list --cached`：列出已下载的安装包（先按索引确定展示项，再按需刷新版本）。
    .OUTPUTS
        [int] 退出码
    #>
    param([hashtable]$Context)

    # 展示项、按需刷新与总览重建都在 Get-WinstCachedOverviewReady 里（与菜单页同一段逻辑）
    $ready = Get-WinstCachedOverviewReady -Context $Context
    if (-not $ready.Ok) {
        Write-Host ''
        Write-Host ('  {0}' -f $ready.Error) -ForegroundColor Red
        return 1
    }
    if ($ready.Warning) { Write-Host ('  提示: {0}' -f $ready.Warning) -ForegroundColor Yellow }

    $items = @($ready.Items)
    Write-Host ''
    if ($items.Count -eq 0) {
        Write-Host '  安装包位置里还没有下载好的安装包。' -ForegroundColor Yellow
        Write-Host ('  安装包位置: {0}  {1}' -f $Context.PkgDir, $Context.PkgDirLabel) -ForegroundColor Gray
        Write-Host '  提示: 安装或更新软件时会自动把安装包下载到这里。' -ForegroundColor DarkGray
        return 0
    }

    # 安装包位置只在开头给一次：每个软件的包都在 <安装包位置>\<id>\ 下
    Write-Host ('  安装包位置: {0}  {1}' -f $Context.PkgDir, $Context.PkgDirLabel) -ForegroundColor Gray

    $packageUpdatable = 0
    $installedUpdatable = 0
    $installedCount = 0
    $index = 0
    $hasGrouped = [bool](@($items | Where-Object { [string]$_['Group'] }).Count)
    $lastGroup = ''
    foreach ($item in $items) {
        $index++
        $lastGroup = Write-WinstGroupHeading -Group ([string]$item['Group']) -LastGroup $lastGroup -ShowUngrouped:$hasGrouped
        Write-WinstCachedRow -Item $item -Number $index
        if ([bool]$item['Installed']) { $installedCount++ }
        if ([bool]$item['Installed'] -and [string]$item['InstalledUpdateState'] -eq 'update') { $installedUpdatable++ }
        if ([bool]$item['HasPackageUpdate']) { $packageUpdatable++ }
    }

    Write-Host ''
    $notes = @()
    if ($packageUpdatable -gt 0) { $notes += ('{0} 个安装包可以更新' -f $packageUpdatable) }
    if ($installedUpdatable -gt 0) { $notes += ('{0} 个已装软件可以升级' -f $installedUpdatable) }
    if ($notes.Count -gt 0) { Write-Host ('  其中 {0}。' -f ($notes -join '，')) -ForegroundColor Green }
    Write-Host ('  共 {0} 个已下载的安装包，{1} 个已安装。' -f $items.Count, $installedCount) -ForegroundColor DarkGray
    Write-Host '  安装 / 更新: winst install <id>    删除: winst clean <id>' -ForegroundColor DarkGray
    Write-Host '  「仅下载」类型: winst download <id> 下载 / 更新软件包，winst clean <id> 删除软件包' -ForegroundColor DarkGray
    return 0
}
