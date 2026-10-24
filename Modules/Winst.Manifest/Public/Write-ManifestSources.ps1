#Requires -Version 5.1

function Write-ManifestSources {
    <#
    .SYNOPSIS
        原子写入共享的软件源列表（UTF-8 无 BOM）。
    .DESCRIPTION
        结构：{ "_version": 1, "sources": [ { repo, url } ] }。
    #>
    param(
        [Parameter(Mandatory = $true)][string]$PkgDir,
        $Sources
    )

    $items = New-Object 'System.Collections.Generic.List[object]'
    foreach ($source in @($Sources)) {
        $repo = Get-EntryString -Entry $source -Key 'repo'
        if (-not $repo) { $repo = Get-EntryString -Entry $source -Key 'name' }
        if (-not $repo) { continue }
        $items.Add([ordered]@{ repo = $repo; url = (Get-EntryString -Entry $source -Key 'url') })
    }

    $obj = [ordered]@{ _version = 1; sources = @($items.ToArray()) }
    Write-FileAtomic -Path (Get-ManifestSourcesPath -PkgDir $PkgDir) -Content (ConvertTo-WinstJson -InputObject $obj -Depth 6)

    # 软件源增删 → 软件清单汇总缓存（搜索 / 依赖索引）必须重建
    Reset-WinstCatalogCache
}
