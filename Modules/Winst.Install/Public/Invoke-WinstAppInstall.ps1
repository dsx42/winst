#Requires -Version 5.1

function Invoke-WinstAppInstall {
    <#
    .SYNOPSIS
        安装（或仅下载）单个软件：检测 → 下载 → 解压 / 安装 → 复制改名 → 环境 → 命令 → 检测 → 台账。
    .DESCRIPTION
        按七个阶段执行；`download` 类条目只下载不安装、不写台账。
        软件包由 FluxDown 取包；缺少可用服务与 CLI 时允许直接 HTTP 引导下载引擎。
        `versionFromPackage` 条目在「本机已装、软件源里又拿不到版本号」时不直接跳过：先取包，
        再按包内文件信息得到的版本补做决策矩阵。
        `-FilesOnly`（仅更新文件）跳过阶段 ④ 的写入：环境变量 / PATH 不动、快捷方式只修正已存在的，
        台账里原有的登记保持不动。
        默认（未指定时）按「设置 → 更新方式」执行：开启（默认「只更新文件」）时**已登记软件**（更新 / 重装）
        同样跳过阶段 ④，只有**首次安装**才补齐缺失项（已存在的保持不动）；
        `-ForceSystemItems` 强制完整落地（覆盖已存在项），忽略配置。
    .OUTPUTS
        @{ Ok; Skipped; Preview; Cancelled; Message; Version; Error; Network }
    #>
    param(
        [Parameter(Mandatory = $true)][hashtable]$Context,
        [Parameter(Mandatory = $true)]$Plan,
        [string]$SourceName,
        [switch]$Force,
        [switch]$Overwrite,
        [string[]]$Keep = @(),
        [switch]$DownloadOnly,
        [switch]$RequireCurrent,
        [switch]$KillRunning,
        [switch]$Quiet,
        [switch]$FilesOnly,
        [switch]$ForceSystemItems,
        [switch]$CompanionOnly
    )

    $result = @{
        Ok         = $false
        Skipped    = $false
        Preview    = $false
        Cancelled  = $false
        Message    = ''
        Version    = ''
        Error      = ''
        Network    = $false
        Downloaded = $false
    }

    $dryRun = [bool]((Get-WinstState -Name WinstOptions) -and (Get-WinstState -Name WinstOptions).DryRun)
    $offline = [bool]((Get-WinstState -Name WinstOptions) -and (Get-WinstState -Name WinstOptions).Offline)

    # —— 初始化：id / 类型 / 版本 / 目录 / 取包判定 / 台账 ——
    $packageLock = $null
    $previousInstallingIds = Get-WinstState -Name WinstInstallingAppIds
    try {
        if (-not $dryRun) {
            try { $packageLock = Enter-WinstPackageLock -PkgDir $Context.PkgDir -Id (Get-EntryString -Entry $Plan -Key 'id') }
            catch { $result.Error = $_.Exception.Message; return $result }
        }
        $info = Initialize-WinstInstallContext -Context $Context -Plan $Plan -DownloadOnly:$DownloadOnly -RequireCurrent:$RequireCurrent -Quiet:$Quiet
        if ($info.Error) { $result.Error = [string]$info.Error; return $result }
        $Plan = $info.Plan
        $id = [string]$info.Id
        $displayName = [string]$info.DisplayName
        $type = [string]$info.Type
        $version = [string]$info.Version
        $installDir = [string]$info.InstallDir
        $pkgDir = [string]$info.PkgDir
        $install = $info.Install
        $files = @($info.Files)
        $versionFromPackage = Get-EntryBool -Entry $Plan -Key 'versionFromPackage'
        $planFreshState = [string]$info.PlanFreshState
        $isDownloadType = [bool]$info.IsDownloadType
        $prevEntry = $info.PrevEntry
        $plans = @($info.Plans)
        $needDownload = [bool]$info.NeedDownload
        $primaryPath = [string]$plans[0]['Target']
        $companionDownloadCount = $info.CompanionNames.Count
        $companionsOnly = [bool]$info.CompanionsOnly
        $ledger = $info.Ledger

        $null = Set-WinstState -Name WinstInstallingAppIds -Value ($previousInstallingIds + @($id))
        $decision = Resolve-WinstInstallDecision -Context $Context -Plan $Plan -Type $type -Install $install -InstallDir $installDir `
            -Id $id -DisplayName $displayName -Version $version -Result $result -Quiet:$Quiet -Force:$Force -DryRun:$dryRun -Offline:$offline `
            -PlanFreshState $planFreshState -CompanionDownloadCount $companionDownloadCount `
            -CompanionsOnly:$companionsOnly -PrimaryFilePlan $plans[0] -IsDownloadType:$isDownloadType -Ledger $ledger -SourceName $SourceName
        if ($decision.Return) { return $decision.Result }
        $deferVersionDecision = [bool]$decision.Defer
        $companionOnlyUpdate = [bool]$decision.CompanionOnly
        $detected = [string]$decision.Detected

        # 版本号取自主包文件信息的条目：版本号要等包到手才知道，预览也说不清装哪个版本
        if ($dryRun -and $deferVersionDecision) {
            $result.Ok = $true
            $result.Preview = $true
            $result.Message = ('（预览）将先取包核对 {0} 的版本，再决定是否更新（本机已安装 {1}）' -f $displayName, $detected)
            return $result
        }

        # 预览在取包与落位之前结束；前置识别可能登记已存在的外部安装，边界见 CLI 文档。
        if ($dryRun) {
            $result.Ok = $true
            $result.Preview = $true
            # 仅下载类型的软件只说「下载」，不说「安装」
            $previewAction = '安装'
            if ($type -eq 'download') { $previewAction = '下载' }
            if ($needDownload) {
                if ($primaryPath -and (Test-Path -LiteralPath $primaryPath -PathType Leaf)) {
                    $result.Message = ('（预览）将{0} {1}' -f $previewAction, $displayName)
                } else {
                    $result.Message = ('（预览）需要下载 {0}' -f $displayName)
                }
            } else {
                $result.Message = ('（预览）将{0} {1}（安装包已在缓存里，不需要下载）' -f $previewAction, $displayName)
            }
            if (-not $plans[0]['NeedDownload']) {
                $cacheLabel = if ($version) { '缓存版本 ' + $version } else { '缓存版本未知' }
                $result.Message += ('（{0}）' -f $cacheLabel)
            }
            if ($companionOnlyUpdate) {
                # 主包没变、只有附加文件要更新：预览说清「只动这几个文件」，别让用户以为要重装
                $result.Message = ('（预览）{0} 主包无变化，将只更新 {1} 个附加文件（不重装）' -f $displayName, $companionDownloadCount)
            }
            return $result
        }

        # —— 逐文件下载（含离线特例 / 引擎引导 / 失效地址重试 / 完整性校验）——
        $download = Invoke-WinstPackageDownloadLoop -Context $Context -Plans $plans -PkgDir $pkgDir -Id $id `
            -DisplayName $displayName -SourceName $SourceName -Plan $Plan -Offline:$offline -Quiet:$Quiet -PrevEntry $prevEntry
        if (-not $download.Ok) {
            $result.Error = [string]$download.Error
            $result.Network = [bool]$download.Network
            $result.Cancelled = [bool]$download['Cancelled']
            if ($result.Cancelled) { $result.Message = ('已取消下载 {0}' -f $displayName) }
            return $result
        }
        $Plan = $download.Plan
        $plans = @($download.Plans)
        $files = @(Get-EntryArray -Entry $Plan.download -Key 'files')
        $primaryPath = [string]$plans[0]['Target']
        $downloadedNames = @($download.Names)
        if ($downloadedNames -contains $plans[0]['Name']) { $companionOnlyUpdate = $false }
        $result.Downloaded = $downloadedNames.Count -gt 0
        if (-not $Force -and $detected -and $detected -ine 'unknown' -and $version -cne $download.Version) {
            $deferVersionDecision = $true
        }
        $version = [string]$download.Version
        if (-not $isDownloadType) {
            try { $Plan = Get-WinstCachedInstallPlan -Context $Context -Plan $Plan -CachedVersion $version }
            catch { $result.Error = $_.Exception.Message; return $result }
            $install = Get-EntryValue -Entry $Plan -Key 'install'
        }

        Remove-WinstObsoletePackages -Context $Context -Id $id -Plans $plans -DownloadedAny $result.Downloaded
        $landingNames = @(($info.CompanionNames + $downloadedNames) | Select-Object -Unique)
        if (-not $primaryPath -or -not (Test-Path -LiteralPath $primaryPath -PathType Leaf)) {
            $result.Error = ('安装包不在缓存里：{0}' -f $displayName)
            return $result
        }

        if ($versionFromPackage -and $downloadedNames -contains $plans[0]['Name']) {
            Update-WinstLockAfterDownload -Context $Context -SourceName $SourceName -Plan $Plan -DownloadedMain $plans[0]
        }

        if ($deferVersionDecision) {
            $deferred = Resolve-WinstDeferredDecision -Context $Context -Plan $Plan -Type $type -Install $install -InstallDir $installDir `
                -Id $id -DisplayName $displayName -Version $version -Detected $detected -Result $result -Ledger $ledger `
                -CompanionDownloadCount $companionDownloadCount -Quiet:$Quiet -SourceName $SourceName
            if ($deferred.Return) { return $deferred.Result }
            $companionOnlyUpdate = [bool]$deferred.CompanionOnly
        }
        if ($CompanionOnly -and -not $companionOnlyUpdate) {
            $result.Error = '确认后安装计划已变化，请重新确认安装范围。'
            return $result
        }
        if ($isDownloadType) {
            $result.Ok = $true
            $result.Version = $version
            # 仅下载类型的软件包里没有可安装的东西，措辞用「软件包」；-DownloadOnly 的普通软件仍叫「安装包」
            $packageNoun = '安装包'
            if ($type -eq 'download') { $packageNoun = '软件包' }
            $versionNote = if ($version) { '（版本 {0}）' -f $version } else { '（缓存版本未知）' }
            # 报实际落地的那个文件（$primaryPath 已在上方校验存在），版本说明跟在路径之后
            $result.Message = ('{0} 的{1}已下载到 {2}{3}' -f $displayName, $packageNoun, $primaryPath, $versionNote)
            return $result
        }

        # —— 运行中检测：目标软件正在运行会锁住文件，导致解压 / 覆盖失败——
        # 仅配套文件更新不触碰主程序，跳过该检测
        if (-not $companionOnlyUpdate) {
            $checkDirs = @()
            if ($type -eq 'installer') {
                # 安装版进程归属按当前产品规则确认，旧台账可能保留名称相近软件的目录。
                $currentDir = (Resolve-WinstActualInstallDir -Plan $Plan -AssumedDir '').Dir
                if ($currentDir) { $checkDirs += $currentDir }
            } elseif ($ledger) {
                $ledgerDir = Get-EntryString -Entry $ledger -Key 'installDir'
                if ($ledgerDir) { $checkDirs += $ledgerDir }
            }
            $nonInteractive = [bool](((Get-WinstState -Name WinstOptions) -and (Get-WinstState -Name WinstOptions).Yes) -or (Test-WinstInputRedirected))
            $runningCheck = Confirm-WinstAppNotRunning -Plan $Plan -InstallDir $installDir -ExtraDirs $checkDirs `
                -Kill:$KillRunning -NonInteractive:$nonInteractive -Quiet:$Quiet
            if (-not $runningCheck.Ok) {
                if ($runningCheck.Cancelled) {
                    $result.Cancelled = $true
                    $result.Message = ('已取消安装 {0}' -f $displayName)
                    return $result
                }
                $result.Error = $runningCheck.Error
                return $result
            }
        }

        # —— ② 解压 / 安装 ——
        # 旧解析锁里单文件条目的 method 还是 exe（已更名为 file），先归一再分派
        $method = ConvertTo-WinstEntryType -Type (Get-EntryString -Entry $install -Key 'method')
        $payloadMethod = $method
        $postInstallCopyApplied = $false
        if ($companionOnlyUpdate) { $payloadMethod = 'companionOnly' }
        switch ($payloadMethod) {
            'companionOnly' { }
            'portable' {
                $payload = Install-WinstPortablePayload -Context $Context -Plan $Plan -Install $install -InstallDir $installDir `
                    -PrimaryPath $primaryPath -Overwrite:$Overwrite -Keep $Keep -Quiet:$Quiet
                if (-not $payload.Ok) { $result.Error = [string]$payload.Error; return $result }
                $postInstallCopyApplied = Get-EntryBool -Entry $payload -Key 'PostInstallCopyApplied'
            }
            'file' {
                $payload = Install-WinstFilePayload -InstallDir $installDir -PrimaryPath $primaryPath
                if (-not $payload.Ok) { $result.Error = [string]$payload.Error; return $result }
            }
            'installer' {
                $payload = Install-WinstInstallerPayload -Context $Context -Plan $Plan -Install $install -InstallDir $installDir `
                    -PrimaryPath $primaryPath -Ledger $ledger -Id $id -Quiet:$Quiet
                if (-not $payload.Ok) { $result.Error = [string]$payload.Error; return $result }
                $installDir = [string]$payload.InstallDir
            }
            default {
                $result.Error = ('不支持的安装方式：{0}' -f $method)
                return $result
            }
        }

        # —— 配套文件按 dest 落位（覆盖写入）+ 完整安装时删除上次落位、这次不需要的旧文件 ——
        # 仅配套文件更新只覆盖这次变化的附件，不删除安装目录里的任何其它文件
        $landing = Add-WinstCompanionFiles -Context $Context -Files $files -PkgDir $pkgDir -InstallDir $installDir `
            -Ledger $ledger -Method $method -CompanionOnly:$companionOnlyUpdate -Quiet:$Quiet -ChangedNames $landingNames
        if ($landing.Error) { $result.Error = [string]$landing.Error; return $result }
        $appliedFiles = @($landing.Files)
        $appliedFileVersions = Get-WinstAppliedFileVersions -Context $Context -Id $id -Plans $plans -Ledger $ledger -Landing $landing -CompanionOnly:$companionOnlyUpdate

        # —— 仅配套文件更新：到这里就结束——不重跑复制 / 改名、不写环境变量 / PATH / 快捷方式、不跑 postInstall，
        # 台账更新实际落位的附件信息，保留已装主包版本与系统项登记。
        if ($companionOnlyUpdate) {
            $fields = @{ appliedFiles = $appliedFiles; appliedFileRules = $landing.Rules; appliedFileVersions = $appliedFileVersions }
            $null = Update-WinstInstalledAppFields -InstallRoot $Context.InstallRoot -Id $id -Entry $ledger -Fields $fields
            $updatedNames = @($landing.UpdatedNames)
            $result.Ok = $true
            $result.Message = ('{0} {1}：仅更新了 {2} 个附加文件（{3}）' -f $displayName, $detected, $updatedNames.Count, ($updatedNames -join '、'))
            if ($method -eq 'installer') {
                $result.Message = ('{0} {1}：仅刷新了缓存中的 {2} 个配套文件（{3}）' -f $displayName, $detected, $downloadedNames.Count, ($downloadedNames -join '、'))
            }
            return $result
        }

        # —— ③ 复制 / 改名 ④ 环境变量 / PATH / 快捷方式 ⑤ 安装后命令 ——
        $system = Invoke-WinstApplySystemItems -Context $Context -Plan $Plan -InstallDir $installDir `
            -FilesOnly:$FilesOnly -ForceSystemItems:$ForceSystemItems -Ledger $ledger -Quiet:$Quiet -SkipCopy:$postInstallCopyApplied
        $final = Get-WinstInstallFinalVersion -Context $Context -Plan $Plan -InstallDir $installDir `
            -Version $version -Ledger $ledger -Quiet:$Quiet
        $finalVersion = [string]$final.Version
        # 系统项失败时也要登记已经落地的部分，以便卸载时回收。
        try {
            Set-WinstInstallLedger -Context $Context -Id $id -Type $type -Plan $Plan `
                -InstallDir $installDir -Version $finalVersion -SourceName $SourceName `
                -SystemItems $system.Items -AppliedFiles $appliedFiles -AppliedFileRules $landing.Rules -AppliedFileVersions $appliedFileVersions `
                -OldVersions @($final.OldVersions)
        } catch {
            if ($system.Error) {
                $result.Error = ('{0}（且写入安装台账失败：{1}）' -f [string]$system.Error, $_.Exception.Message)
                return $result
            }
            $result.Error = ('{0} 的文件已落位，但写入安装台账失败：{1}' -f $displayName, $_.Exception.Message)
            return $result
        }

        if ($system.Error) { $result.Error = [string]$system.Error; return $result }

        $result.Ok = $true
        $result.Version = $finalVersion
        $result.Message = Format-WinstInstallResultMessage -Plan $Plan -Method $method -InstallDir $installDir `
            -Version $finalVersion -SystemItemsSkipped ([bool]$system.Skipped) -FilesOnly:$FilesOnly
        # 安装器升级后旧版本可能仍在系统里：装完就提示，别等用户下次打开「已装软件」才发现
        $oldVersionText = Format-WinstOldVersionText -OldVersions @($final.OldVersions)
        if ($oldVersionText -and -not $Quiet) {
            Write-Host ('    提示: 本机还并存旧版本 {0}，可在「已装软件」的详情里清理。' -f $oldVersionText) -ForegroundColor DarkYellow
        }
        return $result
    } finally {
        if ($null -ne $packageLock) { $packageLock.Dispose() }
        $null = Set-WinstState -Name WinstInstallingAppIds -Value $previousInstallingIds
    }
}
