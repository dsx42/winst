#Requires -Version 5.1

function Show-WinstCachedActionMenu {
    <#
    .SYNOPSIS
        按条目状态渲染可选动作（i / u / x / d），仅展示当前可用的项。
    #>
    param($Item)

    $inCatalog = [bool]$Item['InCatalog']
    $isDownloadType = ([string]$Item['Type'] -eq 'download')
    $canUpgradeInstalled = ([bool]$Item['Installed'] -and ([string]$Item['InstalledUpdateState'] -eq 'update'))
    $canDownloadPackage = [bool]$Item['HasPackageUpdate']

    Write-Host ''
    if ($isDownloadType) {
        # 仅下载类型：已下载的软件包只有「更新软件包」与「删除软件包」两件事
        if (-not $inCatalog) {
            Write-Host '  软件源里没有这个软件，只能删除已下载的软件包。' -ForegroundColor DarkYellow
        } elseif ($canDownloadPackage) {
            Write-Host ('  x) 更新软件包到 {0}（现在是 {1}）' -f [string]$Item['BestVersion'], [string]$Item['CacheVersionText']) -ForegroundColor White
        } else {
            Write-Host ('  已下载的软件包 {0} 已是软件源里的最新版。' -f [string]$Item['CacheVersionText']) -ForegroundColor DarkGray
        }
        Write-Host ('  d) 删除已下载的软件包（{0} 个文件）' -f [int]$Item['CacheFileCount']) -ForegroundColor White
    } else {
        if ($inCatalog) {
            Write-Host '  i) 安装（缓存里有这个包就直接用，不再重复下载）' -ForegroundColor White
        } else {
            Write-Host '  软件源里没有这个软件，只能删除已下载的安装包。' -ForegroundColor DarkYellow
        }
        if ($canUpgradeInstalled) {
            Write-Host ('  u) 更新已安装的软件（{0}  →  {1}）' -f [string]$Item['InstalledVersionText'], [string]$Item['BestVersion']) -ForegroundColor White
        }
        if ($canDownloadPackage) {
            Write-Host ('  x) 下载更新包（安装包 {0}  →  {1}）' -f [string]$Item['CacheVersionText'], [string]$Item['BestVersion']) -ForegroundColor White
        }
        Write-Host ('  d) 删除已下载的安装包（{0} 个文件）' -f [int]$Item['CacheFileCount']) -ForegroundColor White
    }
    Write-Host '  b) 返回列表    q) 退出' -ForegroundColor DarkGray
}
