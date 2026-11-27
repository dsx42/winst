#Requires -Version 5.1

function Get-WinstIdFilterSet {
    <#
    .SYNOPSIS
        把 id 列表转成大小写敏感的哈希集合。
    #>
    param([string[]]$Ids)

    $set = New-WinstOrdinalDictionary
    foreach ($id in @($Ids)) {
        $text = [string]$id
        if ($text) { $set[$text] = $true }
    }
    return $set
}
