#Requires -Version 5.1

function Confirm-WinstUninstallRunning {
    <#
    .SYNOPSIS
        卸载前的运行中检测（软件在运行会锁住文件，删除目录 / 跑卸载程序都可能删不干净）。
    .DESCRIPTION
        与安装 / 更新同一套交互（k 强杀 / c 已手动关闭 / 其它取消）；record-only（只移除记录、不碰文件）跳过检测。
        非 winst 预期目录也一并检测（台账 installDir / installRoot\id），避免软件装在别处时漏检。
    .OUTPUTS
        @{ Ok; Cancelled; Error; Notes }
    #>
    param([hashtable]$Context, [string]$Id, $Ledger, $Targets, [switch]$Yes, [switch]$Kill, [switch]$Quiet)

    $notes = @()
    if ([string]$Targets['Method'] -eq 'record-only') { return @{ Ok = $true; Cancelled = $false; Error = ''; Notes = @() } }

    $checkPlan = $Targets['ManifestPlan']
    if (-not $checkPlan) {
        $ledgerName = Get-EntryString -Entry $Ledger -Key 'name'
        if (-not $ledgerName) { $ledgerName = $Id }
        $checkPlan = @{ id = $Id; name = $ledgerName }
    }
    $checkDirs = @()
    foreach ($d in @((Get-EntryString -Entry $Ledger -Key 'installDir'), (Join-WinstPath $Context.InstallRoot $Id))) {
        $dirText = ([string]$d).Trim()
        if ($dirText) { $checkDirs += $dirText }
    }
    $nonInteractive = [bool]($Yes -or (Test-WinstInputRedirected))
    $runningCheck = Confirm-WinstAppNotRunning -Context $Context -Plan $checkPlan `
        -InstallDir ([string]$Targets['InstallDir']) -ExtraDirs $checkDirs `
        -Action '卸载' -Kill:$Kill -NonInteractive:$nonInteractive -Quiet:$Quiet
    if (-not $runningCheck.Ok) {
        return @{ Ok = $false; Cancelled = [bool]$runningCheck.Cancelled; Error = [string]$runningCheck.Error; Notes = @() }
    }
    if ([int]$runningCheck.Killed -gt 0) {
        $notes += ('已结束 {0} 个正在运行的进程' -f [int]$runningCheck.Killed)
    }
    return @{ Ok = $true; Cancelled = $false; Error = ''; Notes = $notes }
}
