#Requires -Version 5.1

function Get-WinstDeclaredManifestEntries {
    <#
    .SYNOPSIS
        搜索使用的清单正文读取：缓存缺失或空白时返回空条目，不联网。
    #>
    param(
        [Parameter(Mandatory = $true)][hashtable]$Context,
        [Parameter(Mandatory = $true)]$Source
    )

    $read = Read-WinstSourceManifestBody -Context $Context -Source $Source
    $errorText = [string]$read.Error
    if ($errorText) { $errorText = ('{0}: 清单正文无法读取（{1}）' -f (Get-EntryString -Entry $Source -Key 'name'), $errorText) }
    return @{ Entries = @($read.Entries); Error = $errorText }
}
