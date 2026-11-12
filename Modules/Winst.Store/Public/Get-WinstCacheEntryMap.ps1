#Requires -Version 5.1

function Get-WinstCacheEntryMap {
    <#
    .SYNOPSIS
        为缓存索引建立按精确 id 查询的视图，不合并仅大小写不同的身份。
    #>
    param($CacheIndex)

    $map = New-WinstOrdinalDictionary
    if ($CacheIndex) {
        foreach ($key in @($CacheIndex.Keys)) {
            $id = [string]$key
            if ($id -and -not $map.Contains($id)) { $map[$id] = $CacheIndex[$key] }
        }
    }
    return $map
}
