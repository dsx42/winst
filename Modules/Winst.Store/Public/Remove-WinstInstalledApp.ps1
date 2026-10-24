#Requires -Version 5.1

function Remove-WinstInstalledApp {
    <#
    .SYNOPSIS
        从台账移除条目；不存在返回 $false。
    #>
    param(
        [Parameter(Mandatory = $true)][hashtable]$State,
        [Parameter(Mandatory = $true)][string]$Id
    )

    $installed = $State['Installed']
    if ($null -eq $installed -or -not $installed.Contains($Id)) { return $false }
    $installed.Remove($Id)
    return $true
}
