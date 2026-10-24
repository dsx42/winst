#Requires -Version 5.1

function Write-WinstCacheFileList {
    <#
    .SYNOPSIS
        输出已下载包的文件名清单（一行一个，缩进 6 空格）；空文件名自动跳过。
    .DESCRIPTION
        已下载包详情 / 软件列表详情 / 删除确认三处逐字相同的循环，收敛到这里。
    #>
    param([Parameter(Mandatory = $true)]$Item)

    foreach ($fileName in @($Item['CacheFiles'])) {
        if ([string]$fileName) { Write-Host ('      - {0}' -f [string]$fileName) -ForegroundColor DarkGray }
    }
}
