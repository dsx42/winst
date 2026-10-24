#Requires -Version 5.1

function Invoke-WinstUninstallApp {
    <#
    .SYNOPSIS
        卸载一个软件：删除程序本体（或运行官方卸载程序）→ 回收 winst 写入的系统项 → 移除安装记录。
    .DESCRIPTION
        - external 记录（非 winst 安装）默认只移除安装记录。
        - installer 实时回读注册表执行卸载；卸载命令缺失时报告无法自动卸载，`--force` 才只移除登记
          （交互式菜单里就地问一句「是否只移除安装记录」，不提命令行开关，见 Read-WinstRemoveRecordOnlyChoice）。
        - `--dry-run` 只展示不落盘；`--yes` / 输入被重定向时不询问残留文件删除（默认保留）。
        - **运行中检测**：确认卸载后先检测软件是否在运行，命中即走同一套交互；
          非交互下需 `--kill` 才自动结束。external 记录只移除登记、不碰文件，跳过检测。
        - 依赖提示：卸载前列出依赖它的已安装软件，**仅提示、不拦截**。
        本函数只做编排；各步骤见 Confirm-WinstUninstallGo / Write-WinstDependentsHint /
        Confirm-WinstUninstallRunning / Invoke-WinstPreUninstallCommands / Invoke-WinstRemovePayload /
        Remove-WinstAppliedSystemItems 的说明。
    .OUTPUTS
        @{ Ok; Cancelled; Removed; NeedRestart; Missing; Error; Message; Leftovers; Notes }
    #>
    param(
        [Parameter(Mandatory = $true)][hashtable]$Context,
        [Parameter(Mandatory = $true)][string]$Id,
        [switch]$Force,
        [switch]$Yes,
        [switch]$Quiet,
        [switch]$SkipConfirm,
        # --kill：非交互（--yes / 输入被重定向）下检测到软件在运行时自动结束进程（与安装 / 更新同一口径，
        #；交互式下不传也会就地询问 k / c
        [switch]$Kill
    )

    $result = @{
        Ok = $false; Cancelled = $false; Removed = $false; NeedRestart = $false; Missing = $false;
        Error = ''; Message = ''; Leftovers = @(); Notes = @()
    }

    $dryRun = [bool]((Get-WinstState -Name WinstOptions) -and (Get-WinstState -Name WinstOptions).DryRun)

    $stateRead = Read-WinstState -InstallRoot $Context.InstallRoot
    if ($stateRead.Error -and -not $stateRead.Reset) {
        $result.Error = $stateRead.Error
        return $result
    }
    if ($stateRead.Error -and -not $Quiet) { Write-Host ('  提示: {0}' -f $stateRead.Error) -ForegroundColor Yellow }
    $state = $stateRead.State

    $ledger = Get-WinstInstalledApp -State $state -Id $Id
    if (-not $ledger) {
        $result.Error = ('安装记录里没有「{0}」这个软件。' -f $Id)
        return $result
    }

    $targets = Get-WinstUninstallTargets -Context $Context -Id $Id -Entry $ledger
    Show-WinstUninstallPlan -Context $Context -Targets $targets

    Write-WinstDependentsHint -Context $Context -Id $Id

    $gate = Confirm-WinstUninstallGo -DryRun:$dryRun -Yes:$Yes -SkipConfirm:$SkipConfirm
    if (-not $gate.Proceed) {
        if ($gate.Preview) {
            $result.Ok = $true
            $result.Message = '预览模式未执行卸载'
        } else {
            $result.Cancelled = $true
        }
        return $result
    }

    # 卸载过程共享的可变状态（备注 / 残留目录 / 是否「只移除记录」；结果对象用于 Missing / NeedRestart）
    $runState = @{ Notes = @(); Leftovers = @(); ForceRemove = [bool]$Force; Result = $result }

    # —— 运行中检测 ——
    $running = Confirm-WinstUninstallRunning -Context $Context -Id $Id -Ledger $ledger -Targets $targets `
        -Yes:$Yes -Kill:$Kill -Quiet:$Quiet
    if (-not $running.Ok) {
        if ($running.Cancelled) {
            $result.Cancelled = $true
            return $result
        }
        $result.Error = [string]$running.Error
        return $result
    }
    foreach ($note in @($running.Notes)) { $runState.Notes += $note }

    # —— ⓪ 卸载命令 ——
    $pre = Invoke-WinstPreUninstallCommands -Context $Context -Id $Id -Targets $targets -ForceRemove ([bool]$Force) -Quiet:$Quiet
    foreach ($note in @($pre.Notes)) { $runState.Notes += $note }
    if (-not $pre.Ok) {
        $result.Error = [string]$pre.Error
        return $result
    }

    # —— ① 删除程序本体 ——
    $payload = Invoke-WinstRemovePayload -Context $Context -Id $Id -Targets $targets -Ledger $ledger -RunState $runState -Yes:$Yes -Quiet:$Quiet
    if ($payload.Abort) {
        $result.Error = [string]$payload.Error
        return $result
    }

    # —— ② 回收 winst 写入的系统项 ——
    Remove-WinstAppliedSystemItems -Context $Context -State $state -Id $Id -Targets $targets -RunState $runState -Quiet:$Quiet

    # —— ③ 移除安装记录 ——
    $ledgerResult = Remove-WinstUninstallLedgerEntry -Context $Context -State $state -Id $Id
    if ($ledgerResult.Error) {
        $result.Error = [string]$ledgerResult.Error
        return $result
    }

    $result.Ok = $true
    $result.Removed = $true
    $result.Leftovers = @($runState.Leftovers)
    $result.Notes = @($runState.Notes)
    $result.Message = Format-WinstUninstallMessage -Id $Id -Targets $targets
    return $result
}
