#Requires -Version 5.1

function Show-WinstCachedActionMenu {
    <#
    .SYNOPSIS
        按条目状态渲染可选动作（i / u / x / d / s），仅展示当前可用的项。
    #>
    param($Item, [string]$PackageTarget, $Recovery)

    $inCatalog = [bool]$Item['InCatalog']
    $isDownloadType = ([string]$Item['Type'] -eq 'download')
    $canUpgradeInstalled = ([bool]$Item['Installed'] -and ([string]$Item['InstalledUpdateState'] -eq 'update'))
    $recoveryLabel = if ($Recovery -and $Recovery.Action) {
        switch ($Recovery.Action) {
            'Continue'   { '继续下载' }
            'Redownload' { '重新下载' }
            'Move'       { '重试移入缓存' }
            'Register'   { '重试登记缓存' }
            'Inspect'    { '重新检查下载状态' }
        }
    }
    $canDownloadPackage = [bool]$Item['HasPackageUpdate'] -and -not $recoveryLabel

    Write-Host ''
    if ($isDownloadType) {
        # 仅下载类型：已下载的软件包提供更新与删除操作
        if (-not $inCatalog) {
            Write-Host '  软件源里没有这个软件，可刷新软件源或删除已下载的软件包。' -ForegroundColor DarkYellow
        } elseif ($canDownloadPackage) {
            Write-Host ('  x) 更新软件包（{0}  →  {1}）' -f [string]$Item['CacheVersionText'], $PackageTarget) -ForegroundColor White
        } elseif (-not $recoveryLabel -and $Item['CacheFileCount']) {
            $status = Get-WinstVersionConclusion -Item $Item -Kind package
            Write-Host ('  ' + $status.Text) -ForegroundColor $status.Color
        }
        if ($Item['CacheFileCount']) {
            Write-Host ('  d) 删除已下载的软件包（{0} 个文件）' -f [int]$Item['CacheFileCount']) -ForegroundColor White
        }
    } else {
        if ($inCatalog) {
            Write-Host '  i) 安装' -ForegroundColor White
        } else {
            Write-Host '  软件源里没有这个软件，可刷新软件源或删除已下载的安装包。' -ForegroundColor DarkYellow
        }
        if ($canUpgradeInstalled -and -not $Item['LatestVersion']) {
            Write-Host ('  u) 更新已安装的软件（{0}）' -f $Item['InstalledUpdateHint']) -ForegroundColor White
        } elseif ($canUpgradeInstalled) {
            Write-Host ('  u) 更新已安装的软件（{0}  →  {1}）' -f [string]$Item['InstalledVersionText'], [string]$Item['LatestVersion']) -ForegroundColor White
        }
        if ($canDownloadPackage) {
            Write-Host ('  x) 下载更新包（安装包 {0}  →  {1}）' -f [string]$Item['CacheVersionText'], $PackageTarget) -ForegroundColor White
        }
        if ($Item['CacheFileCount']) {
            Write-Host ('  d) 删除已下载的安装包（{0} 个文件）' -f [int]$Item['CacheFileCount']) -ForegroundColor White
        }
    }
    if ($recoveryLabel) { Write-Host ('  x) ' + $recoveryLabel) -ForegroundColor White }
    Write-Host '  s) 刷新这个软件条目的软件源' -ForegroundColor White
    Write-Host '  b) 返回列表    q) 退出' -ForegroundColor DarkGray
}
