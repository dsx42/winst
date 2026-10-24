#Requires -Version 5.1

function ConvertTo-WinstInstalledEntry {
    <#
    .SYNOPSIS
        把台账里的单条安装记录归一化为有序字典，并补齐缺失的可选字段。
    .DESCRIPTION
        appliedEnv / appliedPath 为 [{ name|path, scope }]；字符串数组形式在此
        统一归一化为携带 scope = User 的对象（schemaVersion 2 的迁移规则）。
    #>
    param($Entry)

    $result = [ordered]@{
        version          = (Get-EntryString -Entry $Entry -Key 'version')
        type             = (Get-EntryString -Entry $Entry -Key 'type')
        group            = (Get-EntryString -Entry $Entry -Key 'group')
        installDir       = (Get-EntryString -Entry $Entry -Key 'installDir')
        installedAt      = (Get-EntryString -Entry $Entry -Key 'installedAt')
        updatedAt        = (Get-EntryString -Entry $Entry -Key 'updatedAt')
        manifestOrigin   = (Get-EntryString -Entry $Entry -Key 'manifestOrigin')
        managed          = (Get-EntryString -Entry $Entry -Key 'managed')
        appliedEnv       = @()
        appliedPath      = @()
        appliedShortcuts = @()
        appliedFiles     = @()
        uninstall        = (ConvertTo-WinstUninstallSnapshot -Block $null)
    }
    if (-not $result['managed']) { $result['managed'] = 'winst' }

    # 卸载操作快照（安装时写入；老记录没有这个字段时留空，卸载时回退到软件源里的定义）
    $result['uninstall'] = (ConvertTo-WinstUninstallSnapshot -Block (Get-EntryValue -Entry $Entry -Key 'uninstall' -Default $null))

    foreach ($item in @(Get-EntryArray -Entry $Entry -Key 'appliedEnv')) {
        $name = ''
        $scope = 'User'
        if ($item -is [string]) {
            $name = [string]$item
        } else {
            $name = Get-EntryString -Entry $item -Key 'name'
            $scopeText = Get-EntryString -Entry $item -Key 'scope'
            if ($scopeText) { $scope = $scopeText }
        }
        if (-not $name) { continue }
        if ($scope -ne 'Machine') { $scope = 'User' }
        $result['appliedEnv'] += [ordered]@{ name = $name; scope = $scope }
    }

    foreach ($item in @(Get-EntryArray -Entry $Entry -Key 'appliedPath')) {
        $path = ''
        $scope = 'User'
        if ($item -is [string]) {
            $path = [string]$item
        } else {
            $path = Get-EntryString -Entry $item -Key 'path'
            $scopeText = Get-EntryString -Entry $item -Key 'scope'
            if ($scopeText) { $scope = $scopeText }
        }
        if (-not $path) { continue }
        if ($scope -ne 'Machine') { $scope = 'User' }
        $result['appliedPath'] += [ordered]@{ path = $path; scope = $scope }
    }

    foreach ($item in @(Get-EntryArray -Entry $Entry -Key 'appliedShortcuts')) {
        $text = [string]$item
        if ($text.Trim()) { $result['appliedShortcuts'] += $text }
    }

    # 配套文件「上次落位」的目标路径
    foreach ($item in @(Get-EntryArray -Entry $Entry -Key 'appliedFiles')) {
        $text = [string]$item
        if ($text.Trim()) { $result['appliedFiles'] += $text }
    }

    return $result
}
