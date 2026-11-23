#Requires -Version 5.1

function Resolve-WinstBundleMissingPackages {
    <#
    .SYNOPSIS
        在复制之前按本地清单和摘要核对套件所需的文件。
    #>
    param([hashtable]$Context, $Plan, $Lookup)

    $missing = 0
    foreach ($item in @($Plan)) {
        Update-WinstBundleItemCache -Context $Context -Item $item -Lookup $Lookup
        if ([bool]$item['CacheHas']) { continue }
        $missing++
        Write-Host ('  缺包 {0}: {1}' -f $item['Id'], $item['CacheError']) -ForegroundColor DarkYellow
    }
    return $missing
}
