#Requires -Version 5.1

function Invoke-WinstOldVersionRemoval {
    <#
    .SYNOPSIS
        卸掉一个旧版本：按「可能能卸掉它」的卸载键逐个尝试，第一个成功即停，再清理残留记录。
    .DESCRIPTION
        同一个版本常有两层系统安装记录，而外层 burn 引导包的卸载器文件可能已经被磁盘清理删掉
        （`%ProgramData%\Package Cache` 被清空，注册表记录却还在）。只按登记的那一个键执行，
        就会得到「卸载器文件不存在」——内层 MSI（`MsiExec.exe /X{GUID}`，缓存在
        `C:\Windows\Installer`）其实仍然可用。

        因此这里动态重算候选键（登记的键排在最前），遇到「卸载器文件不存在」就换下一条；
        全部失败才报错，错误信息把每条候选的失败原因都列出来。

        卸掉之后，同一版本那些「卸载器已不存在」的孤儿记录会一并清理——否则它们会一直留在
        「设置 → 应用」里，用户点了也卸不掉。
    .OUTPUTS
        @{ Ok; NeedRestart; Error; Command; Attempts; Removed; Cleaned }
    #>
    param(
        [hashtable]$Context,
        [string]$Id,
        [string]$Version,
        [string]$RecordKey = '',
        [switch]$Quiet
    )

    $result = @{
        Ok = $false; NeedRestart = $false; Error = ''; Command = ''
        Attempts = @(); Removed = $false; Cleaned = @()
    }

    $plan = Get-WinstLockedPlan -Context $Context -Id $Id
    $candidates = @()
    if ($plan) { $candidates = @(Resolve-WinstOldVersionCandidateKeys -Plan $plan -Version $Version) }
    # 登记的键排在最前：它是检测时确实指向这个版本的那条记录
    if ($RecordKey) { $candidates = @($RecordKey) + @($candidates | Where-Object { $_ -ne $RecordKey }) }

    if ($candidates.Count -eq 0) {
        $result.Error = '系统安装记录里没有这个版本的卸载入口'
        return $result
    }

    $failures = @()
    $removed = $false
    foreach ($key in $candidates) {
        $run = Invoke-WinstUninstallRegistryKey -KeyPath $key -Quiet:$Quiet
        $result.Attempts += [ordered]@{
            KeyPath = $key
            Ok      = [bool]$run.Ok
            Missing = [bool]$run.Missing
            Error   = [string]$run.Error
        }
        if ($run.Ok) {
            $result.Ok = $true
            $result.NeedRestart = [bool]$run.NeedRestart
            $result.Command = [string]$run.Command
            $removed = $true
            break
        }
        $reason = [string]$run.Error
        if (-not $reason) { $reason = '未知原因' }
        $failures += $reason
    }

    if (-not $removed) {
        $result.Error = ($failures -join '；')
        return $result
    }

    # 已卸掉：同一版本里「卸载器已不存在」的孤儿记录一并清理，否则它们在「设置 → 应用」里
    # 会一直显示一个卸不掉的条目
    if ($plan) {
        foreach ($orphanKey in @(Find-WinstOrphanRegistryRecords -Plan $plan -Version $Version)) {
            $clean = Remove-WinstOrphanRegistryRecord -KeyPath $orphanKey -Quiet:$Quiet
            if ($clean.Ok) { $result.Cleaned += $orphanKey }
        }
        if (@($result.Cleaned).Count -gt 0) { Reset-WinstSystemCache }
    }

    return $result
}
