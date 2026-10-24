#Requires -Version 5.1

function Show-WinstSoftwareActionMenu {
    <#
    .SYNOPSIS
        按软件状态渲染可选动作（i / p / u / d / x），仅展示当前可用的项。
    #>
    param($Item)

    $installed = [bool]$Item['Installed']
    $cacheHas = [bool]$Item['CacheHas']
    $isDownloadType = ([string]$Item['Type'] -eq 'download')
    $canUpdate = ($installed -and ([string]$Item['InstalledUpdateState'] -eq 'update'))
    # 仅下载类型没有安装记录，它的「更新」看的是已下载的软件包能否换成软件源里的新版
    $canUpdatePackage = ($isDownloadType -and $cacheHas -and [bool]$Item['HasPackageUpdate'])

    Write-Host ''
    if ($isDownloadType) {
        # 仅下载类型的软件只有三个操作：下载软件包 / 更新软件包 / 删除软件包
        if (-not $cacheHas) {
            Write-Host '  i) 下载软件包（只下载到安装包位置，不安装到电脑）' -ForegroundColor White
        }
        if ($canUpdatePackage) {
            Write-Host ('  u) 更新软件包到 {0}（现在是 {1}）' -f [string]$Item['BestVersion'], [string]$Item['CacheVersionText']) -ForegroundColor White
        }
        if ($cacheHas) {
            Write-Host ('  x) 删除已下载的软件包（{0} 个文件）' -f [int]$Item['CacheFileCount']) -ForegroundColor White
        }
    } else {
        if (-not $installed) {
            Write-Host '  i) 安装（缓存里有这个包就直接用，不再重复下载）' -ForegroundColor White
        }
        Write-Host '  p) 下载软件包（只下载到安装包位置，不安装到电脑）' -ForegroundColor White
        if ($canUpdate) {
            Write-Host ('  u) 更新到 {0}（现在是 {1}）' -f [string]$Item['BestVersion'], [string]$Item['InstalledVersionText']) -ForegroundColor White
        }
        if ($installed) {
            Write-Host '  d) 卸载（从电脑上移除这个软件）' -ForegroundColor White
        }
        if ($cacheHas) {
            Write-Host ('  x) 删除已下载的安装包（{0} 个文件）' -f [int]$Item['CacheFileCount']) -ForegroundColor White
        }
    }
    Write-Host '  b) 返回列表    q) 退出' -ForegroundColor DarkGray
}
