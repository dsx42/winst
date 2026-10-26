#Requires -Version 5.1

function Get-ManifestRootDir {
    <#
    .SYNOPSIS
        返回安装包位置下的清单目录：<pkgDir>\manifests。
    .DESCRIPTION
        源列表、清单缓存与元数据都在这里；多机共用同一安装包位置（U 盘 / NAS）时天然共享。
    #>
    param([Parameter(Mandatory = $true)][string]$PkgDir)
    return (Join-WinstPath $PkgDir 'manifests')
}
