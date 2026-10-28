#Requires -Version 5.1
<#
    Update-WinstSelfIfOutdated.ps1  (Winst.Install / Public)

    清单给出更新版本时更新 winst。

    与 Update-WinstEngineIfOutdated 的关系
    --------------------------------------
    同样是：比较台账版本与清单版本，`--offline` / `--dry-run` 下跳过，
    任一侧版本未知时不更新，失败不阻断调用方。
    两处差异：引擎版每个进程只检查一次（WinstEngineUpdateChecked），本函数每次都检查；
    引擎版只看 Ok，本函数要求 Ok 且 Updated 才算「已更新」。

    安装动作交给 Install-WinstSelf，由它处理绿色版 zip 结构
    （winst.ps1 + winst.cmd + Modules\）。

    .OUTPUTS
        @{ Updated; Error }
#>
function Update-WinstSelfIfOutdated {
    <#
    .SYNOPSIS
        有更新版本时更新已安装的 winst 副本。

    .OUTPUTS
        @{ Updated; Error }
    #>
    [CmdletBinding()]
    [OutputType([hashtable])]
    param(
        [Parameter(Mandatory = $true)][hashtable]$Context,
        [switch]$Quiet
    )

    $result = @{ Updated = $false; Error = '' }

    if ((Get-WinstState -Name WinstOptions) -and
        ((Get-WinstState -Name WinstOptions).Offline -or (Get-WinstState -Name WinstOptions).DryRun)) {
        return $result
    }

    $entry = Get-WinstInstalledApp -State (Read-WinstState -InstallRoot $Context.InstallRoot).State -Id 'winst'
    if (-not $entry) { return $result }

    $installedVersion = Get-EntryString -Entry $entry -Key 'version'
    if (-not $installedVersion -or $installedVersion -ieq 'unknown') { return $result }

    $resolved = Get-WinstManifestAppPlan -Context $Context -Id 'winst' -PreferSource (Get-WinstOfficialManifestName)
    if (-not $resolved.Ok) { return $result }

    $latest = Get-EntryString -Entry $resolved.Plan -Key 'version'
    if (-not $latest -or $latest -ieq 'unknown') { return $result }
    if ((Compare-WinstVersion -A $latest -B $installedVersion) -le 0) { return $result }

    if (-not $Quiet) {
        Write-Host ('  检测到 winst 有新版本（{0} → {1}），正在自动更新 …' -f $installedVersion, $latest) -ForegroundColor Gray
    }

    $r = Install-WinstSelf -Context $Context -ForceUpdate -Quiet:$Quiet

    if ($r.Ok -and $r.Updated) {
        $result.Updated = $true
        $newVersion = [string]$r.Version
        if (-not $newVersion) { $newVersion = $latest }
        if (-not $Quiet) {
            Write-Host ('  winst 已更新到 {0}（下次启动生效）。' -f $newVersion) -ForegroundColor DarkGray
        }
    } else {
        $result.Error = [string]$r.Error
        if (-not $result.Error) { $result.Error = '更新流程没有安装新版本' }
        if (-not $Quiet) {
            Write-Host ('  winst 自动更新失败（继续使用现有版本 {0}）: {1}' -f $installedVersion, $result.Error) -ForegroundColor DarkYellow
        }
    }

    return $result
}
