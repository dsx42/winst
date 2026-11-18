#Requires -Version 5.1

function Get-EntryKeyValuePairs {
    <#
    .SYNOPSIS
        把字典 / PSCustomObject 展开为 @( @{ Key; Value } ) 列表（供 env 渲染）。
    #>
    param($Entry)

    foreach ($pair in @(Get-WinstEntryPairs -Entry $Entry)) {
        [ordered]@{ Key = [string]$pair[0]; Value = [string]$pair[1] }
    }
}
