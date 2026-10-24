#Requires -Version 5.1

function Get-WinstListsDir {
    <#
    .SYNOPSIS
        清单文件目录：<数据根>\lists\。
    #>
    param([Parameter(Mandatory = $true)][hashtable]$Context)

    return (Join-Path $Context.DataRoot 'lists')
}
