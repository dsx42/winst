#Requires -Version 5.1

function Invoke-WinstUninstallRegistryPayload {
    <#
    .SYNOPSIS
        installer：用安装记录里的名称规则 + 卸载参数运行官方卸载程序，并检查残留。
    .OUTPUTS
        @{ Abort; Error }
    #>
    param([hashtable]$Context, [string]$Id, $Targets, $Ledger, [hashtable]$RunState, [switch]$Yes, [switch]$Quiet)

    $result = $RunState.Result
    # installer：用安装记录里的名称规则 + 卸载参数（软件源里删掉该软件也照样能定位卸载程序）
    $uninstallPlan = @{
        id        = $Id
        name      = $Id
        detect    = @{ method = 'registry'; name = [string]$Targets['NameRule'] }
        uninstall = @{ method = 'registry'; name = [string]$Targets['NameRule']; uninstallArgs = [string]$Targets['UninstallArgs'] }
    }
    $run = Invoke-WinstRunUninstaller -Context $Context -Plan $uninstallPlan -Quiet:$Quiet
    if (-not $run.Ok) {
        $result.Missing = [bool]$run.Missing
        $fallback = Resolve-WinstRecordOnlyFallback -Id $Id -Reason ([string]$run.Error) -RunState $RunState -Yes $Yes `
            -MenuAbortFormat '{0}。安装记录已保留；如需只移除安装记录，请重新进入「卸载软件」并在提示里选 y。'
        if ($fallback.Abort) { return $fallback }
        $RunState.Notes += ('未能运行卸载程序（{0}），仅移除安装记录' -f $run.Error)
        return @{ Abort = $false; Error = '' }
    }

    if ($run.NeedRestart) {
        $result.NeedRestart = $true
        $RunState.Notes += '卸载程序提示需要重启电脑才能完成'
    }
    if (-not $Quiet) { Write-Host '    卸载程序已执行完成。' -ForegroundColor Gray }

    # 回读系统安装记录：仍在 → 可能需重启才能完成
    if (Get-WinstRegistryEntryForPlan -Plan $uninstallPlan -InstallDir ([string]$Targets['InstallDir'])) {
        $RunState.Notes += '系统安装记录里仍有该软件，可能需重启电脑后才会完全移除'
    }

    # 按 detect 规则复查软件文件：卸载器报成功、文件却还在（Windows Installer 状态
    # 异常 / 卸载器没清理干净 / 需重启才完成移除）时不静默放行，把残留明说——否则下次安装会被
    # 「已是 x.y，无需重复安装」挡回去，用户却以为已经卸干净了。
    # detect 本身走 registry 的条目上面一步已覆盖，不重复；检测出的是同族其它版本
    # （如运行时共存的新旧两版）时不算残留，只提示一句、不当成本次没卸掉
    $recheckPlan = $Targets['ManifestPlan']
    $recheckMethod = ''
    if ($recheckPlan) {
        $recheckMethod = (Get-EntryString -Entry (Get-EntryValue -Entry $recheckPlan -Key 'detect' -Default $null) -Key 'method').Trim().ToLowerInvariant()
    }
    if ($recheckPlan -and $recheckMethod -and $recheckMethod -ne 'registry') {
        $recheck = Get-WinstDetectedVersion -Context $Context -Plan $recheckPlan -InstallDir ([string]$Targets['InstallDir'])
        if ($recheck.Found) {
            $recheckVersion = [string]$recheck.Version
            $ledgerName = Get-EntryString -Entry $Ledger -Key 'name'
            if (-not $ledgerName) { $ledgerName = $Id }
            $uninstalledVersion = [string]$Targets['Version']
            if ($recheckVersion -and $uninstalledVersion -and ($recheckVersion -ine $uninstalledVersion)) {
                if (-not $Quiet) { Write-Host ('    提示: 系统里仍有 {0} 的其它版本 {1}（不属于本次卸载范围，未处理）。' -f $ledgerName, $recheckVersion) -ForegroundColor DarkGray }
            } else {
                $recheckWhere = [string]$recheck.Detail
                if ($recheckWhere) { $recheckWhere = ('（{0}）' -f $recheckWhere) }
                $residueNote = ('卸载程序已执行完成，但按检测规则仍能找到 {0} {1} 的文件{2}——可能是卸载器未清理干净，或需重启电脑完成移除' -f $ledgerName, $recheckVersion, $recheckWhere)
                if (-not $Quiet) { Write-Host ('    警告: {0}。' -f $residueNote) -ForegroundColor Yellow }
                $RunState.Notes += $residueNote
            }
        }
    }

    # 安装目录残留：列出并询问是否删除（默认保留，非交互 / --yes 时保留）
    $dir = [string]$Targets['InstallDir']
    if ($dir -and (Test-Path -LiteralPath $dir -PathType Container)) {
        $remain = @(Get-ChildItem -LiteralPath $dir -Force -ErrorAction SilentlyContinue)
        if ($remain.Count -gt 0) {
            Write-Host ''
            Write-Host ('    安装目录里还有 {0} 项残留: {1}' -f $remain.Count, $dir) -ForegroundColor DarkYellow
            $deleteLeftover = $false
            if (-not $Yes -and -not (Test-WinstInputRedirected)) {
                $deleteLeftover = Read-WinstConfirm -Prompt '    是否删除这些残留文件？(y/N，默认保留)' -Default 'n'
            }
            if ($deleteLeftover) {
                Clear-WinstInstallDir -Dir $dir
                if (Test-Path -LiteralPath $dir -PathType Container) {
                    $RunState.Leftovers += $dir
                    $RunState.Notes += ('残留文件未能全部删除，请手动检查: {0}' -f $dir)
                }
            } else {
                $RunState.Leftovers += $dir
                $RunState.Notes += ('残留文件已保留，可自行删除: {0}' -f $dir)
            }
        }
    }

    return @{ Abort = $false; Error = '' }
}
