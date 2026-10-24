#Requires -Version 5.1

function Get-EntryKeyValuePairs {
    <#
    .SYNOPSIS
        把字典 / PSCustomObject 展开为 @( @{ Key; Value } ) 列表（供 env 渲染）。
    #>
    param($Entry)

    $pairs = @()
    if ($null -eq $Entry) { return $pairs }

    if ($Entry -is [System.Collections.IDictionary]) {
        foreach ($key in @($Entry.Keys)) {
            $pairs += [ordered]@{ Key = [string]$key; Value = [string]$Entry[$key] }
        }
        return $pairs
    }

    foreach ($prop in @($Entry.PSObject.Properties)) {
        $pairs += [ordered]@{ Key = [string]$prop.Name; Value = [string]$prop.Value }
    }
    return $pairs
}
