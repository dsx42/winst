#Requires -Version 5.1

function Set-WinstInstallLedger {
    <#
    .SYNOPSIS
        ⑦ 写台账：合并已有的 applied* 登记与本次落地的系统项，写入版本、安装位置与卸载快照。
    .DESCRIPTION
        落盘走 Save-WinstInstalledAppEntry（重读最新台账、只覆盖这一条）：本次安装流程中途可能
        自动安装 / 更新过引擎或 winst 自身，那些记录不能被流程开始时读到的旧快照整份覆盖回去。
        已有的 applied* 登记也从重读后的条目取，与磁盘保持一致。
    #>
    param([hashtable]$Context, [string]$Id, [string]$Type, $Plan, [string]$InstallDir,
        [string]$Version, [string]$SourceName, $SystemItems, $AppliedFiles, $OldVersions = @())

    $existingEnv = @()
    $existingPath = @()
    $existingShortcuts = @()
    $ledger = Get-WinstInstalledApp -State (Read-WinstState -InstallRoot $Context.InstallRoot).State -Id $Id
    if ($ledger) {
        foreach ($item in @(Get-EntryArray -Entry $ledger -Key 'appliedEnv')) { $existingEnv += $item }
        foreach ($item in @(Get-EntryArray -Entry $ledger -Key 'appliedPath')) { $existingPath += $item }
        foreach ($item in @(Get-EntryArray -Entry $ledger -Key 'appliedShortcuts')) { $existingShortcuts += [string]$item }
    }
    $mergeKey = { param($items, $keyName)
        $merged = @()
        $seen = New-Object 'System.Collections.Hashtable' ([StringComparer]::OrdinalIgnoreCase)
        foreach ($item in @($items)) {
            $k = ''
            if ($item -is [string]) { $k = [string]$item } else { $k = (Get-EntryString -Entry $item -Key $keyName) }
            if (-not $k -or $seen.ContainsKey($k)) { continue }
            $seen[$k] = $true
            $merged += $item
        }
        return $merged
    }
    $allEnv = @(& $mergeKey (@($existingEnv) + @($SystemItems.AppliedEnv)) 'name')
    $allPath = @(& $mergeKey (@($existingPath) + @($SystemItems.AppliedPath)) 'path')
    $allShortcuts = @()
    foreach ($item in @(@($existingShortcuts) + @($SystemItems.AppliedShortcuts))) {
        $text = [string]$item
        if ($text -and ($allShortcuts -notcontains $text)) { $allShortcuts += $text }
    }

    $normalizedOld = @()
    foreach ($item in @($OldVersions)) {
        $oldText = Get-EntryString -Entry $item -Key 'version'
        if (-not $oldText) { $oldText = Get-EntryString -Entry $item -Key 'Version' }
        if (-not $oldText) { continue }
        $normalizedOld += [ordered]@{
            version   = $oldText
            detail    = (Get-EntryString -Entry $item -Key 'Detail')
            recordKey = (Get-EntryString -Entry $item -Key 'RecordKey')
        }
    }

    $null = Save-WinstInstalledAppEntry -InstallRoot $Context.InstallRoot -Id $Id -Entry ([ordered]@{
        version          = $Version
        type             = $Type
        group            = (Get-EntryString -Entry $Plan -Key 'group')
        installDir       = $InstallDir
        manifestOrigin   = $SourceName
        managed          = 'winst'
        appliedEnv       = $allEnv
        appliedPath      = $allPath
        appliedShortcuts = $allShortcuts
        appliedFiles     = $AppliedFiles
        # 本机并存的低版本：安装器升级后旧版本可能仍在系统里，记下来供界面提醒清理
        oldVersions      = @($normalizedOld)
        # 卸载操作快照：软件源以后删掉这个软件也能照常卸载
        uninstall        = (Get-WinstUninstallSnapshotFromPlan -Plan $Plan)
    })
}
