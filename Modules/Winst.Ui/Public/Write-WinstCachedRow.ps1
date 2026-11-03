#Requires -Version 5.1

function Write-WinstCachedRow {
    <#
    .SYNOPSIS
        输出已准备好的缓存列表行，供菜单和 CLI 共用。
    #>
    param($Item, [int]$Number)

    # —— 第 1 行：名称（id）+ 已下载包版本 / 大小 / 文件数 ——
    Write-WinstListItemIdentity -Item $item -Number $number
    Write-Host ('    已下载包 {0}' -f [string]$item['CacheVersionText']) -NoNewline -ForegroundColor Gray
    Write-Host (' · {0} · {1} 个文件' -f [string]$item['CacheSizeText'], [int]$item['CacheFileCount']) -ForegroundColor Gray

    # —— 第 2 行：本机是否已安装 + 已装能否升级 ——
    Write-WinstInstalledStateLine -Item $item -Label '本机安装: '

    # —— 第 3 行：安装包能否更新 + 软件源里的版本（全部来源并排） ——
    $packageLabel = '安装包:   '
    if ([string]$item['Type'] -eq 'download') { $packageLabel = '软件包:   ' }
    Write-Host ('     ' + $packageLabel) -NoNewline -ForegroundColor Gray
    $packageConclusion = Get-WinstVersionConclusion -Item $item -Kind 'package'
    Write-Host ([string]$packageConclusion['Text']) -NoNewline -ForegroundColor ([string]$packageConclusion['Color'])
    if ([string]$item['SourceText']) {
        Write-Host ('    软件源: {0}' -f [string]$item['SourceText']) -NoNewline -ForegroundColor DarkGray
    }
    if ([string]$item['Type'] -eq 'download') { Write-Host '    [只下载软件包，不安装到电脑]' -NoNewline -ForegroundColor DarkGray }
    Write-Host ''
    Write-WinstCompanionVersions -Item $Item
}
