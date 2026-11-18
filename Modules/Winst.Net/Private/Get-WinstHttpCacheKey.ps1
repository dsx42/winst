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

    $key = '{0}|{1}:{2}' -f $verb, $Uri.Length, $Uri
    if ($Headers -and $Headers.Count -gt 0) {
        foreach ($name in @($Headers.Keys | Sort-Object -CaseSensitive)) {
            $value = [string]$Headers[$name]
            $key += '|{0}:{1}{2}:{3}' -f ([string]$name).Length, $name, $value.Length, $value
        }
    }
    return $key
}
