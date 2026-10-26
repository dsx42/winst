#Requires -Version 5.1

function Get-ManifestCacheDir {
    <#
    .SYNOPSIS
        返回清单缓存目录：<pkgDir>\manifests\remote。
    #>
    param([Parameter(Mandatory = $true)][string]$PkgDir)
    return (Join-WinstPath (Get-ManifestRootDir -PkgDir $PkgDir) 'remote')
}
