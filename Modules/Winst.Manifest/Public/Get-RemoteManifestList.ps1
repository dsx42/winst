#Requires -Version 5.1

function Get-RemoteManifestList {
    <#
    .SYNOPSIS
        读取软件源列表（安装包位置下的 sources.json），归一化为有序条目数组。
    .OUTPUTS
        [object[]]：@{ name; repo; url }
    #>
    param([string]$PkgDir)

    return @(Read-ManifestSources -PkgDir $PkgDir)
}
