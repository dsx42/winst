#Requires -Version 5.1

function Remove-WinstSoftwareCachedPackage {
    <#
    .SYNOPSIS
        x) 删除已下载的安装包：先展示将删除的内容，确认后删除。
    #>
    param([hashtable]$Context, $Item)

    $id = [string]$Item['Id']
    $installed = [bool]$Item['Installed']
    $isDownloadType = ([string]$Item['Type'] -eq 'download')

    # 「已下载包」页的条目本身就来自缓存索引，没有 CacheHas 字段 → 缺省视为有缓存，
    # 这样两个页面（软件列表 / 已下载包）能共用同一个删除流程
    $cacheHas = $true
    if ($null -ne $Item['CacheHas']) { $cacheHas = [bool]$Item['CacheHas'] }
    if (-not $cacheHas) {
        if ($isDownloadType) { Write-Host '  这个软件还没有下载过软件包。' -ForegroundColor DarkYellow }
        else { Write-Host '  这个软件还没有下载过安装包。' -ForegroundColor DarkYellow }
        return
    }

    $packageNoun = '安装包'
    if ($isDownloadType) { $packageNoun = '软件包' }
    # 删除前先展示将删除的内容（等同 winst clean <id>）
    Write-Host ''
    Write-Host ('  将要删除「{0}」的已下载{1}：' -f [string]$Item['DisplayName'], $packageNoun) -ForegroundColor Cyan
    Write-Host ('    存放位置: {0}' -f [string]$Item['CacheDir']) -ForegroundColor Gray
    Write-WinstCacheFileList -Item $Item
    Write-Host ('    共 {0} 个文件，{1}' -f [int]$Item['CacheFileCount'], [string]$Item['CacheSizeText']) -ForegroundColor Gray
    if ($installed -and -not $isDownloadType) {
        Write-Host '    提示: 这个软件已经安装到电脑上，删除的只是安装包，程序本身不受影响。' -ForegroundColor DarkGray
    }
    if (-not (Read-WinstConfirm -Prompt '  确认删除？(y/N)' -Default 'n')) {
        Write-Host '  已取消。' -ForegroundColor DarkGray
        return
    }
    $removed = Remove-WinstCachedPackage -Context $Context -Id $id -PackageNoun $packageNoun
    Write-Host ''
    if ($removed.Ok) {
        Write-Host ('  {0}' -f [string]$removed.Message) -ForegroundColor Green
    } else {
        Write-Host ('  失败: {0}' -f [string]$removed.Error) -ForegroundColor Red
    }
}
