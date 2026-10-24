#Requires -Version 5.1

function Get-WinstCacheIndexPath {
    <#
    .SYNOPSIS
        缓存索引文件路径：<pkgDir>\winst.json。
    #>
    param([Parameter(Mandatory = $true)][string]$PkgDir)
    return (Join-Path $PkgDir 'winst.json')
}
