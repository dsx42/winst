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
        $exeText = [Environment]::ExpandEnvironmentVariables((Expand-PlanPlaceholders -Value (Get-EntryString -Entry $command -Key 'exe') -InstallDir $InstallDir -InstallRoot $InstallRoot))
        $argsText = [Environment]::ExpandEnvironmentVariables((Expand-PlanPlaceholders -Value (Get-EntryString -Entry $command -Key 'args') -InstallDir $InstallDir -InstallRoot $InstallRoot))
        $commandLines += (('先执行卸载命令: {0} {1}' -f $exeText, $argsText).TrimEnd())
    }
    return $commandLines
}
