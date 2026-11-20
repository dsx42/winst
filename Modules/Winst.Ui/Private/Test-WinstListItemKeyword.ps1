#Requires -Version 5.1

function Test-WinstListItemKeyword {
    <#
    .SYNOPSIS
        列表项是否命中关键字（Id / DisplayName / Description，不区分大小写）。
    .DESCRIPTION
        匹配范围与 `winst search` 一致；缺失的字段自动跳过（如已装软件项没有说明）。
    #>
    param($Item, [string]$Keyword, [string]$NameField = 'DisplayName')

    if (-not $Keyword -or $null -eq $Item) { return $true }
    foreach ($field in @('Id', $NameField, 'Description')) {
        try { $text = [string]$Item[$field] } catch { $text = '' }
        if ($text -and $text.IndexOf($Keyword, [StringComparison]::OrdinalIgnoreCase) -ge 0) { return $true }
    }
    return $false
}
