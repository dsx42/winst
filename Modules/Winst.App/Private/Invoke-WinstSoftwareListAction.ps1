#Requires -Version 5.1

function Invoke-WinstSoftwareListAction {
    <#
    .SYNOPSIS
        执行软件列表里的一个动作（i / p / u / d / x）。
    .OUTPUTS
        [bool] 是否执行了动作（需要重新载入列表）
    #>
    param([hashtable]$Context, $Item, [string]$Text)

    $id = [string]$Item['Id']
    $installed = [bool]$Item['Installed']
    $cacheHas = [bool]$Item['CacheHas']
    $isDownloadType = ([string]$Item['Type'] -eq 'download')
    $canUpdate = ($installed -and ([string]$Item['InstalledUpdateState'] -eq 'update'))
    $canUpdatePackage = ($isDownloadType -and $cacheHas -and [bool]$Item['HasPackageUpdate'])

    if ($Text -eq 'i') {
        if ($installed) {
            Write-Host '  这个软件已经装在这台电脑上了，可用 u) 更新。' -ForegroundColor DarkYellow
        } elseif ($isDownloadType -and $cacheHas -and -not $canUpdatePackage) {
            Write-Host '  这个软件包已经是最新的，安装包位置里那份会直接复用，不会重复下载。' -ForegroundColor DarkYellow
        } else {
            # 仅下载类型：这一步就是「下载软件包」（安装流程对它只下载、不安装）
            $null = Invoke-WinstInstallTarget -Context $Context -Row $Item['Row']
        }
        return $true
    }

    if ($Text -eq 'p') {
        if ($isDownloadType) {
            Write-Host '  这是「仅下载软件包」类型的软件，请用 i) 下载软件包 / u) 更新软件包。' -ForegroundColor DarkYellow
        } else {
            # 只下载安装包（与「已下载包 → x 下载更新包」同一实现）：不安装、不写台账、不改系统项
            $null = Invoke-WinstDownloadUpdates -Context $Context -Items @($Item) -Download
        }
        return $true
    }

    if ($Text -eq 'u') {
        if ($isDownloadType) {
            if (-not $canUpdatePackage) {
                Write-Host '  这个软件包现在没有可更新的版本。' -ForegroundColor DarkYellow
            } else {
                # 仅下载类型：更新 = 把已下载的软件包换成软件源里的新版（与「已下载包 → x」同一实现）
                $null = Invoke-WinstDownloadUpdates -Context $Context -Items @($Item)
            }
        } elseif (-not $canUpdate) {
            Write-Host '  这个软件现在没有可更新的版本。' -ForegroundColor DarkYellow
        } else {
            $null = Invoke-WinstUpgradeAll -Context $Context -Items @($Item)
        }
        return $true
    }

    if ($Text -eq 'd') {
        if ($isDownloadType) {
            Write-Host '  「仅下载软件包」类型的软件不安装到电脑，没有可卸载的东西；可以下载 / 更新 / 删除它的软件包。' -ForegroundColor DarkYellow
        } elseif (-not $installed) {
            Write-Host '  这个软件没有安装，无法卸载。' -ForegroundColor DarkYellow
        } else {
            Write-WinstUninstallResult -Result (Invoke-WinstUninstallApp -Context $Context -Id $id)
        }
        return $true
    }

    if ($Text -eq 'x') {
        Remove-WinstSoftwareCachedPackage -Context $Context -Item $Item
        return $true
    }

    return $false
}
