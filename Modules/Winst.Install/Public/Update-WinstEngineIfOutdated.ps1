#Requires -Version 5.1

function Update-WinstEngineIfOutdated {
    <#
    .SYNOPSIS
        引擎已安装时检查有没有新版本：有就自动更新（下载新包 → 覆盖引擎目录 → 更新台账）。
    .DESCRIPTION
        触发时机 = Confirm-WinstDownloadEngine / Confirm-WinstExtractEngine（每次下载 / 解压前调用）；
        与引擎引导同一来源（固定内置源），最新版本**优先读软件清单解析锁（本地文件，零网络）**，
        锁里没有该条目时才会实时解析（联网）。
        每个进程内每个引擎最多检查一次（$script:WinstEngineUpdateChecked），避免同一会话里反复比较；
        `--offline` / `--dry-run` 跳过；版本未知（台账或软件源任一侧读不出）不自动更新；
        更新失败**不阻塞**：保留现有引擎继续用，只提示一行（安装版流程照常进行）。
    .OUTPUTS
        @{ Updated; Error }
    #>
    param(
        [Parameter(Mandatory = $true)][hashtable]$Context,
        [Parameter(Mandatory = $true)][string]$Id,
        [switch]$Quiet
    )

    $result = @{ Updated = $false; Error = '' }
    if ((Get-WinstState -Name WinstOptions) -and ((Get-WinstState -Name WinstOptions).Offline -or (Get-WinstState -Name WinstOptions).DryRun)) { return $result }
    if ((Get-WinstState -Name WinstEngineUpdateChecked).ContainsKey($Id)) { return $result }
    (Get-WinstState -Name WinstEngineUpdateChecked)[$Id] = $true

    # 已装版本：引擎没写台账时不自动更新——没有「从哪个版本升上来」的依据
    $state = (Read-WinstState -InstallRoot $Context.InstallRoot).State
    $entry = Get-WinstInstalledApp -State $state -Id $Id
    if (-not $entry) { return $result }
    $installedVersion = Get-EntryString -Entry $entry -Key 'version'
    if (-not $installedVersion -or $installedVersion -ieq 'unknown') { return $result }

    # 最新版本：固定内置源
    $resolved = Get-WinstManifestAppPlan -Context $Context -Id $Id -PreferSource (Get-WinstOfficialManifestName)
    if (-not $resolved.Ok) { return $result }
    $latest = Get-EntryString -Entry $resolved.Plan -Key 'version'
    if (-not $latest -or $latest -ieq 'unknown') { return $result }

    if ((Compare-WinstVersion -A $latest -B $installedVersion) -le 0) { return $result }

    if (-not $Quiet) { Write-Host ('  检测到 {0} 有新版本（{1} → {2}），正在自动更新 …' -f $Id, $installedVersion, $latest) -ForegroundColor Gray }
    $r = Install-WinstEngine -Context $Context -Id $Id -ForceUpdate -Quiet:$Quiet
    if ($r.Ok) {
        $result.Updated = $true
        if (-not $Quiet) { Write-Host ('  {0} 已更新到 {1}。' -f $Id, $latest) -ForegroundColor DarkGray }
    } else {
        $result.Error = $r.Error
        if (-not $Quiet) { Write-Host ('  {0} 自动更新失败（继续使用现有版本 {1}）: {2}' -f $Id, $installedVersion, $r.Error) -ForegroundColor DarkYellow }
    }
    return $result
}
