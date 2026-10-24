#Requires -Version 5.1

function Get-EntryValue {
    <#
    .SYNOPSIS
        从字典（hashtable / ordered）或 PSCustomObject 中安全读取原始值（不做字符串化）。
    #>
    param(
        $Entry,
        [Parameter(Mandatory = $true)]
        [string]$Key,
        $Default = $null
    )

    if ($null -eq $Entry) { return $Default }
    if ($Entry -is [System.Collections.IDictionary]) {
        if ($Entry.Contains($Key) -and $null -ne $Entry[$Key]) { return $Entry[$Key] }
        return $Default
    }
    $prop = $Entry.PSObject.Properties[$Key]
    if ($prop -and $null -ne $prop.Value) { return $prop.Value }
    return $Default
}
