#Requires -Version 5.1

function ConvertTo-WinstStripTopDirValue {
    <#
    .SYNOPSIS
        把 stripTopDir 的布尔 / 字符串写法归一化；未声明或空字符串时返回调用方指定的缺省值。
    #>
    param($Value, [bool]$Default = $true)

    if ($null -eq $Value) { return $Default }
    if ($Value -is [bool]) { return [bool]$Value }
    $text = ([string]$Value).Trim()
    if (-not $text) { return $Default }
    if ($text -ieq 'true') { return $true }
    if ($text -ieq 'false') { return $false }
    return $text
}
