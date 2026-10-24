#Requires -Version 5.1

function Get-WinstHttpCacheEntry {
    <#
    .SYNOPSIS
        读取进程内 TTL 缓存；未命中 / 已过期返回 $null。
    #>
    param([string]$Key)

    if (-not (Get-WinstState -Name WinstHttpCache)) { return $null }
    if (-not (Get-WinstState -Name WinstHttpCache).ContainsKey($Key)) { return $null }

    $item = (Get-WinstState -Name WinstHttpCache)[$Key]
    $age = ([DateTime]::Now - [DateTime]$item['At']).TotalSeconds
    if ($age -gt (Get-WinstHttpCacheTtlSec)) {
        (Get-WinstState -Name WinstHttpCache).Remove($Key)
        return $null
    }

    if ((Get-WinstState -Name WinstOptions) -and (Get-WinstState -Name WinstOptions).Verbose) {
        Write-Host ('  [verbose] 命中进程内缓存（{0} 秒前）: {1}' -f [int]$age, $Key) -ForegroundColor DarkGray
    }
    return @{
        Content   = $item['Content']
        Links     = $item['Links']
        FinalUri  = $item['FinalUri']
        FromCache = $true
    }
}
