#Requires -Version 5.1

function Test-CompiledMatchRule {
    <#
    .SYNOPSIS
        用已编译的匹配规则判断文本是否命中（整串匹配；空规则视为不命中）。
    #>
    param($Rule, [string]$Text)

    if ($null -eq $Rule -or -not $Rule.Ok) { return $false }
    if ($null -eq $Text -or -not ([string]$Text)) { return $false }
    return [regex]::IsMatch([string]$Text, [string]$Rule.Pattern)
}
