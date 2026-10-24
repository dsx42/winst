#Requires -Version 5.1

function Test-WinstUninstallSnapshotEmpty {
    <#
    .SYNOPSIS
        卸载快照是否为空（没有任何要执行的卸载动作）。
    #>
    param($Snapshot)

    if ($null -eq $Snapshot) { return $true }
    if ([string]$Snapshot['method']) { return $false }
    if ([string]$Snapshot['uninstallArgs']) { return $false }
    if ([string]$Snapshot['nameRule']) { return $false }
    if (@($Snapshot['removeEnv']).Count -gt 0) { return $false }
    if (@($Snapshot['removePaths']).Count -gt 0) { return $false }
    if (@($Snapshot['commands']).Count -gt 0) { return $false }
    return $true
}
