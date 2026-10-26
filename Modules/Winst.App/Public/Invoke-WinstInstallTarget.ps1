#Requires -Version 5.1

function Invoke-WinstInstallTarget {
    <#
    .SYNOPSIS
        对已选定的软件执行「展示详情 → 确认 → 安装」。
    .DESCRIPTION
        `-FilesOnly`（仅更新文件）时只替换文件，不处理环境变量 / PATH / 快捷方式；
        不指定时按「设置 → 更新方式」执行（默认「只更新文件」）。
        依赖（条目的 dependencies 字段）：先解析出全部传递依赖里**需要动作**的部分（未安装 / 可更新），
        统一提示一次并随本体的确认一并执行——依赖先装 / 先更新，本体后装；
        任一依赖处理失败即中止本体安装。`-SkipDependencies` 供依赖自身的安装复用本函数时避免重复解析。
        依赖解析 / 依赖执行 / 确认 / 安装与重试 各由独立函数承担。
    .OUTPUTS
        @{ Ok; Skipped; Cancelled; Network; Message; Error; Version; Source }
    #>
    param(
        [Parameter(Mandatory = $true)][hashtable]$Context,
        [Parameter(Mandatory = $true)]$Row,
        [switch]$Force,
        [switch]$Overwrite,
        [string[]]$Keep = @(),
        [switch]$DownloadOnly,
        [switch]$Yes,
        [switch]$AutoPickSource,
        [switch]$KillRunning,
        [switch]$Quiet,
        [switch]$FilesOnly,
        [switch]$ForceSystemItems,
        [switch]$SkipDependencies
    )

    $result = @{
        Ok = $false; Skipped = $false; Cancelled = $false; Network = $false
        Message = ''; Error = ''; Version = ''; Source = ''
        # 失败原因是否已由本函数就地打印过：调用方据此决定要不要再报一次汇总
        FailureShown = $false
    }

    $chosen = Select-WinstRowSource -Row $Row -AutoPick:$AutoPickSource
    if ($chosen.Cancelled) { $result.Cancelled = $true; return $result }
    if (-not $chosen.Ok) {
        $result.Error = [string]$chosen.Error
        if (-not $result.Error) { $result.Error = '软件源里没有可用的版本信息' }
        # 提前返回也必须把原因说出来：调用方（菜单汇总 / CLI）只报失败条数，
        # 不打印就等于「直接显示失败 1」而没有任何线索。
        # -Quiet 时由调用方（依赖处理 / 更新流程）统一转述，这里不重复打印。
        if (-not $Quiet) {
            Write-Host ''
            Write-Host ('  失败: {0} 没有可安装的版本 —— {1}' -f [string]$Row['Name'], $result.Error) -ForegroundColor Red
            Write-Host '  可到「高级功能 → 管理软件源」里刷新软件源后重试；若提示某个来源出错，先修好那个软件源。' -ForegroundColor DarkGray
        }
        # -Quiet 时什么都没打印，标记为「未告知」，让调用方（依赖处理 / 更新流程）转述这条原因
        $result.FailureShown = (-not $Quiet)
        return $result
    }

    $entry = $chosen.Entry
    $sourceName = [string]$entry['Source']
    $plan = $entry['Plan']
    $result.Source = $sourceName

    # 与两个引擎同一口径：winst 自身缺失时自动安装、软件源里有新版本时自动更新
    if ((Get-EntryString -Entry $plan -Key 'id') -ine 'winst') {
        $null = Confirm-WinstSelf -Context $Context -Quiet:$Quiet
    }

    Show-WinstPlanDetail -Context $Context -Plan $plan -SourceName $sourceName

    $planTypeName = ([string](Get-EntryString -Entry $plan -Key 'type')).Trim().ToLowerInvariant()
    $isDownloadPlan = ($planTypeName -eq 'download')
    if ($isDownloadPlan) {
        Write-Host '    这是「仅下载软件包」类型的软件：只下载软件包到安装包位置，不安装到电脑。' -ForegroundColor DarkGray
        $ignoredOptions = @()
        if ($Force) { $ignoredOptions += '--force' }
        if ($Overwrite) { $ignoredOptions += '--overwrite' }
        if (@($Keep).Count -gt 0) { $ignoredOptions += '--keep' }
        if ($ignoredOptions.Count -gt 0) {
            if (Test-WinstMenuMode) {
                Write-Host '    提示: 仅下载软件包的软件只有「下载软件包」这一步，安装类选项已忽略。' -ForegroundColor DarkYellow
            } else {
                Write-Host ('    提示: 仅下载软件包的软件不适用 {0}，已忽略。' -f ($ignoredOptions -join ' / ')) -ForegroundColor DarkYellow
            }
            $Force = $false
            $Overwrite = $false
            $Keep = @()
        }
    }
    $downloadMode = [bool]$DownloadOnly -or $isDownloadPlan

    $forceInstall = [bool]$Force
    $actionText = '安装'
    if ($downloadMode) { $actionText = '下载' }

    # 本机已装版本 / 软件源版本：决定提示是「安装」还是「更新到 x.y ↑」
    $planVersion = Get-EntryString -Entry $plan -Key 'version'
    $installedVersion = ''
    $planId = Get-EntryString -Entry $plan -Key 'id'
    $stateNow = $null
    if ($planId) {
        $stateNow = (Read-WinstState -InstallRoot $Context.InstallRoot).State
        $ledgerNow = Get-WinstInstalledApp -State $stateNow -Id $planId
        if ($ledgerNow) { $installedVersion = Get-EntryString -Entry $ledgerNow -Key 'version' }
    }
    $isUpgrade = $false
    if (-not $downloadMode -and $installedVersion -and $planVersion) {
        if ((Compare-WinstVersion -A $planVersion -B $installedVersion) -gt 0) { $isUpgrade = $true }
    }

    if ($FilesOnly) {
        Write-Host '    仅更新文件：不改动环境变量 / PATH / 快捷方式（保留现有设置）' -ForegroundColor DarkYellow
    }

    # —— 依赖：先解析传递依赖里需要动作的部分，统一提示一次、随本体一并确认 ——
    $deps = Get-WinstInstallTargetDependencies -Context $Context -Plan $plan -PlanId $planId -State $stateNow `
        -SkipDependencies:$SkipDependencies -IsDownloadPlan:$isDownloadPlan
    $depSteps = @($deps.Steps)

    # 版本相同但配套文件有变化 → 先提示「附加文件有更新」，确认后只更新这些文件
    $companionInfo = $null
    if (-not $downloadMode -and -not $forceInstall -and $installedVersion -and $planVersion -and -not $isUpgrade) {
        $companionInfo = Get-WinstCompanionUpdateInfo -Context $Context -Plan $plan
        if ($companionInfo.CompanionsOnly) {
            Write-Host ('    附加文件有更新（{0} 个）: {1}' -f $companionInfo.ChangedCount, ($companionInfo.Names -join '、')) -ForegroundColor DarkYellow
        }
    }
    $companionOnlyPrompt = [bool]($companionInfo -and $companionInfo.CompanionsOnly)

    # 无法获取最新版本号的条目：取包照旧，但确认前把「远端有没有新包」提示给用户参考
    Write-WinstRemoteFreshnessHint -Context $Context -PkgDir $Context.PkgDir -Id $planId -Plan $plan

    if (-not $Yes) {
        $confirm = Show-WinstInstallTargetConfirm -Row $Row -ActionText $actionText -PlanVersion $planVersion `
            -InstalledVersion $installedVersion -IsUpgrade $isUpgrade -CompanionOnlyPrompt $companionOnlyPrompt `
            -CompanionInfo $companionInfo -FilesOnly:$FilesOnly
        if (-not $confirm.Proceed) {
            $result.Cancelled = $true
            return $result
        }
    }

    # —— 依赖先装 / 先更新（上面的统一确认已覆盖它）：任一依赖失败即中止本体安装 ——
    foreach ($step in @($depSteps)) {
        Write-Host ('  依赖: 正在处理「{0}」（{1}）…' -f [string]$step['Name'], [string]$step['ActionText']) -ForegroundColor Gray
        $depResult = Invoke-WinstInstallTarget -Context $Context -Row $step['Row'] -SkipDependencies -AutoPickSource `
            -Yes -DownloadOnly:$downloadMode -KillRunning:$KillRunning -Quiet:$Quiet `
            -FilesOnly:$FilesOnly -ForceSystemItems:$ForceSystemItems
        if ($depResult.Cancelled) {
            $result.Cancelled = $true
            return $result
        }
        if (-not $depResult.Ok -and -not $depResult.Skipped) {
            $depReason = [string]$depResult.Error
            if (-not $depReason) { $depReason = [string]$depResult.Message }
            if (-not $depReason) { $depReason = '未知原因' }
            $result.Error = ('依赖「{0}」处理失败（{1}），已中止本次安装。' -f [string]$step['Name'], $depReason)
            if (-not $Quiet) {
                Write-Host ('  失败: {0}' -f $result.Error) -ForegroundColor Red
                $result.FailureShown = $true
            }
            return $result
        }
    }

    $exec = Invoke-WinstInstallWithRetry -Context $Context -Plan $plan -SourceName $sourceName `
        -ForceInstall $forceInstall -Overwrite:$Overwrite -Keep $Keep -DownloadOnly:$DownloadOnly `
        -KillRunning:$KillRunning -Quiet:$Quiet -FilesOnly:$FilesOnly -ForceSystemItems:$ForceSystemItems `
        -Yes:$Yes -DownloadMode:$downloadMode
    $install = $exec.Install

    $result.Ok = $install.Ok
    $result.Skipped = $install.Skipped
    $result.Network = $install.Network
    $result.Message = $install.Message
    $result.Error = $install.Error
    $result.Version = $install.Version
    if ($install.Cancelled) { $result.Cancelled = $true }

    Write-WinstInstallTargetResult -Install $install -SkipReasonShown ([bool]$exec.SkipReasonShown) -Quiet:$Quiet
    # 失败分支一定有输出（无原因时也给兜底文案），因此失败即视为已告知，调用方不必再重复一遍；
    # -Quiet 时上面什么都不打印，留给调用方转述
    if (-not $result.Ok -and -not $result.Skipped -and -not $result.Cancelled) { $result.FailureShown = (-not $Quiet) }
    return $result
}