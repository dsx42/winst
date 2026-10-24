#Requires -Version 5.1

function Test-RegexRuleText {
    <#
    .SYNOPSIS
        判断一条匹配规则是不是显式正则（re: 前缀）。
    #>
    param([string]$Rule)

    if ($null -eq $Rule) { return $false }
    return (([string]$Rule).TrimStart() -match '^(?i)re:')
}
