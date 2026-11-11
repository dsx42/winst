#Requires -Version 5.1

function Test-CompiledMatchRule {
    <#
    .SYNOPSIS
        用已编译的匹配规则判断文本是否命中（整串匹配；空规则视为不命中）。
    #>
    param($Rule, [string]$Text)

    if ($null -eq $Rule -or -not $Rule.Ok) { return $false }
    if ($null -eq $Text -or -not ([string]$Text)) { return $false }
    try {
        return [regex]::IsMatch([string]$Text, [string]$Rule.Pattern, [Text.RegularExpressions.RegexOptions]::None, [timespan]::FromSeconds(1))
    } catch {
        throw ('匹配规则执行失败或超时（{0}，{1}）：{2}' -f $Rule.Kind, $Rule.Source, $_.Exception.Message)
    }
}
