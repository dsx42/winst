#Requires -Version 5.1

function Resolve-WinstInstallDecision {
    <#
    .SYNOPSIS
        安装前决策矩阵：装 / 跳过 / 降级 / 窄更新 / 推迟。
    .DESCRIPTION
        版本一致 → 跳过或「仅配套文件更新」；本机更新 → 不自动降级；软件源没有版本号 → 要用户确认；
        版本号取自主包文件信息时 → 推迟到取包后再判（Defer）。命中的分支会把结论写进 $Result 并置 Return。
    .OUTPUTS
        立即返回时含 Return、Result，继续安装时含 Return、Defer、CompanionOnly、Detected。
    #>
    param(
        [hashtable]$Context,
        $Plan,
        [string]$Type,
        $Install,
        [string]$InstallDir,
        [string]$Id,
        [string]$DisplayName,
        [string]$Version,
        $Result,
        [switch]$Quiet,
        [switch]$Force,
        [switch]$DryRun,
        [switch]$Offline,
        [string]$PlanFreshState,
        [int]$CompanionDownloadCount,
        [switch]$CompanionsOnly,
        $PrimaryFilePlan,
        [switch]$IsDownloadType,
        $Ledger,
        [string]$SourceName
    )

    $deferVersionDecision = $false
    $detected = ''

    if ($IsDownloadType) {
        return @{ Return = $false; Defer = $false; CompanionOnly = $false; Detected = '' }
    }

    $detect = Get-WinstDetectedVersion -Context $Context -Plan $Plan -InstallDir $InstallDir
    $detectMethod = Get-EntryString -Entry (Get-EntryValue -Entry $Plan -Key 'detect' -Default $null) -Key 'method'
    if ($detect.Ok) { $detected = [string]$detect.Version }
    elseif ($Ledger -and @('registry', 'appx') -contains $detectMethod -and $detect.QuerySucceeded -and $detect.Found) {
        $ledgerVersion = Get-EntryString -Entry $Ledger -Key 'version'
        if ($ledgerVersion -and $ledgerVersion -ine 'unknown') { $detected = $ledgerVersion }
    }

    # 系统记录的完整查询确认未命中时，旧台账不能证明目标产品仍已安装；查询失败则明确中止。
    if (@('registry', 'appx') -contains $detectMethod -and -not [bool]$detect.QuerySucceeded) {
        $Result.Error = [string]$detect.Note
        if (-not $Result.Error) { $Result.Error = '无法完成系统安装记录查询，请排除查询错误后重试' }
        return @{ Return = $true; Result = $Result }
    }

    if ($detected -and $detected -ine 'unknown') {
        $hasTarget = [bool]$Version
        $cmp = 0
        if ($hasTarget) { $cmp = Compare-WinstVersion -A $detected -B $Version }

        # 包内取版且目标版本尚未登记时，待取包阶段给出读数后再比较。
        $deferVersionDecision = -not $Force -and -not $hasTarget -and (Get-EntryBool -Entry $Plan -Key 'versionFromPackage')
        if ($deferVersionDecision -and -not $Quiet) {
            if ($PlanFreshState -ieq 'changed') {
                Write-Host ('  {0} 本机已安装 {1}；远端有新包（文件比较），将重新下载安装包、取包后核对版本。' -f $DisplayName, $detected) -ForegroundColor DarkYellow
            } else {
                Write-Host ('  {0} 本机已安装 {1}；软件源里没有版本号（版本号取自主包文件信息），先取包核对版本再决定。' -f $DisplayName, $detected) -ForegroundColor DarkYellow
            }
        }

        # 版本一致：跳过安装，由用户决定是否强制重装
        if ($hasTarget -and $cmp -eq 0 -and -not $Force -and -not $deferVersionDecision) {
            $recordDir = $InstallDir
            if ($Type -eq 'installer') {
                $recordDir = Get-EntryString -Entry $detect -Key 'Location'
                if (-not $recordDir) { $recordDir = (Resolve-WinstActualInstallDir -Plan $Plan -AssumedDir $InstallDir).Dir }
                if ($Ledger) {
                    Sync-WinstInstallerDecisionPath -Context $Context -Plan $Plan -Id $Id -Ledger $Ledger -Quiet:$Quiet -ProbedDir $recordDir
                }
            }
            if (-not $Ledger) {
                Register-WinstExternalInstallRecord -Context $Context -Plan $Plan -Type $Type -InstallDir $recordDir `
                    -Id $Id -Version $detected -SourceName $SourceName -OldVersions @($detect.OldVersions) -LocationKnown
            }
            if ($CompanionDownloadCount -gt 0 -and $Ledger -and -not $DryRun) {
                if ($PrimaryFilePlan['ValidationError'] -or
                        ($PrimaryFilePlan['NeedDownload'] -and ($Offline -or $PrimaryFilePlan['ExpectedHash']))) {
                    $reason = [string]$PrimaryFilePlan['ValidationError']
                    if (-not $reason) { $reason = [string]$PrimaryFilePlan['Hint'] }
                    if (-not $reason) { $reason = [string]$PrimaryFilePlan['Reason'] }
                    $Result.Error = ('主包 {0} 无法复用，已停止配套文件更新：{1}' -f $PrimaryFilePlan['Name'], $reason)
                    $Result.Network = [bool]$PrimaryFilePlan['ValidationNetwork']
                    return @{ Return = $true; Result = $Result }
                }
            }
            $same = Resolve-WinstSameVersionAction -Install $Install -InstallDir $InstallDir -DisplayName $DisplayName `
                -Detected $detected -CompanionDownloadCount $CompanionDownloadCount -HasCompanionUpdate:$CompanionsOnly `
                -Ledger $Ledger -Result $Result -DryRun:$DryRun -Quiet:$Quiet
            if ($same.Return) { return $same }
            return @{ Return = $false; Defer = $false; CompanionOnly = $true; Detected = $detected }
        }

        if (-not $deferVersionDecision -and $hasTarget -and $cmp -lt 0) {
            # 软件源里是更新的版本 → 这是「更新」：直接安装（无需 --force）
            if (-not $Quiet) {
                Write-Host ('  发现新版本：已安装 {0}  →  {1}  ↑' -f $detected, $Version) -ForegroundColor Green
            }
        } elseif (-not $deferVersionDecision -and $hasTarget -and $cmp -gt 0 -and -not $Force) {
            return (Complete-WinstInstallSkip -Result $Result -Version $detected `
                -Message ('{0} 本机已安装 {1}，比软件源里的 {2} 更新{3}' -f $DisplayName, $detected, $Version, (Get-WinstForceHint -Kind 'downgrade')))
        } elseif (-not $hasTarget -and -not $Force -and -not $deferVersionDecision) {
            $unknown = '软件源里没有可用版本信息'
            if (-not $PrimaryFilePlan['NeedDownload']) { $unknown = '缓存版本未知' }
            return (Complete-WinstInstallSkip -Result $Result -Version $detected `
                -Message ('{0} 已安装（{1}），但{2}{3}' -f $DisplayName, $detected, $unknown, (Get-WinstForceHint -Kind 'continue')))
        }
    } elseif ($detect.Found -and -not $Force) {
        $Result.Ok = $true
        $Result.Skipped = $true
        $Result.Message = ('检测到 {0} 已经安装，但无法识别版本{1}' -f $DisplayName, (Get-WinstForceHint -Kind 'continue'))
        return @{ Return = $true; Result = $Result }
    }

    return @{ Return = $false; Defer = $deferVersionDecision; CompanionOnly = $false; Detected = $detected }
}
