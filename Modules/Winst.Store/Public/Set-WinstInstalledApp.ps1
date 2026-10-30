#Requires -Version 5.1

function Set-WinstInstalledApp {
    <#
    .SYNOPSIS
        写入 / 覆盖台账条目（键按 Ordinal 比较）。
    #>
    param(
        [Parameter(Mandatory = $true)][hashtable]$State,
        [Parameter(Mandatory = $true)][string]$Id,
        [Parameter(Mandatory = $true)]$Entry
    )

    if ($null -eq $State['Installed']) { $State['Installed'] = (New-WinstOrdinalDictionary) }
    $installed = $State['Installed']

    Assert-WinstDistinctIds -Ids @(@($installed.Keys) + @($Id))

    $installed[$Id] = $Entry
}
