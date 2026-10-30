#Requires -Version 5.1

function Save-WinstCacheIndex {
    <#
    .SYNOPSIS
        原子写入缓存索引（UTF-8 无 BOM）。
    #>
    param(
        [Parameter(Mandatory = $true)][string]$PkgDir,
        [Parameter(Mandatory = $true)]$Index
    )

    Assert-WinstDistinctIds -Ids @($Index.Keys)
    Write-FileAtomic -Path (Get-WinstCacheIndexPath -PkgDir $PkgDir) -Content (ConvertTo-WinstJson -InputObject $Index -Depth 8)
}
