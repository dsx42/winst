#Requires -Version 5.1

function Compare-WinstSemVer {
    <#
    .SYNOPSIS
        比较数字核心相同的两个版本的非空预发布标识。
    #>
    param([string[]]$PreA, [string[]]$PreB)

    $count = [Math]::Min($preA.Count, $preB.Count)
    for ($i = 0; $i -lt $count; $i++) {
        $left = [string]$preA[$i]
        $right = [string]$preB[$i]
        $leftNumeric = ($left -match '^[0-9]+$')
        $rightNumeric = ($right -match '^[0-9]+$')
        if ($leftNumeric -and $rightNumeric) {
            $cmp = Compare-WinstNumericText -A $left -B $right
        } elseif ($leftNumeric -and -not $rightNumeric) {
            $cmp = -1
        } elseif (-not $leftNumeric -and $rightNumeric) {
            $cmp = 1
        } else {
            $cmp = [string]::CompareOrdinal($left, $right)
            if ($cmp -lt 0) { $cmp = -1 } elseif ($cmp -gt 0) { $cmp = 1 }
        }
        if ($cmp -ne 0) { return $cmp }
    }
    if ($preA.Count -lt $preB.Count) { return -1 }
    if ($preA.Count -gt $preB.Count) { return 1 }
    return 0
}
