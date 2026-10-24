#Requires -Version 5.1

function Get-WinstRewrittenVersion {
    <#
    .SYNOPSIS
        按 versionRewrite 规则改写版本号写法；没有规则时原样返回。
    .DESCRIPTION
        规则按声明顺序依次应用；替换串沿用 .NET 正则替换语法（`$1` / `${name}` 引用捕获组）。
        单条规则匹配不上就保持原值（幂等）——因此同一组规则照抄到 source / detect 两侧也不会互相干扰。
    #>
    param([string]$Version, $Rules)

    $value = ''
    if ($null -ne $Version) { $value = [string]$Version }
    if (-not $value) { return $value }

    foreach ($rule in @($Rules)) {
        if ($null -eq $rule) { continue }
        $pattern = Get-EntryString -Entry $rule -Key 'pattern'
        if (-not $pattern) { continue }
        $replacement = ''
        $replaceValue = Get-EntryValue -Entry $rule -Key 'replace' -Default ''
        if ($null -ne $replaceValue) { $replacement = [string]$replaceValue }
        try { $value = [regex]::Replace($value, $pattern, $replacement) } catch { }
    }
    return $value
}
