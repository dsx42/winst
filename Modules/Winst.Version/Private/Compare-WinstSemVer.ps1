#Requires -Version 5.1

function Compare-WinstSemVer {
    <#
    .SYNOPSIS
        比较两条已解析的严格 SemVer；构建元数据在解析时已忽略。
    #>
    param($A, $B)

    foreach ($key in @('Major', 'Minor', 'Patch')) {
        $cmp = Compare-WinstNumericText -A ([string]$A[$key]) -B ([string]$B[$key])
        if ($cmp -ne 0) { return $cmp }
    }

    $preA = @($A.PreRelease)
    $preB = @($B.PreRelease)
    if ($preA.Count -eq 0 -and $preB.Count -eq 0) { return 0 }
    if ($preA.Count -eq 0) { return 1 }
    if ($preB.Count -eq 0) { return -1 }

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
