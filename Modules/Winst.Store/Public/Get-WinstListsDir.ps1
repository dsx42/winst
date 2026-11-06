#Requires -Version 5.1

function Get-WinstListsDir {
    <#
    .SYNOPSIS
        清单文件目录：优先使用脚本同目录下已有的 lists\，否则使用 <数据根>\lists\。
    #>
    param([Parameter(Mandatory = $true)][hashtable]$Context)

    $scriptDir = [string](Get-WinstState -Name WinstScriptDir)
    if ($scriptDir) {
        $scriptLists = Join-WinstPath $scriptDir 'lists'
        if (Test-Path -LiteralPath $scriptLists -PathType Container) { return $scriptLists }
    }
    return (Join-WinstPath $Context.DataRoot 'lists')
}
