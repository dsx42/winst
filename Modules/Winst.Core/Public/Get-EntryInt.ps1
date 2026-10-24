#Requires -Version 5.1

function Get-EntryInt {
    <#
    .SYNOPSIS
        读取整数字段，解析失败时返回默认值。
    #>
    param(
        $Entry,
        [Parameter(Mandatory = $true)]
        [string]$Key,
        [int]$Default = 0
    )

    $value = Get-EntryValue -Entry $Entry -Key $Key -Default $null
    if ($null -eq $value) { return $Default }
    if ($value -is [int] -or $value -is [long]) { return [int]$value }
    $number = 0
    if ([int]::TryParse(([string]$value).Trim(), [ref]$number)) { return $number }
    return $Default
}
