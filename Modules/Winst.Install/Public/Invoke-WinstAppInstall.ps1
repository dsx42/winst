#Requires -Version 5.1

function Invoke-WinstAppInstall {
    <#
    .SYNOPSIS
        安装（或仅下载）单个软件：检测 → 下载 → 解压 / 安装 → 复制改名 → 环境 → 命令 → 检测 → 台账。
    .DESCRIPTION
        按七个阶段执行；`download` 类条目只下载不安装、不写台账。
        软件包下载一律走 FluxDown CLI（引擎缺失时先自动安装），不设 IWR 兜底。
        `versionFromPackage` 条目在「本机已装、软件源里又拿不到版本号」时不直接跳过：先取包，
        再按包内文件信息得到的版本补做决策矩阵。
        `-FilesOnly`（仅更新文件）跳过阶段 ④ 的写入：环境变量 / PATH 不动、快捷方式只修正已存在的，
        台账里原有的登记保持不动。
        默认（未指定时）按「设置 → 更新方式」执行：开启（默认「只更新文件」）时**已登记软件**（更新 / 重装）
        同样跳过阶段 ④，只有**首次安装**才补齐缺失项（已存在的保持不动）；
        `-ForceSystemItems` 强制完整落地（覆盖已存在项），忽略配置。
    .OUTPUTS
        @{ Ok; Skipped; Preview; Cancelled; Message; Version; InstallDir; Error; Network; Downloaded }
    #>
    param(
        [Parameter(Mandatory = $true)][hashtable]$Context,
        [Parameter(Mandatory = $true)]$Plan,
        [string]$SourceName = '',
        [switch]$Force,
        [switch]$Overwrite,
        [string[]]$Keep = @(),
        [switch]$DownloadOnly,
        [switch]$KillRunning,
        [switch]$Quiet,
        [switch]$FilesOnly,
        [switch]$ForceSystemItems
    )

    $result = @{
        Ok         = $false
        Skipped    = $false
        Preview    = $false
        Cancelled  = $false
        Message    = ''
        Version    = ''
        InstallDir = ''
        Error      = ''
        Network    = $false
        Downloaded = @()
    }

    $dryRun = [bool]((Get-WinstState -Name WinstOptions) -and (Get-WinstState -Name WinstOptions).DryRun)
    $offline = [bool]((Get-WinstState -Name WinstOptions) -and (Get-WinstState -Name WinstOptions).Offline)

    # —— 初始化：id / 类型 / 版本 / 目录 / 取包判定 / 台账 ——
    $info = Initialize-WinstInstallContext -Context $Context -Plan $Plan -DownloadOnly:$DownloadOnly -Quiet:$Quiet -Result $result
    if ($info.Error) { $result.Error = [string]$info.Error; return $result }
    $id = [string]$info.Id
    $displayName = [string]$info.DisplayName
    $type = [string]$info.Type
    $version = [string]$info.Version
    $installDir = [string]$info.InstallDir
    $pkgDir = [string]$info.PkgDir
    $install = $info.Install
    $files = @($info.Files)
    $versionFromPackage = [bool]$info.VersionFromPackage
    $versionFromCachedPackage = [bool]$info.VersionFromCachedPackage
    $planFreshState = [string]$info.PlanFreshState
    $freshMain = [bool]$info.FreshMain
    $isDownloadType = [bool]$info.IsDownloadType
    $prevEntry = $info.PrevEntry
    $plans = @($info.Plans)
    $needDownload = [bool]$info.NeedDownload
    $primaryTarget = [string]$info.PrimaryTarget
    $companionDownloadCount = [int]$info.CompanionDownloadCount
    $companionsOnly = [bool]$info.CompanionsOnly
    $ledger = $info.Ledger

    $decision = Resolve-WinstInstallDecision -Context $Context -Plan $Plan -Type $type -Install $install -InstallDir $installDir `
        -Id $id -DisplayName $displayName -Version $version -Result $result -Quiet:$Quiet -Force:$Force -DryRun:$dryRun `
        -VersionFromPackage:$versionFromPackage -FreshMain:$freshMain -PlanFreshState $planFreshState `
        -VersionFromCachedPackage:$versionFromCachedPackage -CompanionDownloadCount $companionDownloadCount `
        -CompanionsOnly:$companionsOnly -IsDownloadType:$isDownloadType -Ledger $ledger -SourceName $SourceName
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

    # --dry-run 一律在这里收口：预览不下载、不落盘、不写台账。
    # 之前只挡住「需要下载」的情况，主包命中缓存时（例如「只更新附加文件」或包早就下好）
    # needDownload=false，于是继续往下真的下载 / 解压 / 覆盖安装。
    if ($dryRun) {
        $result.Ok = $true
        $result.Preview = $true
        # 仅下载类型的软件只说「下载」，不说「安装」
        $previewAction = '安装'
        if ($type -eq 'download') { $previewAction = '下载' }
        if ($needDownload) {
            if ($primaryTarget -and (Test-Path -LiteralPath $primaryTarget -PathType Leaf)) {
                $result.Message = ('（预览）将{0} {1}' -f $previewAction, $displayName)
            } else {
                $result.Message = ('（预览）需要下载 {0}' -f $displayName)
            }
        } else {
            $result.Message = ('（预览）将{0} {1}（安装包已在缓存里，不需要下载）' -f $previewAction, $displayName)
        }
        if ($companionOnlyUpdate) {
            # 主包没变、只有附加文件要更新：预览说清「只动这几个文件」，别让用户以为要重装
            $result.Message = ('（预览）{0} 主包无变化，将只更新 {1} 个附加文件（不重装）' -f $displayName, $companionDownloadCount)
        }
        return $result
    }

    # —— 逐文件下载（含离线特例 / 引擎引导 / 失效地址重试 / 完整性校验）——
    $download = Invoke-WinstPackageDownloadLoop -Context $Context -Plans $plans -PkgDir $pkgDir -Id $id `
        -DisplayName $displayName -SourceName $SourceName -Version $version -Offline:$offline -Quiet:$Quiet
    if (-not $download.Ok) {
        $result.Error = [string]$download.Error
        $result.Network = [bool]$download.Network
        return $result
    }
    $result.Downloaded += @($download.Downloaded)
    $downloadedNames = @($download.Names)

    # 自动清理旧包
    Remove-WinstObsoletePackages -Context $Context -Id $id -Plans $plans -DownloadedAny ([bool]$download.Any) -Offline:$offline

    # versionFromPackage：清单里没有版本号时，刚下载完的主包就是版本来源（写进缓存索引，供后续阶段使用）
    $version = Update-WinstPlanVersionFromPackage -Context $Context -Plan $Plan -Plans $plans -PkgDir $pkgDir `
        -Version $version -VersionFromCachedPackage $versionFromCachedPackage -Quiet:$Quiet

    # 缓存索引：版本 + 文件名 + 每个包文件的校验码与 fileMeta
    Update-WinstPackageCacheIndex -Context $Context -Id $id -Plans $plans -PrevEntry $prevEntry `
        -Version $version -DownloadedNames $downloadedNames

    $primaryPath = ''
    if ($files.Count -gt 0) {
        $pn = Get-EntryString -Entry $files[0] -Key 'name'
        if (-not $pn) { $pn = Get-FileNameFromUrl -Url (Get-EntryString -Entry $files[0] -Key 'url') }
        if ($pn) { $primaryPath = Join-WinstPath $pkgDir $pn }
    }
    if (-not $primaryPath -or -not (Test-Path -LiteralPath $primaryPath -PathType Leaf)) {
        $result.Error = ('安装包不在缓存里：{0}' -f $displayName)
        return $result
    }

    # —— versionFromPackage 的推迟决策——
    $deferred = Resolve-WinstDeferredDecision -Context $Context -Plan $Plan -Type $type -Install $install -InstallDir $installDir `
        -Id $id -DisplayName $displayName -Version $version -Detected $detected -Result $result -Ledger $ledger `
        -CompanionDownloadCount $companionDownloadCount -Defer:$deferVersionDecision -Quiet:$Quiet -SourceName $SourceName
    if ($deferred.Return) { return $deferred.Result }
    if ($deferVersionDecision) { $companionOnlyUpdate = [bool]$deferred.CompanionOnly }
    if ($isDownloadType) {
        $result.Ok = $true
        $result.Version = $version
        # 仅下载类型的软件包里没有可安装的东西，措辞用「软件包」；-DownloadOnly 的普通软件仍叫「安装包」
        $packageNoun = '安装包'
        if ($type -eq 'download') { $packageNoun = '软件包' }
        # 版本号取自主包文件信息的条目：刚取到的包已经给出了版本号，一并说明（用户下载这类包就是为了知道版本）
        $versionNote = ''
        if ($versionFromPackage -and $version) { $versionNote = ('（版本 {0}）' -f $version) }
        # 报实际落地的那个文件（$primaryPath 已在上方校验存在），版本说明跟在路径之后
        $result.Message = ('{0} 的{1}已下载到 {2}{3}' -f $displayName, $packageNoun, $primaryPath, $versionNote)
        # 仅下载路径同样回写解析锁：包已到手 → 缓存里这份就是远端当前这份
        if ($versionFromPackage) {
            Update-WinstLockAfterDownload -Context $Context -SourceName $SourceName -Id $id -Version $version
        }
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
        $runningCheck = Confirm-WinstAppNotRunning -Context $Context -Plan $Plan -InstallDir $installDir -ExtraDirs $checkDirs `
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
    if ($companionOnlyUpdate) { $payloadMethod = 'companionOnly' }
    switch ($payloadMethod) {
        'companionOnly' { }
        'portable' {
            $payload = Install-WinstPortablePayload -Context $Context -Install $install -InstallDir $installDir `
                -PrimaryPath $primaryPath -Overwrite:$Overwrite -Keep $Keep -Quiet:$Quiet
            if (-not $payload.Ok) { $result.Error = [string]$payload.Error; return $result }
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
            $result.InstallDir = $installDir
        }
        default {
            $result.Error = ('不支持的安装方式：{0}' -f $method)
            return $result
        }
    }

    # —— 配套文件按 dest 落位 + 删除上次落位、这次不需要的旧文件（installer 的配套文件仅缓存）——
    $landing = Add-WinstCompanionFiles -Context $Context -Files $files -PkgDir $pkgDir -InstallDir $installDir `
        -Ledger $ledger -Method $method -Quiet:$Quiet
    if ($landing.Error) { $result.Error = [string]$landing.Error; return $result }
    $appliedFiles = @($landing.Files)
    $staleRemoved = @($landing.Removed)
    $staleDirs = @($landing.KeptDirs)

    # —— 仅配套文件更新：到这里就结束——不重跑复制 / 改名、不写环境变量 / PATH / 快捷方式、不跑 postInstall，
    # 也不改台账里的版本与系统项登记，只补 appliedFiles——
    if ($companionOnlyUpdate) {
        if ($ledger) {
            # appliedFiles 用流程开始时的条目做浅拷贝；落盘由 Save-WinstInstalledAppEntry 重读后只覆盖这一条
            $null = Update-WinstInstalledAppFields -InstallRoot $Context.InstallRoot `
                -Id $id -Entry $ledger -Fields @{ appliedFiles = $appliedFiles }
        }
        $updatedNames = @()
        foreach ($filePlan in $plans) {
            if ($filePlan['NeedDownload']) { $updatedNames += [string]$filePlan['Name'] }
        }
        $removedNote = ''
        if ($staleRemoved.Count -gt 0) { $removedNote = ('，删除 {0} 个旧文件（{1}）' -f $staleRemoved.Count, ($staleRemoved -join '、')) }
        if ($staleDirs.Count -gt 0) { $removedNote += ('，保留旧目录（{0}）' -f ($staleDirs -join '、')) }
        $result.Ok = $true
        $result.InstallDir = $installDir
        $result.Message = ('{0} {1}：主包无变化；已更新 {2} 个附加文件（{3}）{4}' -f $displayName, $detected, $updatedNames.Count, ($updatedNames -join '、'), $removedNote)
        if (-not $Quiet) { Write-Host ('  ' + $result.Message) -ForegroundColor Green }
        return $result
    }

    # —— ③ 复制 / 改名 ④ 环境变量 / PATH / 快捷方式 ⑤ 安装后命令 ——
    $system = Invoke-WinstApplySystemItems -Context $Context -Plan $Plan -InstallDir $installDir `
        -FilesOnly:$FilesOnly -ForceSystemItems:$ForceSystemItems -Ledger $ledger -Quiet:$Quiet
    if ($system.Error) {
        # 系统项在 postInstall 之前就已落地：这里直接返回会让台账里没有这些登记，
        # 卸载时回收不到（环境变量 / PATH / 快捷方式成为孤儿）。先把已落地的项写进台账再报错。
        try {
            Set-WinstInstallLedger -Context $Context -Id $id -Type $type -Plan $Plan `
                -InstallDir $installDir -Version $version -SourceName $SourceName `
                -SystemItems $system.Items -AppliedFiles $appliedFiles -OldVersions @()
        } catch {
            $result.Error = ('{0}（且写入安装台账失败：{1}）' -f [string]$system.Error, $_.Exception.Message)
            return $result
        }
        $result.Error = [string]$system.Error
        return $result
    }

    # —— ⑥ 版本检测 ——
    $final = Get-WinstInstallFinalVersion -Context $Context -Plan $Plan -InstallDir $installDir `
        -Version $version -Ledger $ledger -Quiet:$Quiet
    $finalVersion = [string]$final.Version

    # —— ⑦ 写台账 ——
    try {
        Set-WinstInstallLedger -Context $Context -Id $id -Type $type -Plan $Plan `
            -InstallDir $installDir -Version $finalVersion -SourceName $SourceName `
            -SystemItems $system.Items -AppliedFiles $appliedFiles -OldVersions @($final.OldVersions)
    } catch {
        $result.Error = ('{0} 的文件已落位，但写入安装台账失败：{1}' -f $displayName, $_.Exception.Message)
        return $result
    }

    # versionFromPackage 条目：主包（重新）取回并安装成功 → 缓存里这份就是远端当前这份，
    # 把解析锁里的远端新鲜度结论改写为 unchanged、版本对齐为本次读数——
    # 否则「已装软件 / 检查更新」在下次刷新前会一直显示下载前的旧结论「远端有新包」
    if ($versionFromPackage) {
        Update-WinstLockAfterDownload -Context $Context -SourceName $SourceName -Id $id -Version $finalVersion
    }

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
}
