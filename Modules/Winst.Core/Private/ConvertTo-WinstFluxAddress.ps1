#Requires -Version 5.1

function ConvertTo-WinstFluxAddress {
    param([string]$Address)

    $uri = $null
    if (-not [uri]::TryCreate($Address, [UriKind]::Absolute, [ref]$uri) -or
        $uri.Scheme -notin @('http','https') -or $uri.UserInfo -or
        $Address -notmatch '^https?://[^/\\?#@]+/?$') { return }

    # 固定 localhost 到字面回环地址，避免 DNS 转发管理令牌。
    $builder = New-Object UriBuilder $uri
    if ($uri.Host -eq 'localhost') { $builder.Host = '127.0.0.1' }
    $ip = $null
    if ([Net.IPAddress]::TryParse($builder.Host.Trim('[',']'), [ref]$ip) -and [Net.IPAddress]::IsLoopback($ip)) {
        return $builder.Uri.GetLeftPart([UriPartial]::Authority)
    }
}
