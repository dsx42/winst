#Requires -Version 5.1

function Get-ManifestCachePath {
    <#
    .SYNOPSIS
        返回某来源的清单缓存文件路径：<pkgDir>\manifests\remote\<源名键>.json。
    .DESCRIPTION
        源名含 `/`，按 Get-ManifestFileKey 映射为「用户名__仓库」后作文件名；
        本地清单（local）没有下载缓存——内容就是磁盘上的清单文件本身，故返回空串。
    #>
    param([string]$PkgDir, [string]$Name)
    if ($Name -ieq (Get-WinstLocalManifestName)) { return '' }
    return (Join-Path (Get-ManifestCacheDir -PkgDir $PkgDir) ((Get-ManifestFileKey -Name $Name) + '.json'))
}
