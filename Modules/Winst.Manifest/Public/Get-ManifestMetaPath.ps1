#Requires -Version 5.1

function Get-ManifestMetaPath {
    <#
    .SYNOPSIS
        返回某来源的 sidecar 元数据文件路径（软件清单 / 更新时间）。
    .DESCRIPTION
        远程来源：<pkgDir>\manifests\remote\<源名键>.meta.json；
        本地清单：<pkgDir>\manifests\local.meta.json（按 *.meta.json 排除，不会被当成清单）。
    #>
    param([string]$PkgDir, [string]$Name)

    if ($Name -ieq (Get-WinstLocalManifestName)) {
        return (Join-WinstPath (Get-ManifestRootDir -PkgDir $PkgDir) ((Get-WinstLocalManifestName) + '.meta.json'))
    }
    return (Join-WinstPath (Get-ManifestCacheDir -PkgDir $PkgDir) ((Get-ManifestFileKey -Name $Name) + '.meta.json'))
}
