#Requires -Version 5.1

function Test-ConfigValueIsDefault {
    <#
    .SYNOPSIS
        判断配置值是否等于内置默认值（bool / int / string 分别比较）。
    #>
    param(
        $Value,
        $Default
    )

    if ($null -eq $Value) { return $true }
    if ($Default -is [bool]) { return (([bool]$Value) -eq $Default) }
    if ($Default -is [int]) {
        $number = 0
        if ([int]::TryParse(([string]$Value).Trim(), [ref]$number)) { return ($number -eq $Default) }
        return $false
    }
    return (([string]$Value) -eq ([string]$Default))
}
