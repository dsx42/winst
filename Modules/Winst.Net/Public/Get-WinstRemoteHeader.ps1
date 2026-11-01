#Requires -Version 5.1

function Get-WinstRemoteHeader {
    <#
    .SYNOPSIS
        发 HEAD 并读取指定响应头；请求失败、缺少响应头或空值时明确报错。
    #>
    param([hashtable]$Context, [string]$Uri, [string]$Name)

    if (-not $Name -or $Name -notmatch '^[!#$%&''*+.^_`|~0-9A-Za-z-]+$') { throw '响应头名称为空或含非法字符' }
    $probe = Get-WinstRemoteValidators -Context $Context -Uri $Uri
    if (-not $probe.Ok) { throw ('HEAD 请求失败：{0}（{1}）' -f $Uri, $probe.Error) }
    $value = ([string]$probe.Headers[$Name]).Trim()
    if (-not $value) { throw ('HEAD 响应缺少非空响应头 {0}：{1}' -f $Name, $Uri) }
    return $value
}