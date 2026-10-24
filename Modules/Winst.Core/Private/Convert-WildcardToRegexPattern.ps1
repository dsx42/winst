#Requires -Version 5.1

function Convert-WildcardToRegexPattern {
    <#
    .SYNOPSIS
        把通配写法编译成正则模式（整串匹配）。
    .DESCRIPTION
        * → 任意多字符，? → 单个字符，\ 转义下一个字符（\* 表示字面量星号）；
        其余字符一律 [regex]::Escape，用户不必再为正则元字符转义。
    #>
    param([string]$Wildcard)

    $text = ''
    if ($null -ne $Wildcard) { $text = [string]$Wildcard }

    $sb = New-Object System.Text.StringBuilder
    $null = $sb.Append('^')
    $i = 0
    while ($i -lt $text.Length) {
        $ch = $text[$i]
        if ($ch -eq '\') {
            if ($i + 1 -lt $text.Length) {
                $null = $sb.Append([regex]::Escape([string]$text[$i + 1]))
                $i += 2
                continue
            }
            $null = $sb.Append('\\')
            $i++
            continue
        }
        if ($ch -eq '*') { $null = $sb.Append('.*'); $i++; continue }
        if ($ch -eq '?') { $null = $sb.Append('.'); $i++; continue }
        $null = $sb.Append([regex]::Escape([string]$ch))
        $i++
    }
    $null = $sb.Append('$')
    return $sb.ToString()
}
