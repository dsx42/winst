#Requires -Version 5.1

function Get-WinstHttpCacheEntry {
    <#
    .SYNOPSIS
        读取进程内 TTL 缓存；未命中 / 已过期返回 $null。
    #>
    param([string]$Key)

    $cache = Get-WinstState -Name WinstHttpCache
    $item = $cache[$Key]
    if ($null -eq $item) { return $null }
    if (([DateTime]::Now - $item.At).TotalSeconds -gt (Get-WinstHttpCacheTtlSec)) {
        $cache.Remove($Key)
        return $null
    }
    return $item
}
