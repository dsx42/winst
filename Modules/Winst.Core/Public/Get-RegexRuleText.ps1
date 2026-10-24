#Requires -Version 5.1

function Get-RegexRuleText {
    <#
    .SYNOPSIS
        去掉 re: 前缀，返回正则本体（前缀后的首个空白会被忽略）。
    #>
    param([string]$Rule)

    $text = [string]$Rule
    $idx = $text.IndexOf(':')
    if ($idx -lt 0) { return $text }
    return $text.Substring($idx + 1).TrimStart()
}
