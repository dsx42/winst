#Requires -Version 5.1

function Get-DistinctValues {
    <#
    .SYNOPSIS
        去重（忽略大小写）并去空白，保持首次出现顺序。
    #>
    param([string[]]$Values)

    $seen = New-Object 'System.Collections.Hashtable' ([StringComparer]::OrdinalIgnoreCase)
    $result = @()
    foreach ($item in @($Values)) {
        if ($null -eq $item) { continue }
        $text = ([string]$item).Trim()
        if (-not $text) { continue }
        if ($seen.ContainsKey($text)) { continue }
        $seen[$text] = $true
        $result += $text
    }
    return $result
}
