#Requires -Version 5.1

function Get-WinstHeadCacheKey {
    <#
    .SYNOPSIS
        用同一请求和有序的代理尝试序列生成 HEAD 缓存键。
    #>
    param([string]$RequestKey, [int]$TimeoutSec, [string[]]$ProxyAttempts)

    $proxyKey = foreach ($proxy in $ProxyAttempts) { '{0}:{1}' -f $proxy.Length, $proxy }
    return ('{0}|{1}|{2}' -f $TimeoutSec, ($proxyKey -join ''), $RequestKey)
}
