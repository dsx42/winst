#Requires -Version 5.1

function Get-NormalizedVersionString {
    <#
    .SYNOPSIS
        版本号规范化：去首尾空白与单个 v / V 前缀。
    #>
    param([string]$Value)

    return (ConvertTo-WinstVersionCore -Value $Value)
}
