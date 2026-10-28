#Requires -Version 5.1

function Test-RemoteFileExists {
    <#
    .SYNOPSIS
        探测远程文件是否存在（HEAD 请求）。
    .OUTPUTS
        $true（存在）/ $false（确认不存在：404 / 410，或重定向后最终地址不包含 FinalUriMustContain）/
        $null（无法判断：网络失败、服务器不支持 HEAD，或被站点的人机校验拦下）
    .DESCRIPTION
        实际探测由 Get-WinstRemoteFileProbe 完成（它额外区分「被人机校验拦下」这一态）；这里只把它折成
        「有 / 没有 / 不知道」三态，供只关心存在性的调用方（版本列表、配套文件）使用。
    #>
    param(
        [Parameter(Mandatory = $true)]
        [string]$Uri,
        [hashtable]$Context,
        [int]$TimeoutSec = 20,
        [hashtable]$Headers = $null,
        [string]$FinalUriMustContain = ''
    )

    $probe = Get-WinstRemoteFileProbe -Uri $Uri -Context $Context -TimeoutSec $TimeoutSec -Headers $Headers `
        -FinalUriMustContain $FinalUriMustContain
    if ($probe.State -eq 'ok') { return $true }
    if ($probe.State -eq 'missing') { return $false }
    return $null
}
