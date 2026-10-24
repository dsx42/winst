#Requires -Version 5.1

function Get-WinstCacheEntryMap {
    <#
    .SYNOPSIS
        为缓存索引建立不区分大小写的 id 视图，兼容目录名与索引键仅大小写不同。
    #>
    param($CacheIndex)

    $map = New-Object 'System.Collections.Hashtable' ([StringComparer]::OrdinalIgnoreCase)
    if ($CacheIndex) {
        foreach ($key in @($CacheIndex.Keys)) {
            $id = [string]$key
            if ($id -and -not $map.ContainsKey($id)) { $map[$id] = $CacheIndex[$key] }
        }
    }
    return $map
}
