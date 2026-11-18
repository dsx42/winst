#Requires -Version 5.1

function Get-NormalizedVersionString {
    <#
    .SYNOPSIS
        版本号规范化：去首尾空白与单个 v / V 前缀。
    #>
    param([string]$Value)

    $text = ([string]$Value).Trim()
    if ($text.Length -gt 1 -and $text[0] -in @('v', 'V')) { return $text.Substring(1).Trim() }
    return $text
}
