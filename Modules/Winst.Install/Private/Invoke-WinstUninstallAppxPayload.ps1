#Requires -Version 5.1

function Invoke-WinstUninstallAppxPayload {
    <#
    .SYNOPSIS
        应用包（msixbundle 等）：用系统自带的 Remove-AppxPackage 按名称规则移除。
    .OUTPUTS
        @{ Abort; Error }
    #>
    param([hashtable]$Context, [string]$Id, $Targets, [hashtable]$RunState, [switch]$Yes, [switch]$Quiet)

    $remove = Remove-WinstAppxPackage -NameRule $Targets['NameRule'] -Quiet:$Quiet
    if ($remove.Ok) {
        if (-not $Quiet) { Write-Host '    应用包已移除。' -ForegroundColor Gray }
        return @{ Abort = $false; Error = '' }
    }

    $fallback = Resolve-WinstRecordOnlyFallback -Id $Id -Reason ([string]$remove.Error) -RunState $RunState -Yes $Yes `
        -MenuAbortFormat '{0}。已保留安装记录；如需只移除安装记录，请到「卸载软件」里重新选中这个软件，在弹出的提示里选 y。'
    if ($fallback.Abort) { return $fallback }
    $RunState.Notes += ('未能移除应用包（{0}），仅移除安装记录' -f $remove.Error)
    return @{ Abort = $false; Error = '' }
}
