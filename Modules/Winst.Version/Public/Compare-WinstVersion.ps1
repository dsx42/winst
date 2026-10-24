#Requires -Version 5.1

function Compare-WinstVersion {
    <#
    .SYNOPSIS
        版本号语义化比较：返回 -1（A<B）/ 0（相等）/ 1（A>B）。
    .DESCRIPTION
        规范化去除 `v` 前缀与首尾空白；把版本号按「数字串 / 字母串」切分成段（`.` `_` `+` 等分隔符忽略），
        数字段按数值比较、其余按字符串（忽略大小写）比较；段数不同时缺段按 0 补齐
        （`1.0` = `1.0.0`、`1.8.0_504` = `1.8.0.504`）；`-` 后缀的预发布标识整体视为低于同号正式版。
        非严格 SemVer 的核心与预发布后缀都按上述规则逐段比较，后缀缺段同样按 0 补齐。
        切分让 `8u504` 与 `8u512`、`8u1504` 与 `8u504` 这类「数字 + 字母混合」写法也能按数值比较。
    #>
    param([string]$A, [string]$B)

    $sa = ConvertTo-WinstVersionCore -Value $A
    $sb = ConvertTo-WinstVersionCore -Value $B

    # 两侧都是严格 SemVer 时按 2.0.0 规则比较：预发布标识逐段比较，构建元数据不参与优先级。
    $semA = ConvertTo-WinstSemVer -Value $sa
    $semB = ConvertTo-WinstSemVer -Value $sb
    if ($semA.Valid -and $semB.Valid) { return (Compare-WinstSemVer -A $semA -B $semB) }

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
        $partsA = @(Get-WinstVersionTokens -Value $preA)
        $partsB = @(Get-WinstVersionTokens -Value $preB)
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
    }
    return 0
}
