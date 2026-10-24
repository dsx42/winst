#Requires -Version 5.1

function Compare-WinstNumericText {
    <#
    .SYNOPSIS
        比较任意长度的十进制数字串，避免转换整数时溢出。
    #>
    param([string]$A, [string]$B)

    $left = ([string]$A).TrimStart('0')
    $right = ([string]$B).TrimStart('0')
    if (-not $left) { $left = '0' }
    if (-not $right) { $right = '0' }
    if ($left.Length -lt $right.Length) { return -1 }
    if ($left.Length -gt $right.Length) { return 1 }
    $cmp = [string]::CompareOrdinal($left, $right)
    if ($cmp -lt 0) { return -1 }
    if ($cmp -gt 0) { return 1 }
    return 0
}
