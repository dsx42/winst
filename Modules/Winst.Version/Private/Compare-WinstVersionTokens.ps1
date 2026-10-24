#Requires -Version 5.1

function Compare-WinstVersionTokens {
    <#
    .SYNOPSIS
        比较宽松版本号切分出的数字串 / 字母串，缺段由调用方按 0 补齐。
    #>
    param([string]$A, [string]$B)

    if (($A -match '^[0-9]+$') -and ($B -match '^[0-9]+$')) {
        return (Compare-WinstNumericText -A $A -B $B)
    }
    $cmp = [string]::Compare($A, $B, [StringComparison]::OrdinalIgnoreCase)
    if ($cmp -lt 0) { return -1 }
    if ($cmp -gt 0) { return 1 }
    return 0
}
