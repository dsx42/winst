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

    # 防御：同一字典不允许同时存在仅大小写不同的键——这种 JSON 在 PS 5.1 / 7 下都无法被
    # ConvertFrom-Json 解析（会整份台账判为损坏）。写入前先移除仅大小写不同的旧键。
    $collisions = @()
    foreach ($key in @($installed.Keys)) {
        $keyText = [string]$key
        if ($keyText -cne $Id -and $keyText -ieq $Id) { $collisions += $keyText }
    }
    foreach ($key in $collisions) { $installed.Remove($key) }

    $installed[$Id] = $Entry
}
