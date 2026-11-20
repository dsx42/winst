#Requires -Version 5.1

function Invoke-WinstUninstallRegistryPayload {
    <#
    .SYNOPSIS
        installer：用安装记录里的名称规则 + 卸载参数运行官方卸载程序，并检查残留。
    .OUTPUTS
        @{ Abort; Error }
    #>
    param([string]$Id, $Targets, [hashtable]$RunState, [switch]$Yes, [switch]$Quiet)

    $result = $RunState.Result
    # installer：用安装记录里的名称规则 + 卸载参数（软件源里删掉该软件也照样能定位卸载程序）
    $uninstallPlan = @{
        id        = $Id
        name      = $Id
        detect    = @{ method = 'registry'; name = @($Targets['NameRule']) }
        uninstall = @{ method = 'registry'; name = @($Targets['NameRule']); uninstallArgs = [string]$Targets['UninstallArgs'] }
    }
    $selectedRecord = Get-WinstRegistryEntryForPlan -Plan $uninstallPlan -InstallDir ([string]$Targets['InstallDir'])
    $recordDir = ''
    if ($selectedRecord) { $recordDir = Get-WinstRegistryEntryInstallDir -Entry $selectedRecord }
    $run = Invoke-WinstRunUninstaller -Plan $uninstallPlan -Quiet:$Quiet
    $result.RestartInitiated = Get-EntryBool -Entry $run -Key 'RestartInitiated'
    if (-not $run.Ok) {
        if (Get-EntryBool -Entry $run -Key 'Cancelled') {
            $result.Cancelled = $true
            return @{ Abort = $true; Error = '用户已取消卸载，安装记录已保留' }
        }
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
    if (Get-EntryBool -Entry $run -Key 'RestartInitiated') { return @{ Abort = $false; Error = '' } }
    if (-not $Quiet) { Write-Host '    卸载程序已执行完成。' -ForegroundColor Gray }

    # 回读系统安装记录：仍在 → 可能需重启才能完成
    Reset-WinstSystemCache
    if (Get-WinstRegistryEntryForPlan -Plan $uninstallPlan -InstallDir ([string]$Targets['InstallDir'])) {
        $RunState.Notes += '系统安装记录里仍有该软件，可能需重启电脑后才会完全移除'
    }

    # 官方卸载器留下的目录默认保留，交互确认后才删除。
    $dir = [string]$Targets['InstallDir']
    if ($dir -and (Test-Path -LiteralPath $dir -PathType Container)) {
        try {
            $verified = ($recordDir -and (([IO.Path]::GetFullPath($recordDir)).TrimEnd('\') -ieq ([IO.Path]::GetFullPath($dir)).TrimEnd('\')))
            if ($verified) { Assert-WinstSafeWritePath -Path $dir -Directory }
        } catch { $verified = $false }
        if (-not $verified) {
            $RunState.Leftovers += $dir
            $RunState.Notes += ('安装目录无法与本次系统记录安全对应，残留已保留：{0}' -f $dir)
            return @{ Abort = $false; Error = '' }
        }
        Write-Host ''
        Write-Host ('    卸载后安装目录仍存在：{0}' -f $dir) -ForegroundColor DarkYellow
        $deleteLeftover = $false
        if (-not $Yes -and -not (Test-WinstInputRedirected)) {
            $deleteLeftover = Read-WinstConfirm -Prompt '    是否删除此目录及其内容？(y/N，默认保留)' -Default 'n'
        }
        if ($deleteLeftover) {
            try {
                Invoke-WinstFileStep -Name '删除残留目录' -Quiet:$Quiet -Action { Remove-WinstDirectoryTree -Path $dir }
            } catch {
                $RunState.Leftovers += $dir
                $RunState.Notes += ('残留目录删除失败，请手动检查 {0}：{1}' -f $dir, $_.Exception.Message)
            }
        } else {
            $RunState.Leftovers += $dir
            $RunState.Notes += ('残留目录已保留，可自行删除：' + $dir)
        }
    }

    return @{ Abort = $false; Error = '' }
}
