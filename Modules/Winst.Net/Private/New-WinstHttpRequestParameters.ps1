#Requires -Version 5.1

function New-WinstHttpRequestParameters {
    <#
    .SYNOPSIS
        构造单次 HTTP 请求参数；没有显式代理时继承系统代理。
    #>
    param([string]$Uri, [string]$Method = 'Get', [int]$TimeoutSec = 30,
        [hashtable]$Headers = $null, [string]$Proxy = '', [string]$OutFile = '')

    $parameters = @{ Uri = $Uri; UseBasicParsing = $true; TimeoutSec = $TimeoutSec }
    if ($Method -and $Method -ine 'Get') { $parameters['Method'] = $Method }
    if ($Headers -and $Headers.Count -gt 0) { $parameters['Headers'] = $Headers }
    if ($Proxy) { $parameters['Proxy'] = $Proxy }
    if ($OutFile) { $parameters['OutFile'] = $OutFile }
    return $parameters
}
