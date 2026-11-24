#Requires -Version 5.1

function Invoke-WinstUpdateExecuteEntry {
    <#
    .SYNOPSIS
        执行更新：保护规则（不自动降级 / external 只报告）→ 按检查选定的来源复用安装流程。
    #>
    param([hashtable]$Context, [string]$Id, $Row, $Ledger, $Snap, $EntryResult, [string]$InstalledVersion,
        [string]$DisplayName, [switch]$DownloadOnly, [switch]$Force, [switch]$Yes,
        [switch]$FilesOnly, [switch]$ForceSystemItems)

    $latest = [string]$Snap.Latest
    $latestSource = [string]$Snap.LatestSource
    $comparable = [bool]$Snap.Comparable
    $cmp = [int]$Snap.Cmp

    # —— 执行更新：保护规则 ——
    # 无法比较版本的两种按软件源里的定义安装：它们本来就没有「降级」这回事（没有可比对的版本），
    # 只需放行安装侧的「已装检查」（等同 --force，只作用于这一条）；「本机版本比软件源里新」的保护不变。
    $forceThisItem = [bool]$Force
    if (-not $comparable -or -not $latest) {
        if ($Snap.VersionFromPackage) {
            # 「版本号取自主包文件信息」的条目交给安装流程「先取包、再决定」——不强制重装
            Write-Host ''
            Write-Host ('  {0}: 无法比较版本（版本号取自主包文件信息），更新时重新取包核对。' -f $DisplayName) -ForegroundColor DarkYellow
        } else {
            $forceThisItem = $true
            $reasonText = '本机版本未知'
            if (-not $latest) { $reasonText = '软件源里没有可用的版本信息' }
            Write-Host ''
            Write-Host ('  {0}: 无法比较版本（{1}），按软件源里的定义更新。' -f $DisplayName, $reasonText) -ForegroundColor DarkYellow
        }
    }
    if ($comparable -and $latest -and $cmp -eq 0 -and -not $Force) {
        # 版本相同、只有配套文件有变化 → 走「仅配套文件更新」
        # 注意：-Force 时这一段整体被上面的条件短路掉 —— 用户明确要求重装，就不该走「只更新附加文件」
        $companionInfo = Get-WinstCompanionUpdateInfo -Context $Context -Plan $Row['Sources'][0]['Plan']
        if ($companionInfo.Error) { throw ('附加文件检查失败：{0}' -f $companionInfo.Error) }
        if ($Snap.VersionFromPackage -and $companionInfo.PrimaryCacheError -and -not $DownloadOnly) {
            $EntryResult.Network = [bool]$companionInfo.PrimaryCacheNetwork
            $EntryResult.Action = 'failed'
            Write-Host ('  {0}: {1}' -f $DisplayName, $companionInfo.PrimaryCacheError) -ForegroundColor Red
            return
        }
        if ($companionInfo.CompanionsOnly) {
            Write-Host ''
            Write-Host ('  {0}: 附加文件待更新（{1} 个）: {2}' -f $DisplayName, $companionInfo.ChangedCount, ($companionInfo.Names -join '、')) -ForegroundColor DarkYellow
        }
        if (-not ($companionInfo.CompanionsOnly -or $companionInfo.PrimaryCacheError)) {
            $EntryResult.Action = 'latest'
            Write-Host ''
            Write-Host ('  {0}: 已是最新版本（{1}）。' -f $DisplayName, $InstalledVersion) -ForegroundColor Gray
            return
        }
    }
    if ($comparable -and $latest -and $cmp -lt 0 -and -not $Force) {
        $EntryResult.Action = 'newer'
        Write-Host ''
        if (Test-WinstMenuMode) {
            # 菜单里不能出现命令行开关：指向菜单里能做到重装 / 降级的入口
            Write-Host ('  {0}: 本机已安装 {1}，比软件源里的 {2} 更新；不自动降级（需要重装 / 降级请到「安装软件」里搜索「{0}」，按提示确认强制重装）。' -f $DisplayName, $InstalledVersion, $latest) -ForegroundColor DarkYellow
        } else {
            Write-Host ('  {0}: 本机已安装 {1}，比软件源里的 {2} 更新；如需降级请加 --force。' -f $DisplayName, $InstalledVersion, $latest) -ForegroundColor DarkYellow
        }
        return
    }

    # external 的免安装版 / 单文件程序：只报告，不覆盖
    $managed = Get-EntryString -Entry $Ledger -Key 'managed'
    if (-not $managed) { $managed = 'winst' }
    $type = (Get-EntryString -Entry $Ledger -Key 'type').Trim().ToLowerInvariant()
    if ($managed -ne 'winst' -and $type -and $type -ne 'installer') {
        $EntryResult.Action = 'external'
        Write-Host ''
        Write-Host ('  {0}: 当前 {1}  →  新版本 {2}（来自 {3}）  ↑' -f $DisplayName, $InstalledVersion, $latest, $latestSource) -ForegroundColor DarkYellow
        Write-Host '    该软件不是 winst 安装的，winst 不覆盖它，请用软件自己的方式更新。' -ForegroundColor DarkGray
        return
    }

    # 执行：复用安装流程（含升级提示、确认、运行中软件处理与台账写入）
    Write-Host ''
    Write-Host ('  —— {0}（{1}）——' -f $DisplayName, $Id) -ForegroundColor Cyan
    if ($FilesOnly) {
        Write-Host '    仅更新文件：环境变量 / PATH 保持原样；快捷方式只修正不新建' -ForegroundColor DarkYellow
    } elseif ((-not $ForceSystemItems) -and [bool](Get-ConfigValue -Config $Context.Config -Key 'updateFilesOnly' -Default $true)) {
        Write-Host '    只更新文件：环境变量 / PATH 保持原样；快捷方式只修正不新建' -ForegroundColor DarkGray
    }
    $one = Invoke-WinstInstallTarget -Context $Context -Row $Row -Force:$forceThisItem -DownloadOnly:$DownloadOnly `
        -Yes:$Yes -FilesOnly:$FilesOnly -ForceSystemItems:$ForceSystemItems

    if ($one.Cancelled) {
        $EntryResult.Action = 'cancelled'
    } elseif (-not $one.Ok) {
        $EntryResult.Network = [bool]$one.Network
        $EntryResult.Action = 'failed'
        # 失败原因就地打印过就不再重复；没有的话在这里补一句，否则汇总只剩「失败 1」
        if (-not [bool]$one.FailureShown) {
            $reason = [string]$one.Error
            if (-not $reason) { $reason = [string]$one.Message }
            if (-not $reason) { $reason = '未知原因' }
            Write-Host ''
            Write-Host ('  {0}: 更新失败 —— {1}' -f $DisplayName, $reason) -ForegroundColor Red
        }
    } elseif ($one.Skipped) {
        $EntryResult.Action = 'skipped'
    } else {
        $EntryResult.Action = 'updated'
    }

    # 更新后重读安装记录，后续条目按最新状态处理
    $EntryResult.RefreshState = $true
}
