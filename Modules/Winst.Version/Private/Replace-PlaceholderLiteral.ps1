#Requires -Version 5.1

function Replace-PlaceholderLiteral {
    <#
    .SYNOPSIS
        把文本里的 {name} 占位符替换为字面值（不做 URL 转义）。
    .DESCRIPTION
        默认按原样插入（通配写法用）；-Escape 时把值做正则转义后再插入（re: 正则写法用，
        这样 {version} 始终代表「这个确切的版本号」，不会被版本号里的点号当成通配符）。
    #>
    param([string]$Text, [string]$Name, [string]$Value, [switch]$Escape)

    if ($null -eq $Text) { return '' }
    $body = [string]$Text
    if (-not $Name) { return $body }

    $token = '{' + $Name + '}'
    if ($body.IndexOf($token, [StringComparison]::OrdinalIgnoreCase) -lt 0) { return $body }

    $replacement = ''
    if ($null -ne $Value) { $replacement = [string]$Value }
    if ($Escape) { $replacement = [regex]::Escape($replacement) }
    $replacement = $replacement.Replace('$', '$$')
    return [regex]::Replace($body, '\{' + $Name + '\}', $replacement, [Text.RegularExpressions.RegexOptions]::IgnoreCase)
}
