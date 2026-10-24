#Requires -Version 5.1

function Add-WinstPlanUninstallCommands {
    <#
    .SYNOPSIS
        ⑦′ 把 uninstall.commands 展开成解析锁里的卸载命令段（原地写入传入的卸载块）。
    #>
    param($Uninstall, $Entry, [string]$Version)

    $uninstallCommands = @()
    $uninstallSpec = Get-EntryValue -Entry $Entry -Key 'uninstall' -Default $null
    foreach ($item in @(Get-EntryArray -Entry $uninstallSpec -Key 'commands')) {
        $exeText = Expand-VersionPlaceholder -Text (Get-EntryString -Entry $item -Key 'exe') -Version $Version
        if (-not $exeText) { continue }
        $commandBlock = [ordered]@{
            exe        = $exeText
            args       = Expand-VersionPlaceholder -Text (Get-EntryString -Entry $item -Key 'args') -Version $Version
            timeoutSec = (Get-EntryInt -Entry $item -Key 'timeoutSec' -Default 600)
        }
        if (Get-EntryBool -Entry $item -Key 'requireAdmin') { $commandBlock['requireAdmin'] = $true }
        $uninstallCommands += $commandBlock
    }
    if ($uninstallCommands.Count -gt 0) { $Uninstall['commands'] = @($uninstallCommands) }
}
