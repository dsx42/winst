#Requires -Version 5.1

function Set-WinstHttpCacheEntry {
    <#
    .SYNOPSIS
        写入进程内 TTL 缓存（仅内存，进程退出即失效，不做磁盘缓存）。
    #>
    param([string]$Key, [hashtable]$Entry)

    $cache = Get-WinstState -Name WinstHttpCache
    $now = [DateTime]::Now
    $sweepAt = Get-WinstState -Name WinstHttpCacheSweepAt
    if ($now -ge $sweepAt) {
        $ttl = Get-WinstHttpCacheTtlSec
        $cutoff = $now.AddSeconds(-$ttl)
        foreach ($existing in @($cache.Keys)) {
            if ($cache[$existing]['At'] -lt $cutoff) { $cache.Remove($existing) }
        }
        $null = Set-WinstState -Name WinstHttpCacheSweepAt -Value $now.AddSeconds($ttl)
    }
    if (-not $Entry.ContainsKey('At')) { $Entry.At = $now }
    $cache[$Key] = $Entry
}
