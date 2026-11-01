#Requires -Version 5.1

function Save-WinstCacheIndex {
    <#
    .SYNOPSIS
        缓存索引内容变化时原子写入（UTF-8 无 BOM）；内容相同则保留文件与缓存。
    #>
    param(
        [Parameter(Mandatory = $true)][string]$PkgDir,
        [Parameter(Mandatory = $true)]$Index
    )

    Assert-WinstDistinctIds -Ids @($Index.Keys)
    $null = Write-WinstJsonFileIfChanged -Path (Get-WinstCacheIndexPath -PkgDir $PkgDir) -InputObject $Index -Depth 8
}
