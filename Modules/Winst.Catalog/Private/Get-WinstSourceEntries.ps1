#Requires -Version 5.1

function Get-WinstSourceEntries {
    <#
    .SYNOPSIS
        来源解析使用的正文读取：缺失或空白缓存明确报错，不联网。
    #>
    param(
        [Parameter(Mandatory = $true)][hashtable]$Context,
        [Parameter(Mandatory = $true)]$Source
    )

    $read = Read-WinstSourceManifestBody -Context $Context -Source $Source
    $errorText = [string]$read.Error
    if ($read.Missing) { $errorText = '还没有这个软件源的清单缓存，请先刷新软件源' }
    elseif ($read.Empty) { $errorText = '软件源的清单缓存是空文件，请重新刷新' }
    elseif ($errorText) { $errorText = ('读取软件源的清单正文失败: {0}' -f $errorText) }
    return @{ Entries = @($read.Entries); Error = $errorText }
}
