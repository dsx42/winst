#Requires -Version 5.1

function Write-WinstCachedRow {
    <#
    .SYNOPSIS
        输出已准备好的缓存列表行，供菜单和 CLI 共用。
    #>
    param($Item, [int]$Number)

    # 正式包与下载暂存在同一行，进入详情后才检查任务。
    Write-WinstListItemIdentity -Item $item -Number $number
    if ([int]$Item['CacheFileCount'] -gt 0) {
        Write-Host ('    {0} · {1} · {2} 个文件' -f $Item['CacheVersionText'], $Item['CacheSizeText'], $Item['CacheFileCount']) -NoNewline -ForegroundColor Gray
        if ($Item['HasPackageUpdate']) { Write-Host '    可更新' -NoNewline -ForegroundColor Green }
    }
    if ($Item['HasDownloadStage']) { Write-Host '    下载中断' -NoNewline -ForegroundColor Yellow }
    Write-Host ''
}
