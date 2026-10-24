#Requires -Version 5.1

function Remove-WinstUninstallLedgerEntry {
    <#
    .SYNOPSIS
        ③ 移除安装记录并落盘。
    .OUTPUTS
        @{ Error }
    #>
    param([hashtable]$Context, $State, [string]$Id)

    try {
        $stateRead = Read-WinstState -InstallRoot $Context.InstallRoot
    } catch {
        return @{ Error = ('重读安装台账失败：{0}' -f $_.Exception.Message) }
    }
    if ($stateRead.Error -and -not $stateRead.Reset) {
        return @{ Error = ('重读安装台账失败：{0}' -f $stateRead.Error) }
    }
    $latestState = $stateRead.State
    if (-not (Remove-WinstInstalledApp -State $latestState -Id $Id)) { return @{ Error = '' } }
    try {
        Save-WinstState -InstallRoot $Context.InstallRoot -State $latestState
    } catch {
        return @{ Error = ('移除安装记录失败：{0}' -f $_.Exception.Message) }
    }
    return @{ Error = '' }
}
