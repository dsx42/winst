#Requires -Version 5.1

function Get-ManifestSourcesPath {
    <#
    .SYNOPSIS
        返回软件源列表文件路径：<pkgDir>\manifests\sources.json。
    #>
    param([Parameter(Mandatory = $true)][string]$PkgDir)
    return (Join-WinstPath (Get-ManifestRootDir -PkgDir $PkgDir) (Get-WinstManifestSourcesFileName))
}
