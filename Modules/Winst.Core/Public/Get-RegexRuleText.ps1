#Requires -Version 5.1

function Get-RegexRuleText {
    <#
    .SYNOPSIS
        去掉 re: 前缀，返回正则本体（前缀后的首个空白会被忽略）。
    #>
    param([string]$Rule)

    return $Rule.Substring($Rule.IndexOf(':') + 1).TrimStart()
}
