#Requires -Version 5.1

function New-WinstPortableUninstallBlock {
    <#
    .SYNOPSIS
        ⑦ 卸载（portable-dir）：删目录 + 回收环境变量 / PATH 项 / 快捷方式。
    #>
    param($EnvMap, $PathList, [string]$ShortcutName)

    $envNames = @()
    foreach ($key in @($EnvMap.Keys)) { $envNames += [string]$key }

    $uninstallBlock = [ordered]@{
        method      = 'portable-dir'
        removePaths = @($PathList)
        removeEnv   = $envNames
    }
    if ($ShortcutName) { $uninstallBlock['shortcutName'] = $ShortcutName }
    return $uninstallBlock
}
