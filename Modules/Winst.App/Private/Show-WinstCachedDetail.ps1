#Requires -Version 5.1

function Show-WinstCachedDetail {
    <#
    .SYNOPSIS
        「已下载包」的详情页：安装包（路径 / 版本 / 文件 / 大小）+ 是否已安装与已装版本 + 已装软件能否更新 + 软件源里的版本 + 安装包能否更新。
    #>
    param(
        [Parameter(Mandatory = $true)][hashtable]$Context,
        [Parameter(Mandatory = $true)]$Item
    )

    Write-WinstDetailHeader -Item $Item

    # 已下载的安装包：版本 / 大小 / 文件（安装或更新时缓存命中就直接使用，不重复下载）
    Write-Host ('    已下载包 : 版本 {0}' -f [string]$Item['CacheVersionText']) -NoNewline -ForegroundColor Gray
    Write-Host ('    {0}（{1} 个文件）' -f [string]$Item['CacheSizeText'], [int]$Item['CacheFileCount']) -ForegroundColor Gray
    Write-Host ('    存放位置 : {0}' -f [string]$Item['CacheDir']) -ForegroundColor Gray
    Write-WinstCacheFileList -Item $Item

    # 本机是否已安装 + 已装版本（仅下载类型没有「安装」这一步）
    Write-Host '    本机安装 : ' -NoNewline -ForegroundColor Gray
    if ([string]$Item['Type'] -eq 'download') {
        Write-Host '不适用（这类软件只下载软件包，不安装到电脑）' -ForegroundColor DarkGray
    } elseif (-not [bool]$Item['Installed']) {
        Write-Host '未安装' -ForegroundColor DarkGray
    } else {
        Write-Host ('已安装 {0}' -f [string]$Item['InstalledVersionText']) -NoNewline -ForegroundColor Gray
        if ([bool]$Item['InstalledDirMissing']) { Write-Host '   [安装目录不存在]' -ForegroundColor Yellow } else { Write-Host '' }
    }

    # 已安装的这个软件能否更新（更新到哪个版本、来自哪个软件源）
    if ([bool]$Item['Installed']) {
        Write-Host '    能否更新 : ' -NoNewline -ForegroundColor Gray
        $installedConclusion = Get-WinstVersionConclusion -Item $Item -Kind 'installed'
        Write-Host ([string]$installedConclusion['Text']) -ForegroundColor ([string]$installedConclusion['Color'])
    }

    # 安装包能否更新（缓存里的版本 vs 软件源里最高可用版本）；仅下载类型叫「软件包」
    $packageLabel = '安装包   : '
    if ([string]$Item['Type'] -eq 'download') { $packageLabel = '软件包   : ' }
    Write-Host ('    ' + $packageLabel) -NoNewline -ForegroundColor Gray
    $packageConclusion = Get-WinstVersionConclusion -Item $Item -Kind 'package'
    Write-Host ([string]$packageConclusion['Text']) -ForegroundColor ([string]$packageConclusion['Color'])

    # 软件源里的版本（全部来源并排）
    if ([string]$Item['SourceText']) {
        Write-Host ('    软件源   : {0}' -f [string]$Item['SourceText']) -ForegroundColor DarkGray
    }
    if ([string]$Item['TypeText']) {
        Write-Host ('    类型     : {0}' -f [string]$Item['TypeText']) -ForegroundColor Gray
    }

    Write-WinstDetailDependencies -Context $Context -Item $Item
}
