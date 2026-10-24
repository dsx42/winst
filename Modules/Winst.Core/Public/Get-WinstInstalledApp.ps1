#Requires -Version 5.1

function Get-WinstInstalledApp {
    <#
    .SYNOPSIS
        按 id 读取台账条目；未命中返回 $null。
    #>
    param(
        [Parameter(Mandatory = $true)][hashtable]$State,
        [string]$Id
    )

    if (-not $Id) { return $null }
    $installed = $State['Installed']
    if ($null -eq $installed) { return $null }
    if ($installed.Contains($Id)) { return $installed[$Id] }
    return $null
}
