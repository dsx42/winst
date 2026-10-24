#Requires -Version 5.1

function Write-WinstPlanUninstallStage {
    <#
    .SYNOPSIS
        ⑦ 卸载段。
    #>
    param($Plan, [hashtable]$View)

    $installDir = $View.InstallDir
    $shortcuts = Get-EntryValue -Entry $Plan -Key 'shortcuts' -Default $null
    $uninstall = Get-EntryValue -Entry $Plan -Key 'uninstall' -Default $null
    $uninstallLines = @()
    switch (Get-EntryString -Entry $uninstall -Key 'method') {
        'portable-dir' {
            if ($installDir) { $uninstallLines += ('删除这个文件夹: {0}' -f $installDir) }
            $removeEnv = @(Get-EntryArray -Entry $uninstall -Key 'removeEnv')
            if ($removeEnv.Count -gt 0) { $uninstallLines += ('删除环境变量: ' + ($removeEnv -join '、')) }
            foreach ($pathItem in @(Get-EntryArray -Entry $uninstall -Key 'removePaths')) {
                $uninstallLines += ('从 PATH 里移除: {0}' -f (Expand-PlanPlaceholders -Value ([string]$pathItem) -InstallDir $installDir -InstallRoot $View.InstallRoot))
            }
            if ((Get-EntryBool -Entry $shortcuts -Key 'desktop') -and $View.DesktopLink) {
                $uninstallLines += ('删除桌面快捷方式: {0}' -f $View.DesktopLink)
            }
            if ((Get-EntryBool -Entry $shortcuts -Key 'startMenu') -and $View.StartMenuLink) {
                $uninstallLines += ('删除开始菜单快捷方式: {0}' -f $View.StartMenuLink)
            }
        }
        'registry' {
            $uninstallLines += '自动从系统安装记录里找到卸载程序并运行'
            $uninstallArgs = Get-EntryString -Entry $uninstall -Key 'uninstallArgs'
            if ($uninstallArgs) { $uninstallLines += ('卸载参数: {0}' -f $uninstallArgs) }
        }
        'appx' {
            $uninstallLines += ('从系统的应用包记录里移除（名称规则: {0}）' -f (Get-EntryString -Entry $uninstall -Key 'name'))
        }
        'clean-cache' {
            if ($View.PkgTarget) { $uninstallLines += ('删除已下载的安装包: {0}' -f ($View.PkgTarget + '\')) }
            else { $uninstallLines += '删除已下载的安装包' }
        }
        default { $uninstallLines += '按软件自身的方式卸载' }
    }
    $commandLines = @(Get-WinstPlanUninstallCommandLines -Uninstall $uninstall -InstallDir $installDir -InstallRoot $View.InstallRoot)
    if ($commandLines.Count -gt 0) { $uninstallLines = @($commandLines) + @($uninstallLines) }
    Write-ResolvedStage -Marker '⑦' -Label '卸载' -Lines $uninstallLines
}
