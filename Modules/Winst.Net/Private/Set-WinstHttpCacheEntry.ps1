#Requires -Version 5.1

function Set-WinstHttpCacheEntry {
    <#
    .SYNOPSIS
        写入进程内 TTL 缓存（仅内存，进程退出即失效，不做磁盘缓存）。
    #>
    param(
        [string]$Key,
        [string]$Content,
        $Links,
        [string]$FinalUri = ''
    )

    if (-not (Get-WinstState -Name WinstHttpCache)) {
        $null = Set-WinstState -Name WinstHttpCache -Value (New-Object 'System.Collections.Hashtable' ([StringComparer]::Ordinal))
    }
    (Get-WinstState -Name WinstHttpCache)[$Key] = @{
        At       = [DateTime]::Now
        Content  = $Content
        Links    = $Links
        FinalUri = $FinalUri
    }
}
