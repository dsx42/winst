#Requires -Version 5.1

function Write-WinstPlanEnvStage {
    <#
    .SYNOPSIS
        ④ 环境变量与快捷方式段。
    #>
    param($Plan, [hashtable]$View)

    $envLines = @()
    foreach ($pair in @(Get-EntryKeyValuePairs -Entry (Get-EntryValue -Entry $Plan -Key 'env' -Default $null))) {
        $envLines += ('环境变量 {0} = {1}' -f $pair['Key'], (Expand-PlanPlaceholders -Value ([string]$pair['Value']) -InstallDir $View.InstallDir -InstallRoot $View.InstallRoot))
    }
    foreach ($pathItem in @(Get-EntryArray -Entry $Plan -Key 'addToPath')) {
        $envLines += ('PATH 里追加 {0}' -f (Expand-PlanPlaceholders -Value ([string]$pathItem) -InstallDir $View.InstallDir -InstallRoot $View.InstallRoot))
    }
    $shortcuts = Get-EntryValue -Entry $Plan -Key 'shortcuts' -Default $null
    $desktopOn = Get-EntryBool -Entry $shortcuts -Key 'desktop'
    $startMenuOn = Get-EntryBool -Entry $shortcuts -Key 'startMenu'
    if ($desktopOn -and $View.DesktopLink) {
        $envLines += ('在桌面创建快捷方式: {0}' -f $View.DesktopLink)
    }
    if ($startMenuOn -and $View.StartMenuLink) {
        $envLines += ('在开始菜单创建快捷方式: {0}' -f $View.StartMenuLink)
    }
    Write-ResolvedStage -Marker '④' -Label '环境' -Lines $envLines
}
