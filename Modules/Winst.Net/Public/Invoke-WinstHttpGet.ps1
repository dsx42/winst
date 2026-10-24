#Requires -Version 5.1

function Invoke-WinstHttpGet {
    <#
    .SYNOPSIS
        HTTP GET 并返回响应文本（Invoke-WinstHttpRequest 的文本便捷封装）。
    #>
    param(
        [Parameter(Mandatory = $true)]
        [string]$Uri,
        [hashtable]$Context,
        [int]$TimeoutSec = 30,
        [hashtable]$Headers = $null,
        [switch]$NoCache
    )

    $result = Invoke-WinstHttpRequest -Uri $Uri -Context $Context -TimeoutSec $TimeoutSec -Headers $Headers -NoCache:$NoCache
    return $result.Content
}
