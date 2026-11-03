#Requires -Version 5.1

function Compare-WinstVersion {
    <#
    .SYNOPSIS
        版本号语义化比较：返回 -1（A<B）/ 0（相等）/ 1（A>B）。
    .DESCRIPTION
        规范化去除 `v` 前缀与首尾空白；忽略 + 后的构建元数据；核心按「数字串 / 字母串」切分，
        数字段按数值比较、其余按字符串（忽略大小写）比较；段数不同时缺段按 0 补齐
        （`1.0` = `1.0.0`、`1.8.0_504` = `1.8.0.504`）；`-` 后缀的预发布标识整体视为低于同号正式版。
        预发布标识按点分段：数字按数值比较且低于文字，文字区分大小写，前缀相同则较短者低。
        切分让 `8u504` 与 `8u512`、`8u1504` 与 `8u504` 这类「数字 + 字母混合」写法也能按数值比较。
    #>
    param([string]$A, [string]$B)

    $sa = ConvertTo-WinstVersionCore -Value $A
    $sb = ConvertTo-WinstVersionCore -Value $B

    # 严格和宽松写法共用同一套规则，避免相同核心段因另一侧写法而改变比较关系。
    $idx = $sa.IndexOf('+')
    if ($idx -ge 0) { $sa = $sa.Substring(0, $idx) }
    $idx = $sb.IndexOf('+')
    if ($idx -ge 0) { $sb = $sb.Substring(0, $idx) }

    $preA = ''
    $preB = ''
    $idx = $sa.IndexOf('-')
    if ($idx -ge 0) { $preA = $sa.Substring($idx + 1); $sa = $sa.Substring(0, $idx) }
    $idx = $sb.IndexOf('-')
    if ($idx -ge 0) { $preB = $sb.Substring($idx + 1); $sb = $sb.Substring(0, $idx) }

    $partsA = @(Get-WinstVersionTokens -Value $sa)
    $partsB = @(Get-WinstVersionTokens -Value $sb)
    $count = $partsA.Count
    if ($partsB.Count -gt $count) { $count = $partsB.Count }

    for ($i = 0; $i -lt $count; $i++) {
        $pa = '0'
        $pb = '0'
        if ($i -lt $partsA.Count) { $pa = [string]$partsA[$i] }
        if ($i -lt $partsB.Count) { $pb = [string]$partsB[$i] }

        $cmp = Compare-WinstVersionTokens -A $pa -B $pb
        if ($cmp -ne 0) { return $cmp }
    }

    $hasPreA = ($preA.Length -gt 0)
    $hasPreB = ($preB.Length -gt 0)
    if ($hasPreA -and -not $hasPreB) { return -1 }
    if (-not $hasPreA -and $hasPreB) { return 1 }
    if ($hasPreA -and $hasPreB) {
        return (Compare-WinstSemVer -A @{ Major = '0'; Minor = '0'; Patch = '0'; PreRelease = @($preA.Split('.')) } `
            -B @{ Major = '0'; Minor = '0'; Patch = '0'; PreRelease = @($preB.Split('.')) })
    }
    return 0
}
