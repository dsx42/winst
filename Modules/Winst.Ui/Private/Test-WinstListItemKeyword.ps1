#Requires -Version 5.1

function Test-WinstListItemKeyword {
    <#
    .SYNOPSIS
        列表项是否命中关键字（Id / DisplayName / Description，不区分大小写）。
    .DESCRIPTION
        匹配范围与 `winst search` 一致（见 6 节）；缺失的字段自动跳过（如已装软件项没有说明）。
    #>
    param($Item, [string]$Keyword)

    if (-not $Keyword -or $null -eq $Item) { return $true }
    foreach ($field in @('Id', 'DisplayName', 'Description')) {
        $text = ''
        try { $text = [string]$Item[$field] } catch { $text = '' }
        if ($text -and $text.IndexOf($Keyword, [StringComparison]::OrdinalIgnoreCase) -ge 0) { return $true }
    }
    return $false
}
