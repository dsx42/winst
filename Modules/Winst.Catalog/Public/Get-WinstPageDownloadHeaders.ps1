#Requires -Version 5.1

function Get-WinstPageDownloadHeaders {
    <#
    .SYNOPSIS
        返回本次取址时保存的文件请求头。需要浏览器而会话凭据缺失时返回空值，供下载方重新取址。
    #>
    param([hashtable]$Context, $Plan, [string]$SourceName, [string]$Id, [int]$Index, [string]$Url)

    $download = Get-EntryValue $Plan 'download'
    if ((Get-EntryString $download 'kind') -ne 'page') { return @{} }
    $browser = Get-EntryValue $download 'browser'
    if ($null -ne $browser -and -not $browser) { return @{} }

    $key = $Context.PkgDir, $SourceName, $Id -join [char]0
    $records = (Get-WinstState -Name WinstPageDownloadHeaders)[$key]
    if ($null -ne $records -and $Index -ge 0 -and $Index -lt $records.Count -and $records[$Index].Url -ceq $Url) {
        return $records[$Index].Headers
    }
    return $null
}