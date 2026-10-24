#Requires -Version 5.1

function Get-WinstUninstallSnapshotFromPlan {
    <#
    .SYNOPSIS
        取某个软件清单条目对应的卸载操作快照（nameRule 缺省时回退到 detect.name）。
    #>
    param($Plan)

    if ($null -eq $Plan) { return (ConvertTo-WinstUninstallSnapshot -Block $null) }
    $block = Get-EntryValue -Entry $Plan -Key 'uninstall' -Default $null
    $detect = Get-EntryValue -Entry $Plan -Key 'detect' -Default $null
    return (ConvertTo-WinstUninstallSnapshot -Block $block -NameRuleFallback (Get-EntryString -Entry $detect -Key 'name'))
}
