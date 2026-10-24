#Requires -Version 5.1

function Get-WinstHttpCacheKey {
    <#
    .SYNOPSIS
        构造进程内 HTTP 响应缓存的键（方法 + URL + 请求头签名）。
    #>
    param(
        [string]$Uri,
        [hashtable]$Headers,
        [string]$Method = 'Get'
    )

    $verb = 'GET'
    if ($Method) { $verb = ([string]$Method).Trim().ToUpperInvariant() }

    $key = $verb + '|' + [string]$Uri
    if ($Headers -and $Headers.Count -gt 0) {
        foreach ($name in @($Headers.Keys | Sort-Object)) {
            $key += '|' + [string]$name + '=' + [string]$Headers[$name]
        }
    }
    return $key
}
