#Requires -Version 5.1

function Assert-WinstHttpUrl {
    <#
    .SYNOPSIS
        拒绝 HTTP 来源中的相对地址及其它协议，校验不发起请求。
    #>
    param([string]$Url, [string]$Label = '下载地址')

    $parsed = $null
    if (-not [Uri]::TryCreate($Url, [UriKind]::Absolute, [ref]$parsed) -or @('http', 'https') -notcontains $parsed.Scheme) {
        throw ('{0}必须是绝对 HTTP(S) 地址：{1}' -f $Label, $Url)
    }
}
