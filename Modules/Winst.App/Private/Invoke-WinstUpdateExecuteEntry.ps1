#Requires -Version 5.1

function Invoke-WinstUpdateExecuteEntry {
    <#
    .SYNOPSIS
        执行更新：保护规则（不自动降级 / external 只报告）→ 选来源 → 复用安装流程。
    .OUTPUTS
        @{ RefreshState }
    #>
    param([hashtable]$Context, [string]$Id, $Row, $Ledger, $Snap, $EntryResult, [string]$InstalledVersion,
        [string]$DisplayName, [switch]$DownloadOnly, [switch]$Force, [switch]$Yes, [switch]$Quiet,
        [bool]$AutoPick = $false, [switch]$FilesOnly, [switch]$ForceSystemItems, [string]$SourceName = '', [hashtable]$Result)

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
            if (-not $Quiet) {
                Write-Host ''
                Write-Host ('  {0}: 无法比较版本（版本号取自主包文件信息），更新时重新取包核对。' -f $DisplayName) -ForegroundColor DarkYellow
            }
        } else {
            $forceThisItem = $true
            if (-not $Quiet) {
                $reasonText = '本机版本未知'
                if (-not $latest) { $reasonText = '软件源里没有可用的版本信息' }
                Write-Host ''
                Write-Host ('  {0}: 无法比较版本（{1}），按软件源里的定义更新。' -f $DisplayName, $reasonText) -ForegroundColor DarkYellow
            }
        }
    }
    if ($comparable -and $latest -and $cmp -eq 0 -and -not $Force) {
        # 版本相同、只有配套文件有变化 → 走「仅配套文件更新」
        # 注意：-Force 时这一段整体被上面的条件短路掉 —— 用户明确要求重装，就不该走「只更新附加文件」
        $companionOnlyExec = $false
        $companionInfo = Get-WinstRowCompanionInfo -Context $Context -Row $Row
        if ($companionInfo -and $companionInfo.CompanionsOnly) {
            $companionOnlyExec = $true
            if (-not $Quiet) {
                Write-Host ''
                Write-Host ('  {0}: 主包已是最新（{1}）；附加文件有更新（{2} 个）: {3}' -f $DisplayName, $InstalledVersion, $companionInfo.ChangedCount, ($companionInfo.Names -join '、')) -ForegroundColor DarkYellow
            }
        }
        if (-not $companionOnlyExec) {
            $Result.UpToDate++
            $EntryResult.Action = 'latest'
            if (-not $Quiet) {
                Write-Host ''
                Write-Host ('  {0}: 已是最新版本（{1}）。' -f $DisplayName, $InstalledVersion) -ForegroundColor Gray
            }
            return @{ RefreshState = $false }
        }
    }
    if ($comparable -and $latest -and $cmp -lt 0 -and -not $Force) {
        $Result.Unknown++
        $EntryResult.Action = 'newer'
        $EntryResult.Message = '本机版本比软件源里的更新'
        if (-not $Quiet) {
            Write-Host ''
            if (Test-WinstMenuMode) {
                # 菜单里不能出现命令行开关：指向菜单里能做到重装 / 降级的入口
                Write-Host ('  {0}: 本机已安装 {1}，比软件源里的 {2} 更新；不自动降级（需要重装 / 降级请到「安装软件」里搜索「{0}」，按提示确认强制重装）。' -f $DisplayName, $InstalledVersion, $latest) -ForegroundColor DarkYellow
            } else {
                Write-Host ('  {0}: 本机已安装 {1}，比软件源里的 {2} 更新；如需降级请加 --force。' -f $DisplayName, $InstalledVersion, $latest) -ForegroundColor DarkYellow
            }
        }
        return @{ RefreshState = $false }
    }

    if ($comparable -and $latest -and $cmp -gt 0) { $Result.Updatable++ }

    # external 的免安装版 / 单文件程序：只报告，不覆盖
    $managed = Get-EntryString -Entry $Ledger -Key 'managed'
    if (-not $managed) { $managed = 'winst' }
    $type = (Get-EntryString -Entry $Ledger -Key 'type').Trim().ToLowerInvariant()
    if ($managed -ne 'winst' -and $type -and $type -ne 'installer') {
        $Result.Reported++
        $EntryResult.Action = 'external'
        if (-not $Quiet) {
            Write-Host ''
            Write-Host ('  {0}: 当前 {1}  →  新版本 {2}（来自 {3}）  ↑' -f $DisplayName, $InstalledVersion, $latest, $latestSource) -ForegroundColor DarkYellow
            Write-Host '    该软件不是 winst 安装的，winst 不覆盖它，请用软件自己的方式更新。' -ForegroundColor DarkGray
        }
        return @{ RefreshState = $false }
    }

    # 执行：复用安装流程（含升级提示、确认、运行中软件处理与台账写入）
    # 来源选择：-SourceName 明确指定时优先它；否则优先**安装时选择的来源**
    # （安装记录 manifestOrigin，安装时选哪个源、更新也默认用哪个源）；只有它**确实不比本机新**时
    # 才回退到「有更新版本」的来源并说明。
    $targetRow = Sort-WinstRowSources -Context $Context -Row $Row -InstalledVersion $InstalledVersion
    $otherHasNewer = [bool]($comparable -and $latest -and ($latestSource -ine $Snap.OriginName) -and ((Compare-WinstVersion -A $latest -B $InstalledVersion) -gt 0))
    if ($SourceName) {
        $preferred = Set-WinstRowPreferredSource -Row $targetRow -SourceName $SourceName
        if (([string]$preferred['Sources'][0]['Source']) -ieq $SourceName) {
            $targetRow = $preferred
        } else {
            Write-Host ('  提示: 软件源「{0}」里没有 {1} 的可用版本，已改用默认来源。' -f $SourceName, $DisplayName) -ForegroundColor DarkYellow
        }
    } elseif ($Snap.OriginUsable -and $Snap.OriginNewer) {
        # 安装时用的来源自己有更新版本 → 直接用它（即使别的来源版本号更高，保持这条软件的版本线稳定）
        $preferred = Set-WinstRowPreferredSource -Row $targetRow -SourceName $Snap.OriginName
        if (([string]$preferred['Sources'][0]['Source']) -ieq $Snap.OriginName) { $targetRow = $preferred }
    } elseif ($Snap.OriginUsable -and $otherHasNewer) {
        Write-Host ('  提示: 安装时用的软件源「{0}」没有比本机 {2} 更新的版本，改用软件源「{3}」的 {4}。' -f $Snap.OriginName, $Snap.OriginVersion, $InstalledVersion, $latestSource, $latest) -ForegroundColor DarkYellow
        $preferred = Set-WinstRowPreferredSource -Row $targetRow -SourceName $latestSource
        if (([string]$preferred['Sources'][0]['Source']) -ieq $latestSource) { $targetRow = $preferred }
    } else {
        if ($Snap.OriginName -and -not $Snap.OriginUsable) {
            Write-Host ('  提示: 安装时用的软件源「{0}」现在没有可用的版本，已改用默认来源。' -f $Snap.OriginName) -ForegroundColor DarkYellow
        }
        $preferred = Set-WinstRowPreferredSource -Row $targetRow -SourceName $Snap.OriginName
        if (([string]$preferred['Sources'][0]['Source']) -ieq $Snap.OriginName) { $targetRow = $preferred }
    }
    Write-Host ''
    Write-Host ('  —— {0}（{1}）——' -f $DisplayName, $Id) -ForegroundColor Cyan
    if ($FilesOnly) {
        Write-Host '    仅更新文件：不处理环境变量 / PATH / 快捷方式（保留现有设置）' -ForegroundColor DarkYellow
    } elseif ((-not $ForceSystemItems) -and [bool](Get-ConfigValue -Config $Context.Config -Key 'updateFilesOnly' -Default $true)) {
        Write-Host '    只更新文件：环境变量 / PATH / 快捷方式保持原样（不新增、不覆盖）' -ForegroundColor DarkGray
    }
    $one = Invoke-WinstInstallTarget -Context $Context -Row $targetRow -Force:$forceThisItem -DownloadOnly:$DownloadOnly `
        -Yes:$Yes -AutoPickSource:$AutoPick -Quiet:$Quiet -FilesOnly:$FilesOnly -ForceSystemItems:$ForceSystemItems

    if ($one.Cancelled) {
        $Result.Skipped++
        $EntryResult.Action = 'cancelled'
    } elseif (-not $one.Ok) {
        $Result.Failed++
        if ($one.Network) { $Result.Network = $true }
        $EntryResult.Action = 'failed'
        $EntryResult.Message = [string]$one.Error
    } elseif ($one.Skipped) {
        $Result.Skipped++
        $EntryResult.Action = 'skipped'
        $EntryResult.Message = [string]$one.Message
    } else {
        $Result.Updated++
        $EntryResult.Action = 'updated'
        $EntryResult.Latest = [string]$one.Version
    }

    # 更新后重读安装记录，后续条目按最新状态处理
    return @{ RefreshState = $true }
}
