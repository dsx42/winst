#Requires -Version 5.1

function Invoke-WinstUpdateEntry {
    <#
    .SYNOPSIS
        检查一条已安装软件的来源与版本，按请求报告或执行更新。
    .OUTPUTS
        单条更新结果，含最终动作及原因。
    #>
    param([hashtable]$Context, [string]$Id, $Ledger, $RowById, [switch]$Check, [switch]$DownloadOnly,
        [switch]$Force, [switch]$Yes, [switch]$Quiet, [switch]$FilesOnly,
        [switch]$ForceSystemItems, [switch]$AllTargets, [string]$SourceName, [hashtable]$SourceLookup)

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
        $entryResult.Action = 'unknown'
        $entryResult.Message = '软件源里没有这个软件'
        Write-WinstUpdateNoRowHint -DisplayName $displayName -Check:$Check -Quiet:$Quiet
        return $entryResult
    }

    # 显式来源必须可执行，不能被后续选择器悄悄换成其它来源。
    if ($SourceName) {
        $specified = @($row['Sources'] | Where-Object { [string]$_['Source'] -ieq $SourceName })
        if ($specified.Count -eq 0 -or -not $specified[0]['Ok'] -or -not $specified[0]['Plan']) {
            $entryResult.Action = 'failed'
            $reason = '没有可用的安装计划'
            if ($specified.Count -gt 0 -and [string]$specified[0]['Error']) { $reason = [string]$specified[0]['Error'] }
            $entryResult.Message = ('指定软件源「{0}」不可用：{1}' -f $SourceName, $reason)
            if (-not $Quiet) { Write-Host ('  {0}: {1}' -f $displayName, $entryResult.Message) -ForegroundColor Red }
            return $entryResult
        }
        $probeEntry = $specified[0]
        $row = Copy-WinstObjectShallow -InputObject $row
        $row['Sources'] = @($probeEntry)
    } else {
        $probeEntry = Get-WinstRowBestPlanEntry -Row $row
        $origin = Get-EntryString -Entry $ledger -Key 'manifestOrigin'
        if ($origin) {
            foreach ($candidate in @($row['Sources'])) {
                if ([string]$candidate['Source'] -ieq $origin -and $candidate['Ok'] -and $candidate['Plan']) {
                    $probeEntry = $candidate
                    break
                }
            }
        }
    }

    # 先按当前来源的身份规则回读系统记录。
    $probeMethod = ''
    if ($probeEntry) {
        $probePlan = Get-EntryValue -Entry $probeEntry -Key 'Plan' -Default $null
        $probeMethod = Get-EntryString -Entry (Get-EntryValue -Entry $probePlan -Key 'detect' -Default $null) -Key 'method'
        if (@('registry', 'appx') -contains $probeMethod) {
            $probe = Get-WinstDetectedVersion -Context $Context -Plan $probePlan -InstallDir (Get-EntryString -Entry $ledger -Key 'installDir')
            if (-not [bool]$probe.QuerySucceeded) {
                if ($Check) {
                    $entryResult.Action = 'unknown'
                } else {
                    $entryResult.Action = 'failed'
                }
                $entryResult.Message = [string]$probe.Note
                if (-not $entryResult.Message) { $entryResult.Message = '无法完成系统安装记录查询，请排除查询错误后重试' }
                if (-not $Quiet) { Write-Host ('  {0}: {1}' -f $displayName, $entryResult.Message) -ForegroundColor Yellow }
                return $entryResult
            }
            if ($probe.Ok) {
                $installedVersion = [string]$probe.Version
            } elseif (-not $probe.Found) {
                # 完整查询确认目标身份不存在时，才丢弃旧台账版本。
                $installedVersion = ''
            } elseif ((-not $installedVersion -or $installedVersion -ieq 'unknown') -and -not $Force -and -not $DownloadOnly) {
                # 身份仍在但版本不可读时，不能因版本未知而自动强制重装。
                if ($Check) {
                    $entryResult.Action = 'unknown'
                } else {
                    $entryResult.Action = 'skipped'
                }
                $entryResult.Message = ('系统记录中存在该软件，但无法识别版本，且台账里没有可用版本{0}' -f (Get-WinstForceHint -Kind 'continue'))
                if (-not $Quiet) { Write-Host ('  {0}: {1}' -f $displayName, $entryResult.Message) -ForegroundColor Yellow }
                return $entryResult
            }
            $entryResult.Installed = $installedVersion
        }
    }

    # 已安装版本未知时先尝试修复安装记录：用软件源里最新解析的检测定义重新识别一次并更正台账。
    # 只有 registry / appx 才有「按系统记录确认身份」这一步，其它检测方式重跑同一套规则没有意义；
    # 预览模式跳过修复。修复失败保留查询结果，不以旧台账证明软件仍存在。
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
    # 检查与执行固定使用同一来源，比较结果和实际安装计划必须对应。
    $chosen = $probeEntry
    if (-not $SourceName) {
        $chosen = Get-WinstDefaultUpdateSource -Lookup $SourceLookup -Context $Context -Row $row -Ledger $ledger -InstalledVersion $installedVersion
        if ($chosen) {
            if (-not $Quiet -and $origin -and [string]$chosen['Source'] -ine $origin) {
                Write-Host ('  提示: 安装来源「{0}」不可用或没有已确认的更新，改用软件源「{1}」。' -f $origin, [string]$chosen['Source']) -ForegroundColor DarkYellow
            }
            if (@($row['Sources']).Count -ne 1) {
                $row = Copy-WinstObjectShallow -InputObject $row
                $row['Sources'] = @($chosen)
            }
        }
    }

    if (-not $chosen) {
        $entryResult.Action = 'unknown'
        $entryResult.Message = '软件源里没有可用的版本信息（清单有误 / 不可用）'
        $entryResult.ResolutionError = $true
        if (-not $Quiet) {
            Write-Host ''
            Write-Host ('  {0}: 软件源里没有可用的版本信息（清单有误 / 不可用），无法更新；可到「高级功能 → 管理软件源」刷新软件源后重试。' -f $displayName) -ForegroundColor Red
        }
        return $entryResult
    }

    $snap = Get-WinstUpdateEntrySnapshot -Chosen $chosen -InstalledVersion $installedVersion
    $latest = [string]$snap.Latest
    $entryResult.Latest = $latest
    $entryResult.LatestSource = [string]$snap.LatestSource
    if ($snap.VersionFromPackage -and (-not $latest -or -not $snap.Comparable)) {
        $verdict = Get-WinstUpdateVerdict -VersionFromPackage $true -RemoteFresh $snap.RemoteFresh `
            -BestVersion $latest -CurrentVersion $installedVersion
        if ($Check -or ($AllTargets -and -not $Force -and -not $DownloadOnly -and -not $verdict.HasUpdate)) {
            $entryResult.Action = if ($verdict.HasUpdate) { 'check' } else { 'unknown' }
            $entryResult.Message = [string]$verdict.Hint
            if (-not $Quiet) { Write-Host ('  {0}: {1}。' -f $displayName, $entryResult.Message) -ForegroundColor DarkYellow }
            return $entryResult
        }
    } elseif (-not $latest -and $Check) {
        $entryResult.Action = 'check'
        $entryResult.Message = '软件源里没有可用的版本信息'
        if (-not $Quiet) { Write-Host ('  {0}: 无法比较版本（{1}），按软件源里的定义更新。' -f $displayName, $entryResult.Message) -ForegroundColor DarkYellow }
        return $entryResult
    }
    if ($Check) {
        Write-WinstUpdateCheckEntry -Context $Context -Plan $chosen['Plan'] -Snap $snap -EntryResult $entryResult `
            -InstalledVersion $installedVersion -DisplayName $displayName -Quiet:$Quiet
        return $entryResult
    }

    Invoke-WinstUpdateExecuteEntry -Context $Context -Id $Id -Row $row -Ledger $ledger -Snap $snap `
        -EntryResult $entryResult -InstalledVersion $installedVersion -DisplayName $displayName `
        -DownloadOnly:$DownloadOnly -Force:$Force -Yes:$Yes `
        -FilesOnly:$FilesOnly -ForceSystemItems:$ForceSystemItems

    return $entryResult
}
