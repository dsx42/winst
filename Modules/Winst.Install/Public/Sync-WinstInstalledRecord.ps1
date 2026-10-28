#Requires -Version 5.1

function Sync-WinstInstalledRecord {
    <#
    .SYNOPSIS
        按软件源里的检测规则重新识别该软件当前的版本与安装位置，并更正安装记录（单个条目的轻量 repair）。
    .OUTPUTS
        @{ Ok; Changed; Message; Error }
    #>
    param(
        [Parameter(Mandatory = $true)][hashtable]$Context,
        [Parameter(Mandatory = $true)][string]$Id
    )

    $result = @{ Ok = $false; Changed = $false; Message = ''; Error = '' }

    $stateRead = Read-WinstState -InstallRoot $Context.InstallRoot
    if ($stateRead.Error -and -not $stateRead.Reset) { $result.Error = $stateRead.Error; return $result }
    $ledger = Get-WinstInstalledApp -State $stateRead.State -Id $Id
    if (-not $ledger) { $result.Error = ('安装记录里没有「{0}」这个软件。' -f $Id); return $result }

    $planResult = Get-WinstManifestAppPlan -Context $Context -Id $Id
    if (-not $planResult.Ok) {
        # 菜单里不出现命令行写法（见 Test-WinstMenuMode / 6.2）
        $repairHint = '（命令行侧可用 winst repair 重新扫描）'
        if (Test-WinstMenuMode) { $repairHint = '' }
        $result.Error = ('软件源里没有「{0}」，无法自动检测版本；可到「高级功能 → 管理软件源」刷新软件源后重试{1}。' -f $Id, $repairHint)
        return $result
    }
    $plan = $planResult.Plan

    $type = (Get-EntryString -Entry $ledger -Key 'type').Trim().ToLowerInvariant()
    if (-not $type) { $type = (Get-EntryString -Entry $plan -Key 'type').Trim().ToLowerInvariant() }

    $oldVersion = Get-EntryString -Entry $ledger -Key 'version'
    $oldDir = Get-EntryString -Entry $ledger -Key 'installDir'
    $newDir = $oldDir
    $dirChanged = $false

    # 安装版软件的实际安装目录以系统安装记录为准
    if ($type -eq 'installer') {
        $actual = Resolve-WinstActualInstallDir -Plan $plan -AssumedDir $oldDir
        if ($actual.Dir -and $actual.Dir -ine $oldDir) { $newDir = $actual.Dir; $dirChanged = $true }
    }

    $detect = Get-WinstDetectedVersion -Context $Context -Plan $plan -InstallDir $newDir
    $newVersion = ''
    if ($detect.Ok -and $detect.Version) { $newVersion = [string]$detect.Version }
    $newOldVersions = @()
    foreach ($one in @($detect.OldVersions)) {
        $newOldVersions += [ordered]@{
            version   = [string]$one['Version']
            detail    = [string]$one['Detail']
            recordKey = [string]$one['RecordKey']
        }
    }

    if (-not $newVersion) {
        if (-not $dirChanged) {
            $detail = ''
            if ($detect.Detail) { $detail = ('（{0}）' -f [string]$detect.Detail) }
            $result.Ok = $true
            $result.Message = ('没能识别出这个软件当前的版本{0}，安装记录保持不变。' -f $detail)
            return $result
        }
        try {
            $null = Update-WinstInstalledAppFields -InstallRoot $Context.InstallRoot -Id $Id `
                -Entry $ledger -Fields @{ installDir = $newDir }
        } catch {
            $result.Error = ('更新安装记录失败：{0}' -f $_.Exception.Message)
            return $result
        }
        $result.Ok = $true
        $result.Changed = $true
        $result.Message = ('安装位置已更正为 {0}；版本没能重新识别，保留原记录。' -f $newDir)
        return $result
    }

    # 本机并存的旧版本也要跟着更正：升级 / 手动清理后再次检测，读到的才是当前真实剩余
    $oldChanged = -not (Test-WinstOldVersionsEqual -A @(Get-EntryArray -Entry $ledger -Key 'oldVersions') -B $newOldVersions)
    if ($newVersion -eq $oldVersion -and -not $dirChanged -and -not $oldChanged) {
        $result.Ok = $true
        $result.Message = ('检测结果与安装记录一致：版本 {0}。' -f $newVersion)
        return $result
    }

    $fields = @{ version = $newVersion; oldVersions = @($newOldVersions) }
    if ($dirChanged) { $fields['installDir'] = $newDir }
    try {
        $null = Update-WinstInstalledAppFields -InstallRoot $Context.InstallRoot -Id $Id `
            -Entry $ledger -Fields $fields
    } catch {
        $result.Error = ('更新安装记录失败：{0}' -f $_.Exception.Message)
        return $result
    }

    $result.Ok = $true
    $result.Changed = $true
    if ($newVersion -eq $oldVersion) {
        $oldText = Format-WinstOldVersionText -OldVersions $newOldVersions
        if ($oldText) {
            $result.Message = ('安装记录已更新：版本 {0} 不变，本机并存的旧版本为 {1}' -f $newVersion, $oldText)
        } else {
            $result.Message = ('安装记录已更新：版本 {0} 不变，旧版本登记已清空（本机只剩这一个版本）' -f $newVersion)
        }
    } else {
        $oldText = $oldVersion
        if (-not $oldText) { $oldText = '未知' }
        $result.Message = ('安装记录已更新：版本 {0} → {1}' -f $oldText, $newVersion)
    }
    if ($dirChanged) { $result.Message += ('；安装位置更正为 {0}' -f $newDir) }
    return $result
}
