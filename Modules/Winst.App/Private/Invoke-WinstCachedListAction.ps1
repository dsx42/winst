#Requires -Version 5.1

function Invoke-WinstCachedListAction {
    <#
    .SYNOPSIS
        执行「已下载包」里的一个动作（i / u / x / d）。
    .OUTPUTS
        [bool] 是否执行了动作（需要重新载入列表）
    #>
    param([hashtable]$Context, $Item, [string]$Text)

    $inCatalog = [bool]$Item['InCatalog']
    $isDownloadType = ([string]$Item['Type'] -eq 'download')
    $canUpgradeInstalled = ([bool]$Item['Installed'] -and ([string]$Item['InstalledUpdateState'] -eq 'update'))
    $canDownloadPackage = [bool]$Item['HasPackageUpdate']

    if ($Text -eq 'i') {
        if ($isDownloadType) {
            Write-Host '  这是「仅下载软件包」类型的软件，不安装到电脑；可用 x) 更新软件包、d) 删除软件包。' -ForegroundColor DarkYellow
        } elseif (-not $inCatalog) {
            Write-Host '  软件源里没有这个软件，无法安装；如需保留安装包请自行到上面的位置复制。' -ForegroundColor Yellow
        } else {
            # 复用既有安装流程：展示详情 → 确认 → 安装（缓存命中就不下载，已装同版本时再问是否强制重装）
            $null = Invoke-WinstInstallTarget -Context $Context -Row $Item['Row']
        }
        return $true
    }

    if ($Text -eq 'u') {
        if ($isDownloadType) {
            Write-Host '  这是「仅下载软件包」类型的软件，没有安装记录；请用 x) 更新软件包。' -ForegroundColor DarkYellow
        } elseif (-not $canUpgradeInstalled) {
            Write-Host '  这个软件现在没有可更新的版本。' -ForegroundColor DarkYellow
        } else {
            $null = Invoke-WinstUpgradeAll -Context $Context -Items @($Item)
        }
        return $true
    }

    if ($Text -eq 'x') {
        if (-not $canDownloadPackage) {
            if ($isDownloadType) { Write-Host '  这个软件包已经是最新的，不需要重新下载。' -ForegroundColor DarkYellow }
            else { Write-Host '  这个安装包已经是最新的，不需要重新下载。' -ForegroundColor DarkYellow }
        } else {
            $null = Invoke-WinstDownloadUpdates -Context $Context -Items @($Item)
        }
        return $true
    }

    if ($Text -eq 'd') {
        # 与「软件列表 → x」共用同一套删除流程（展示内容 → 确认 → 删除）
        Remove-WinstSoftwareCachedPackage -Context $Context -Item $Item
        return $true
    }

    return $false
}
