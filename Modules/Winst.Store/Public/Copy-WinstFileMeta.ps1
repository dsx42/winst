#Requires -Version 5.1

function Copy-WinstFileMeta {
    <#
    .SYNOPSIS
        把索引条目里的记账（fileMeta）复制成可写的记账表。
    .OUTPUTS
        新的记账表（文件名 → 元信息）；来源为空或结构对不上时返回空表。
    #>
    param($FileMeta)

    $table = New-WinstOrdinalDictionary -IgnoreCase
    foreach ($pair in @(Get-WinstEntryPairs -Entry $FileMeta)) {
        $name = [string]$pair[0]
        $item = $pair[1]
        if (-not $name -or $null -eq $item) { continue }
        $table[$name] = New-WinstFileMetaEntry -Item $item
    }
    return $table
}
