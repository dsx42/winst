#Requires -Version 5.1

function New-WinstHttpRequestParameters {
    <#
    .SYNOPSIS
        构造单次 HTTP 请求参数；没有显式代理时继承系统代理。
    #>
    param([string]$Uri, [string]$Method = 'Get', [int]$TimeoutSec,
        [hashtable]$Headers = $null, [string]$Proxy, [string]$OutFile = '')

    $parameters = @{ Uri = $Uri; UseBasicParsing = $true; TimeoutSec = $TimeoutSec }
    if ($Method -and $Method -ine 'Get') { $parameters['Method'] = $Method }
    if ($Headers -and $Headers.Count -gt 0) { $parameters['Headers'] = $Headers }
    if ($Headers -and $Headers['Cookie']) {
        # 文件请求的 Cookie 只绑定原主机和路径，交给系统处理后续重定向。
        $uriObject = [uri]$Uri
        $session = New-Object Microsoft.PowerShell.Commands.WebRequestSession
        foreach ($pair in ([string]$Headers['Cookie']).Split(';')) {
            $parts = $pair.Trim() -split '=', 2
            if ($parts.Count -ne 2) { throw '浏览器返回了无效的 Cookie' }
            $cookie = New-Object Net.Cookie $parts[0], $parts[1], $uriObject.AbsolutePath
            $cookie.Secure = $uriObject.Scheme -eq 'https'
            $session.Cookies.Add($uriObject, $cookie)
        }
        $parameters['Headers'] = $Headers.Clone()
        $parameters['Headers'].Remove('Cookie')
        $parameters['WebSession'] = $session
    }
    if ($Proxy) { $parameters['Proxy'] = $Proxy }
    if ($OutFile) { $parameters['OutFile'] = $OutFile }
    return $parameters
}
