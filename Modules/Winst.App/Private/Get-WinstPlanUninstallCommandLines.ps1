#Requires -Version 5.1

function Get-WinstPlanUninstallCommandLines {
    <#
    .SYNOPSIS
        生成「先执行卸载命令: …」的行。
    .OUTPUTS
        [string[]]
    #>
    param($Uninstall, [string]$InstallDir, [string]$InstallRoot)

    $commandLines = @()
    foreach ($command in @(Get-EntryArray -Entry $Uninstall -Key 'commands')) {
        $expanded = Expand-WinstPlanCommand -Command $command -InstallDir $InstallDir -InstallRoot $InstallRoot
        if (-not $expanded.Exe) { continue }
        $commandLines += (('先执行卸载命令: {0} {1}' -f $expanded.Exe, $expanded.Arguments).TrimEnd())
    }
    return $commandLines
}
