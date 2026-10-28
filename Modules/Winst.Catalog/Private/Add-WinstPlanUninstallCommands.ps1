#Requires -Version 5.1

function Add-WinstPlanUninstallCommands {
    <#
    .SYNOPSIS
        ⑦′ 把 uninstall.commands 展开成解析锁里的卸载命令段（原地写入传入的卸载块）。
    #>
    param($Uninstall, $Entry, [string]$Version)

    $uninstallSpec = Get-EntryValue -Entry $Entry -Key 'uninstall' -Default $null
    $uninstallCommands = @(New-WinstPlanCommandList -Commands (Get-EntryArray -Entry $uninstallSpec -Key 'commands') -Version $Version)
    if ($uninstallCommands.Count -gt 0) { $Uninstall['commands'] = @($uninstallCommands) }
}
