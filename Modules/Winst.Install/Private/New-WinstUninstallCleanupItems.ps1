#Requires -Version 5.1

function New-WinstUninstallCleanupItems {
    <#
    .SYNOPSIS
        把要回收的系统项整理成确认页的一行行文字（环境变量 / PATH 项 / 快捷方式）。
    .OUTPUTS
        [array]
    #>
    param($Env, $PathItems, $Shortcuts)

    $cleanupItems = @()
    foreach ($one in @($Env)) {
        $scopeText = '用户级'
        if ([string]$one['scope'] -eq 'Machine') { $scopeText = '系统级' }
        $cleanupItems += [ordered]@{ Kind = '环境变量'; Text = ('{0}（{1}）' -f [string]$one['name'], $scopeText) }
    }
    foreach ($one in @($PathItems)) {
        $scopeText = '用户级'
        if ([string]$one['scope'] -eq 'Machine') { $scopeText = '系统级' }
        $cleanupItems += [ordered]@{ Kind = 'PATH 项'; Text = ('{0}（{1}）' -f [string]$one['path'], $scopeText) }
    }
    foreach ($link in @($Shortcuts)) {
        $cleanupItems += [ordered]@{ Kind = '快捷方式'; Text = [string]$link }
    }
    return $cleanupItems
}
