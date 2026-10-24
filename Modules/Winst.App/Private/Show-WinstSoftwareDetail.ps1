#Requires -Version 5.1

function Show-WinstSoftwareDetail {
    <#
    .SYNOPSIS
        「软件列表」的详情页：版本信息（各来源）、安装状态与安装位置、下载状态与下载位置、类型与说明。
    #>
    param(
        [Parameter(Mandatory = $true)][hashtable]$Context,
        [Parameter(Mandatory = $true)]$Item
    )

    Write-WinstDetailHeader -Item $Item
    if ([string]$Item['SourceText']) {
        Write-Host ('    软件源   : {0}' -f [string]$Item['SourceText']) -ForegroundColor Gray
    }
    if ([string]$Item['TypeText']) {
        Write-Host ('    类型     : {0}' -f [string]$Item['TypeText']) -ForegroundColor Gray
    }

    Write-WinstDetailDependencies -Context $Context -Item $Item

    # 安装状态 + 安装位置（仅下载类型的软件只下载、不安装，这里直接说明不适用）
    Write-Host '    安装状态 : ' -NoNewline -ForegroundColor Gray
    if ([string]$Item['Type'] -eq 'download') {
        Write-Host '不适用（这类软件只下载软件包，不安装到电脑）' -ForegroundColor DarkGray
    } elseif (-not [bool]$Item['Installed']) {
        Write-Host '未安装' -ForegroundColor DarkGray
    } else {
        Write-Host ('已安装 {0}' -f [string]$Item['InstalledVersionText']) -NoNewline -ForegroundColor Gray
        $installedConclusion = Get-WinstVersionConclusion -Item $Item -Kind 'installed'
        Write-Host ('    {0}' -f [string]$installedConclusion['Text']) -NoNewline -ForegroundColor ([string]$installedConclusion['Color'])
        if ([bool]$Item['InstalledDirMissing']) { Write-Host '   [安装目录不存在]' -NoNewline -ForegroundColor Yellow }
        Write-Host ''
        $installDir = Get-EntryString -Entry $Item['Ledger'] -Key 'installDir'
        if (-not $installDir) { $installDir = '（未记录）' }
        Write-Host ('    安装位置 : {0}' -f $installDir) -ForegroundColor Gray
    }

    # 已下载的安装包 + 存放位置（含文件名）
    Write-Host '    已下载包 : ' -NoNewline -ForegroundColor Gray
    if (-not [bool]$Item['CacheHas']) {
        if ([string]$Item['Type'] -eq 'download') {
            Write-Host '未下载（下载软件包后会保存到安装包位置）' -ForegroundColor DarkGray
        } else {
            Write-Host '未下载（安装 / 更新时会自动下载）' -ForegroundColor DarkGray
        }
    } else {
        Write-Host ('{0} · {1}（{2} 个文件）' -f [string]$Item['CacheVersionText'], [string]$Item['CacheSizeText'], [int]$Item['CacheFileCount']) -NoNewline -ForegroundColor Gray
        $packageConclusion = Get-WinstVersionConclusion -Item $Item -Kind 'package'
        $packageLabel = '安装包: '
        if ([string]$Item['Type'] -eq 'download') { $packageLabel = '软件包: ' }
        Write-Host ('    {0}{1}' -f $packageLabel, [string]$packageConclusion['Text']) -NoNewline -ForegroundColor ([string]$packageConclusion['Color'])
        Write-Host ''
        Write-Host ('    存放位置 : {0}' -f [string]$Item['CacheDir']) -ForegroundColor Gray
        Write-WinstCacheFileList -Item $Item
    }

    if ([string]$Item['Description']) {
        Write-Host ('    说明     : {0}' -f [string]$Item['Description']) -ForegroundColor DarkGray
    }
}
