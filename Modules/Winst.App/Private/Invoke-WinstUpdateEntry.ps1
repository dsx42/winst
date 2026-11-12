#Requires -Version 5.1

function Invoke-WinstUpdateEntry {
    <#
    .SYNOPSIS
        处理一条软件：未安装提示 → 取来源与版本 → 仅检查报告 或 执行更新。
    .OUTPUTS
        @{ Entries; Installed; DownloadOnlySkipped; RefreshState }
    #>
    param([hashtable]$Context, [string]$Id, $State, $RowById, [switch]$Check, [switch]$DownloadOnly,
        [switch]$Force, [switch]$Yes, [switch]$Quiet, [bool]$AutoPick = $false, [switch]$FilesOnly,
        [switch]$ForceSystemItems, [string]$SourceName = '', [hashtable]$Result)

    $ledger = Get-WinstInstalledApp -State $State -Id $Id
    if (-not $ledger) {
        $skip = Write-WinstUpdateMissingEntry -Id $Id -RowById $RowById -Result $Result -SourceName $SourceName
        return @{ Entries = @(); Installed = $false; DownloadOnlySkipped = [bool]$skip.DownloadOnly; RefreshState = $false }
    }

    $installedVersion = Get-EntryString -Entry $ledger -Key 'version'
    $displayName = $Id
    $row = $null
    if ($RowById.Contains($Id)) { $row = $RowById[$Id] }
    if ($row) {
        $rowName = Get-EntryString -Entry $row -Key 'Name'
        if ($rowName) { $displayName = $rowName }
    }

    $entryResult = New-WinstUpdateEntryResult -Id $Id -Name $displayName -Installed $installedVersion

    if (-not $row) {
        # 软件源里没有这个软件：既无从比较版本，也没有可安装的定义 → 一律跳过（不更新、不报错），
        # 只在检查时把它列进「无法比较」，提示用户去刷新软件源或补充定义。
        $Result.Unknown++
        $entryResult.Action = 'unknown'
        $entryResult.Message = '软件源里没有这个软件'
        Write-WinstUpdateNoRowHint -DisplayName $displayName -Check:$Check -Quiet:$Quiet
        return @{ Entries = @($entryResult); Installed = $true; DownloadOnlySkipped = $false; RefreshState = $false }
    }

    # 显式来源必须可执行，不能被后续选择器悄悄换成其它来源。
    if ($SourceName) {
        $specified = @($row['Sources'] | Where-Object { [string]$_['Source'] -ieq $SourceName })
        if ($specified.Count -eq 0 -or -not $specified[0]['Ok'] -or -not $specified[0]['Plan']) {
            $Result.Failed++
            $entryResult.Action = 'failed'
            $reason = '没有可用的安装计划'
            if ($specified.Count -gt 0 -and [string]$specified[0]['Error']) { $reason = [string]$specified[0]['Error'] }
            $entryResult.Message = ('指定软件源「{0}」不可用：{1}' -f $SourceName, $reason)
            if (-not $Quiet) { Write-Host ('  {0}: {1}' -f $displayName, $entryResult.Message) -ForegroundColor Red }
            return @{ Entries = @($entryResult); Installed = $true; DownloadOnlySkipped = $false; RefreshState = $false }
        }
        $sourceRow = [ordered]@{}
        foreach ($key in $row.Keys) { $sourceRow[$key] = $row[$key] }
        $sourceRow['Sources'] = @($specified[0])
        $row = $sourceRow
    }

    # 先按当前来源的身份规则回读系统记录，避免过期台账中的其它产品 / 主系列版本挡住更新。
    $probeEntry = Get-WinstRowBestPlanEntry -Row $row
    if ($SourceName) {
        foreach ($candidate in @($row['Sources'])) {
            if ([string]$candidate['Source'] -ieq $SourceName -and $candidate['Ok']) { $probeEntry = $candidate; break }
        }
    } elseif (Get-EntryString -Entry $ledger -Key 'manifestOrigin') {
        foreach ($candidate in @($row['Sources'])) {
            if ([string]$candidate['Source'] -ieq (Get-EntryString -Entry $ledger -Key 'manifestOrigin') -and $candidate['Ok']) { $probeEntry = $candidate; break }
        }
    }
    $probeMethod = ''
    if ($probeEntry) {
        $probePlan = Get-EntryValue -Entry $probeEntry -Key 'Plan' -Default $null
        $probeMethod = Get-EntryString -Entry (Get-EntryValue -Entry $probePlan -Key 'detect' -Default $null) -Key 'method'
        if (@('registry', 'appx') -contains $probeMethod) {
            $probe = Get-WinstDetectedVersion -Context $Context -Plan $probePlan -InstallDir (Get-EntryString -Entry $ledger -Key 'installDir')
            if (-not [bool]$probe.QuerySucceeded) {
                if ($Check) {
                    $Result.Unknown++
                    $entryResult.Action = 'unknown'
                } else {
                    $Result.Failed++
                    $entryResult.Action = 'failed'
                }
                $entryResult.Message = [string]$probe.Note
                if (-not $entryResult.Message) { $entryResult.Message = '无法完成系统安装记录查询，请排除查询错误后重试' }
                if (-not $Quiet) { Write-Host ('  {0}: {1}' -f $displayName, $entryResult.Message) -ForegroundColor Yellow }
                return @{ Entries = @($entryResult); Installed = $true; DownloadOnlySkipped = $false; RefreshState = $false }
            }
            if ($probe.Ok) {
                $installedVersion = [string]$probe.Version
            } elseif (-not $probe.Found) {
                # 完整查询确认目标身份不存在时，才丢弃旧台账版本。
                $installedVersion = ''
            } elseif ((-not $installedVersion -or $installedVersion -ieq 'unknown') -and -not $Force -and -not $DownloadOnly) {
                # 身份仍在但版本不可读时，不能因版本未知而自动强制重装。
                if ($Check) {
                    $Result.Unknown++
                    $entryResult.Action = 'unknown'
                } else {
                    $Result.Skipped++
                    $entryResult.Action = 'skipped'
                }
                $entryResult.Message = ('系统记录中存在该软件，但无法识别版本，且台账里没有可用版本{0}' -f (Get-WinstForceHint -Kind 'continue'))
                if (-not $Quiet) { Write-Host ('  {0}: {1}' -f $displayName, $entryResult.Message) -ForegroundColor Yellow }
                return @{ Entries = @($entryResult); Installed = $true; DownloadOnlySkipped = $false; RefreshState = $false }
            }
            $entryResult.Installed = $installedVersion
        }
    }

    # 已安装版本未知时先尝试修复安装记录：用软件源里最新解析的检测定义重新识别一次并更正台账。
    # 只有 registry / appx 才有「按系统记录确认身份」这一步，其它检测方式重跑同一套规则没有意义；
    # 修复只写台账（--dry-run 跳过）。修复失败保留查询结果，不以旧台账证明软件仍存在。
    $installedVersionUnknown = (-not $installedVersion -or $installedVersion -ieq 'unknown')
    if ($installedVersionUnknown -and @('registry', 'appx') -contains $probeMethod -and
        -not [bool]((Get-WinstState -Name WinstOptions) -and (Get-WinstState -Name WinstOptions).DryRun)) {
        try {
            $synced = Sync-WinstInstalledRecord -Context $Context -Id $Id
        } catch {
            $synced = $null
        }
        if ($synced -and $synced.Ok -and $synced.Changed) {
            $ledger = Get-WinstInstalledApp -State (Read-WinstState -InstallRoot $Context.InstallRoot).State -Id $Id
            $repairedVersion = Get-EntryString -Entry $ledger -Key 'version'
            if ($repairedVersion -and $repairedVersion -ine 'unknown') {
                $installedVersion = $repairedVersion
                $entryResult.Installed = $installedVersion
                if (-not $Quiet) {
                    Write-Host ('  {0}: 安装记录已修复，当前版本 {1}。' -f $displayName, $repairedVersion) -ForegroundColor DarkGray
                }
            }
        } elseif ($synced -and -not $synced.Ok -and -not $Quiet -and [string]$synced.Error) {
            Write-Host ('  {0}: 修复安装记录未完成 —— {1}' -f $displayName, [string]$synced.Error) -ForegroundColor DarkYellow
        }
    }
    $snap = Get-WinstUpdateEntrySnapshot -Context $Context -Row $row -Ledger $ledger -InstalledVersion $installedVersion
    # 检查与执行固定使用同一来源，比较结果和实际安装计划必须对应。
    $sorted = Sort-WinstRowSources -Context $Context -Row $row -InstalledVersion $installedVersion
    $chosen = @($sorted['Sources'] | Where-Object { $_['Ok'] -and $_['Plan'] } | Select-Object -First 1)
    if (-not $SourceName -and $snap.OriginUsable) {
        $otherHasNewer = [bool]($snap.Comparable -and $snap.Latest -and $snap.LatestSource -ine $snap.OriginName -and $snap.Cmp -gt 0)
        if ($snap.OriginNewer -or -not $snap.OriginVersion -or -not $otherHasNewer) {
            $chosen = @($snap.OriginEntry)
        } else {
            $chosen = @($row['Sources'] | Where-Object { [string]$_['Source'] -ieq $snap.LatestSource -and $_['Ok'] -and $_['Plan'] } | Select-Object -First 1)
        }
    }
    if ($chosen.Count -gt 0) {
        if (-not $Quiet -and -not $SourceName -and $snap.OriginName -and [string]$chosen[0]['Source'] -ine $snap.OriginName) {
            Write-Host ('  提示: 安装来源「{0}」不可用或没有更新，改用软件源「{1}」。' -f $snap.OriginName, [string]$chosen[0]['Source']) -ForegroundColor DarkYellow
        }
        $sourceRow = [ordered]@{}
        foreach ($key in $row.Keys) { $sourceRow[$key] = $row[$key] }
        $sourceRow['Sources'] = @($chosen[0])
        $row = $sourceRow
        $snap = Get-WinstUpdateEntrySnapshot -Context $Context -Row $row -Ledger $ledger -InstalledVersion $installedVersion
    }
    $latest = [string]$snap.Latest
    $latestSource = [string]$snap.LatestSource

    if (-not $latest -and -not $snap.HasUsableSource) {
        $Result.Unknown++
        $entryResult.Action = 'unknown'
        $entryResult.Message = '软件源里没有可用的版本信息（清单有误 / 不可用）'
        $entryResult.ResolutionError = $true
        if (-not $Quiet) {
            Write-Host ''
            Write-Host ('  {0}: 软件源里没有可用的版本信息（清单有误 / 不可用），无法更新；可到「高级功能 → 管理软件源」刷新软件源后重试。' -f $displayName) -ForegroundColor Red
        }
        return @{ Entries = @($entryResult); Installed = $true; DownloadOnlySkipped = $false; RefreshState = $false }
    }

    if (-not $latest) {
        $unknown = Get-WinstUpdateUnknownText -Snap $snap
        if ($snap.VersionFromPackage) {
            # 三条件满足 = 远端无新包 + 已下载安装包有版本号 + 已安装版本不低于包版本
            # → 检查时判「已是最新」；执行时只有未指定强制重装才跳过。
            # 先看附加文件：主包没变但附件变了，要单列「附加文件有更新」并允许只更新这些文件。
            $upToDate = Test-WinstUpdateUpToDateByPackage -Snap $snap -InstalledVersion $installedVersion
            if ($upToDate.UpToDate -and ($Check -or -not $Force)) {
                if ($upToDate.Newer) {
                    $Result.Unknown++
                    $entryResult.Action = 'newer'
                    $entryResult.Latest = [string]$snap.CachedPackageVersion
                    $entryResult.PackageVersion = [string]$snap.CachedPackageVersion
                    $entryResult.Message = '本机版本比已下载的安装包更新，不自动降级'
                    if (-not $Quiet) { Write-Host ('  {0}: {1}（本机 {2}，安装包 {3}）。' -f $displayName, $entryResult.Message, $installedVersion, $snap.CachedPackageVersion) -ForegroundColor DarkYellow }
                    return @{ Entries = @($entryResult); Installed = $true; DownloadOnlySkipped = $false; RefreshState = $false }
                }
                $companionInfo = Get-WinstRowCompanionInfo -Context $Context -Row $row
                if ($companionInfo -and $companionInfo.Error) { throw ('附加文件检查失败：{0}' -f $companionInfo.Error) }
                $companionsChanged = [bool]($companionInfo -and $companionInfo.CompanionsOnly)
                if ($companionsChanged) {
                    if ($Check) {
                        $Result.Updatable++
                        $entryResult.Action = 'files'
                        $entryResult.Message = ('附加文件有更新（{0} 个）' -f [int]$companionInfo.ChangedCount)
                        $entryResult.CompanionCount = [int]$companionInfo.ChangedCount
                        $entryResult.CompanionNames = @($companionInfo.Names)
                        $entryResult.Latest = [string]$snap.CachedPackageVersion
                        $entryResult.PackageVersion = [string]$snap.CachedPackageVersion
                        $entryResult.RemoteFresh = [string]$snap.RemoteFresh
                        return @{ Entries = @($entryResult); Installed = $true; DownloadOnlySkipped = $false; RefreshState = $false }
                    }
                    # 非检查（执行更新）且附件有变化：不在这里返回，交给安装侧走「仅附件更新」
                } else {
                    $Result.UpToDate++
                    $entryResult.Action = 'latest'
                    $entryResult.Latest = [string]$snap.CachedPackageVersion
                    $entryResult.PackageVersion = [string]$snap.CachedPackageVersion
                    $entryResult.RemoteFresh = [string]$snap.RemoteFresh
                    $shownVersion = $installedVersion
                    $basisNote = '远端无新包，与已下载的安装包一致'
                    if (-not $Quiet) {
                        Write-Host ('  {0}: 已是最新版本（{1}；{2}）。' -f $displayName, $shownVersion, $basisNote) -ForegroundColor Gray
                    }
                    return @{ Entries = @($entryResult); Installed = $true; DownloadOnlySkipped = $false; RefreshState = $false }
                }
            }
        }
        if ($Check) {
            $Result.Updatable++
            $entryResult.Action = 'check'
            $entryResult.Message = [string]$unknown.Reason
            if ($snap.VersionFromPackage) {
                $entryResult.PackageVersion = [string]$snap.CachedPackageVersion
                $entryResult.RemoteFresh = [string]$snap.RemoteFresh
                if ($snap.RemoteFresh -ieq 'unchanged' -and $snap.CachedPackageVersion) {
                    $entryResult.Latest = [string]$snap.CachedPackageVersion
                }
            }
            Write-WinstUpdateCheckUnknownLine -DisplayName $displayName -InstalledVersion $installedVersion -Snap $snap `
                -Reason ([string]$unknown.Reason) -ActionText ([string]$unknown.Action) -Quiet:$Quiet
            return @{ Entries = @($entryResult); Installed = $true; DownloadOnlySkipped = $false; RefreshState = $false }
        }
        if (-not $Quiet) {
            Write-Host ('  {0}: 无法比较版本（{1}），{2}。' -f $displayName, [string]$unknown.Reason, [string]$unknown.Action) -ForegroundColor DarkYellow
        }
    }

    $entryResult.Latest = $latest
    $entryResult.LatestSource = $latestSource

    if ($Check) {
        Write-WinstUpdateCheckEntry -Context $Context -Row $row -Snap $snap -EntryResult $entryResult `
            -InstalledVersion $installedVersion -DisplayName $displayName -Result $Result -Quiet:$Quiet
        return @{ Entries = @($entryResult); Installed = $true; DownloadOnlySkipped = $false; RefreshState = $false }
    }

    $exec = Invoke-WinstUpdateExecuteEntry -Context $Context -Id $Id -Row $row -Ledger $ledger -Snap $snap `
        -EntryResult $entryResult -InstalledVersion $installedVersion -DisplayName $displayName `
        -DownloadOnly:$DownloadOnly -Force:$Force -Yes:$Yes -Quiet:$Quiet -AutoPick $AutoPick `
        -FilesOnly:$FilesOnly -ForceSystemItems:$ForceSystemItems -Result $Result

    return @{ Entries = @($entryResult); Installed = $true; DownloadOnlySkipped = $false; RefreshState = [bool]$exec.RefreshState }
}
