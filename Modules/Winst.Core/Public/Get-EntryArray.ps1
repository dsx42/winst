#Requires -Version 5.1

function Get-EntryArray {
    <#
    .SYNOPSIS
        从字典或 PSCustomObject 中安全读取数组字段，缺失 / 为空时返回空数组。
    .DESCRIPTION
        兼容 JSON 中该字段写成单个对象、以及单元素数组被解包为标量的情况。
    #>
    param(
        $Entry,
        [Parameter(Mandatory = $true)]
        [string]$Key
    )

    $value = Get-EntryValue -Entry $Entry -Key $Key -Default $null
    if ($null -eq $value) { return @() }
    return @($value)
}
