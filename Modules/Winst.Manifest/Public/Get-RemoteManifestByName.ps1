#Requires -Version 5.1

function Get-RemoteManifestByName {
    <#
    .SYNOPSIS
        按名称（不区分大小写）在软件源列表中查找，未命中返回 $null。
    .DESCRIPTION
        只看 sources.json 里的软件源（不含自动识别的本地清单）；需要包含本地清单的查找
        请用 Get-ManifestSourceByName / Get-ManifestSourceList。
    #>
    param(
        [string]$PkgDir,
        [Parameter(Mandatory = $true)]
        [string]$Name
    )

    foreach ($source in @(Get-RemoteManifestList -PkgDir $PkgDir)) {
        if ([string]$source['name'] -ieq $Name) { return $source }
    }
    return $null
}
