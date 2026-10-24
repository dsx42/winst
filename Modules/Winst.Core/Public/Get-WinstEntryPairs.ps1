#Requires -Version 5.1

function Get-WinstEntryPairs {
    <#
    .SYNOPSIS
        把字典（hashtable / ordered）或 PSCustomObject 摊平成「键值对」列表。
    .OUTPUTS
        @( @(键, 值), ... )——需要遍历嵌套结构且两种形态都要认时使用。
    #>
    param($Entry)

    $pairs = New-Object 'System.Collections.Generic.List[object]'
    if ($null -eq $Entry) { return @() }
    if ($Entry -is [System.Collections.IDictionary]) {
        foreach ($key in @($Entry.Keys)) { $pairs.Add(@([string]$key, $Entry[$key])) }
        return $pairs.ToArray()
    }
    if ($Entry -is [string]) { return @() }
    foreach ($prop in @($Entry.PSObject.Properties)) { $pairs.Add(@([string]$prop.Name, $prop.Value)) }
    return $pairs.ToArray()
}
