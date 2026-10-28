#Requires -Version 5.1

function ConvertTo-WinstUninstallSnapshot {
    <#
    .SYNOPSIS
        把清单条目的卸载定义整理成「卸载操作快照」。
    .DESCRIPTION
        安装成功时把这份快照写进 state.json：日后软件源里删掉这个软件、或清单改了卸载方式，
        卸载仍能按安装时记录的操作完整执行。
    .OUTPUTS
        [ordered]@{ method; removeEnv = @(); removePaths = @(); commands = @(); uninstallArgs; nameRule; shortcutName }
    #>
    param($Block, [string]$NameRuleFallback = '')

    $method = ''
    $removeEnv = @()
    $removePaths = @()
    $commands = @()
    $uninstallArgs = ''
    $nameRule = ''
    $shortcutName = ''

    if ($null -ne $Block) {
        $method = (Get-EntryString -Entry $Block -Key 'method').Trim().ToLowerInvariant()
        foreach ($item in @(Get-EntryArray -Entry $Block -Key 'removeEnv')) {
            $name = [string]$item
            if ($name) { $removeEnv += $name }
        }
        foreach ($item in @(Get-EntryArray -Entry $Block -Key 'removePaths')) {
            $text = [string]$item
            if ($text) { $removePaths += $text }
        }
        # 卸载命令：{installDir} / {installRoot} 保持符号，卸载时按本机安装目录展开
        foreach ($item in @(Get-EntryArray -Entry $Block -Key 'commands')) {
            $exeText = (Get-EntryString -Entry $item -Key 'exe').Trim()
            if (-not $exeText) { continue }
            $commandBlock = [ordered]@{
                exe        = $exeText
                args       = (Get-EntryString -Entry $item -Key 'args').Trim()
                timeoutSec = (Get-EntryInt -Entry $item -Key 'timeoutSec' -Default 600)
            }
            if (Get-EntryBool -Entry $item -Key 'requireAdmin') { $commandBlock['requireAdmin'] = $true }
            $commands += $commandBlock
        }
        $uninstallArgs = (Get-EntryString -Entry $Block -Key 'uninstallArgs').Trim()
        # 名称规则支持数组：字符串保持单值，数组按原样透传。
        # 本函数两个方向都用：清单块里字段叫 name，已保存的快照里叫 nameRule。
        # 只读 name 会让「快照 → 快照」的归一化（ConvertTo-WinstInstalledEntry）永远取到空值，
        # 卸载时名称规则随之丢失并被写回磁盘。
        $nameRuleRaw = Get-EntryValue -Entry $Block -Key 'nameRule' -Default $null
        if ($null -eq $nameRuleRaw) { $nameRuleRaw = Get-EntryValue -Entry $Block -Key 'name' -Default $null }
        if ($null -ne $nameRuleRaw) {
            $nameRule = @($nameRuleRaw | ForEach-Object { ([string]$_).Trim() } | Where-Object { $_ })
        }
        $shortcutName = (Get-EntryString -Entry $Block -Key 'shortcutName').Trim()
    }
    if (-not $nameRule -and $NameRuleFallback) { $nameRule = [string]$NameRuleFallback }

    return [ordered]@{
        method        = $method
        removeEnv     = @($removeEnv)
        removePaths   = @($removePaths)
        commands      = @($commands)
        uninstallArgs = $uninstallArgs
        nameRule      = $nameRule
        shortcutName  = $shortcutName
    }
}
