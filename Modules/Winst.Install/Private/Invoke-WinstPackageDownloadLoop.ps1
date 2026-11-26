#Requires -Version 5.1

function Invoke-WinstPackageDownloadLoop {
    <#
    .SYNOPSIS
        按清单逐个校验、复用或替换缓存包，并将已完成文件及主包版本写入索引。
    #>
    param([hashtable]$Context, $Plan, $Plans, [string]$PkgDir, [string]$Id, [string]$DisplayName,
        [string]$SourceName, [switch]$Offline, [switch]$Quiet, [switch]$Bootstrap, $PrevEntry, [switch]$Inspect)

    $downloadedNames = @()
    $retries = @{}
    $downloadDir = Join-WinstPath $PkgDir 'winst-download'
    $Bootstrap = $Bootstrap -or ($Id -ceq (Get-WinstDownloadEngineId))
    $engineChecked = $false
    if (-not $SourceName) { $SourceName = Get-EntryString -Entry $Plan -Key 'manifestOrigin' }
    :downloadPlan while ($true) {
        $records = Get-WinstDownloadTaskRecords -DestDir $downloadDir
        foreach ($file in $Plans) {
            $pending = $records.Contains($file.Name)
            if (-not $pending -and $file.Name -and (Test-Path -LiteralPath $downloadDir -PathType Container)) {
                $failed = Join-WinstPath (Join-WinstPath (Join-WinstPath $downloadDir '.local') $file.Name) 'failed'
                $pending = Test-Path -LiteralPath $failed -PathType Container
            }
            if ($pending) { $file['NeedDownload'] = $true }
        }
        $planNames = @($Plans | ForEach-Object { $_['Name'] })
        if (-not $Inspect -and -not $Offline) {
            foreach ($oldName in $records.Keys) {
                if ($oldName -notin $planNames) {
                    $null = Remove-WinstObsoleteDownloadRecord -DestDir $downloadDir -FileName $oldName -Record $records[$oldName] -Config $Context.Config
                }
            }
        }
        $version = Get-EntryString -Entry $PrevEntry -Key 'version'
        $fromPackage = Get-EntryBool -Entry $Plan -Key 'versionFromPackage'

        $versionInput = $null
        if ($fromPackage -and (-not $version -or $Plans[0]['NeedDownload'])) {
            $versionInput = Get-WinstPackageVersionInput -Plan $Plan
            if (-not $versionInput -or $versionInput.Index -ge $Plans.Count) {
                return @{ Ok = $false; Error = '未找到有效的包内取版文件'; Network = $false }
            }
        }
        $order = @(0..($Plans.Count - 1))
        # 新主包需要新版取版附件时，先换附件，确保中断后不会从旧附件补读新主包版本。
        if ($versionInput -and $versionInput.Index -gt 0 -and $Plans[$versionInput.Index]['NeedDownload']) {
            $hasOldInput = Test-Path -LiteralPath $Plans[$versionInput.Index]['Target'] -PathType Leaf
            if (-not $version -and $hasOldInput -and (Test-Path -LiteralPath $Plans[0]['Target'] -PathType Leaf)) {
                # 先登记旧主包，避免只换了取版附件就中断时，下次把新附件的版本补给旧主包。
                try {
                    $version = Read-WinstPackageVersion -Context $Context -Plan $Plan -PkgDir $PkgDir -InputName $versionInput.Name -Quiet:$Quiet
                } catch {
                    if (-not $Plans[0]['NeedDownload']) { return @{ Ok = $false; Error = $_.Exception.Message; Network = $false } }
                    Write-Verbose ('旧附件无法补读版本，将先替换主包，再从新附件取版。{0}' -f $_.Exception.Message)
                }
                if ($version -and $Plans[0]['NeedDownload']) {
                    Save-WinstCacheIndex -PkgDir $Context.PkgDir -UpdateIds @($Id) -Update {
                        param($index)
                        if ($index.Contains($Id)) { $index[$Id]['version'] = $version }
                        else { Set-WinstCacheIndexEntry -Index $index -Id $Id -Version $version -Files @($planNames[0], $versionInput.Name) }
                    }
                }
                if (-not $Plans[0]['NeedDownload']) { $versionInput = $null }
            }
            if ($Plans[0]['NeedDownload'] -and $hasOldInput -and $version) {
                $order = @($versionInput.Index) + @($order -ne $versionInput.Index)
            }
        }
        $mainReady = $false
        foreach ($fileSeq in $order) {
            $filePlan = $Plans[$fileSeq]
            $url = [string]$filePlan['Url']
            $name = [string]$filePlan['Name']
            $target = [string]$filePlan['Target']
            if (-not $name -or -not $target -or -not $url) {
                return @{ Ok = $false; Error = ('下载信息不完整（{0}）' -f $DisplayName); Network = $false }
            }
            # refresh 取值写错之类只在 --verbose 提示，不占正常输出
            if ($filePlan['Notice'] -and (Get-WinstState -Name WinstOptions) -and (Get-WinstState -Name WinstOptions).Verbose) {
                Write-Host ('  [verbose] {0}' -f [string]$filePlan['Notice']) -ForegroundColor DarkGray
            }
            # Hint：拿不到校验器时「本次按已缓存处理」这类必须让用户看见的一行
            if ($filePlan['Hint'] -and -not $Quiet) {
                Write-Host ('    提示: {0}' -f [string]$filePlan['Hint']) -ForegroundColor DarkYellow
            }

            if ($filePlan['ValidationError'] -and -not $records.Contains($name)) {
                return @{ Ok = $false; Error = ('{0} 无法验证缓存：{1}' -f $name, $filePlan['ValidationError']); Network = [bool]$filePlan['ValidationNetwork'] }
            }

            $received = $null
            if ($records.Contains($name)) {
                $received = Restore-WinstPackageFile -Context $Context -FilePlan $filePlan -Plan $Plan -SourceName $SourceName `
                    -Record $records[$name] -DestDir $downloadDir -Offline:$Offline
                if (-not $received.Ok) {
                    if ($Inspect -or $received.Action -in @('Move','Register') -or $Offline) {
                        $received['Changed'] = $downloadedNames.Count -gt 0
                        return $received
                    }
                    if (-not $retries.ContainsKey($fileSeq)) {
                        $retries[$fileSeq] = @{ Attempts = 0; Refresh = $true; Restart = $received.Action -eq 'Redownload' }
                    }
                    $received = $null
                }
            }
            if ($filePlan['NeedDownload'] -and -not $received) {
                if ($Inspect) {
                    return @{ Ok = $false; Changed = $downloadedNames.Count -gt 0; Network = $false
                        Action = 'Redownload'; Error = ('{0} 未下载完成。' -f $name) }
                }
                if ($Offline) {
                    $offlineError = ('离线缺包：{0} 的安装包不在缓存里。请在联网机器上刷新缓存（bundle pack / update --download-only）后重试。' -f $DisplayName)
                    if ($Id -ieq 'winst') {
                        $offlineError = ('离线缺包：{0} 的安装包不在缓存里。离线安装 winst 自身请用 winst install winst --from <winst.zip 或已解压目录>。' -f $DisplayName)
                    }
                    if (Test-Path -LiteralPath $target -PathType Leaf) {
                        $offlineError = ('离线缓存无法验证：{0} 的现有安装包未通过当前完整性规则；文件已保留，请在联网机器上刷新缓存后重试。' -f $DisplayName)
                    }
                    return @{
                        Ok = $false; Network = $true
                        Error = $offlineError
                    }
                }
                if (-not $Quiet -and $filePlan['Reason']) {
                    Write-Host ('    {0}: {1}' -f $name, $filePlan['Reason']) -ForegroundColor DarkYellow
                }
                if (-not $Bootstrap -and -not $engineChecked -and (Get-WinstEngineExe -Context $Context -Id (Get-WinstDownloadEngineId))) {
                    $engine = Confirm-WinstDownloadEngine -Context $Context -Quiet:$Quiet
                    if (-not $engine.Ok) {
                        return @{ Ok = $false; Error = ('下载引擎不可用：{0}' -f $engine.Error); Network = $true }
                    }
                    $engineChecked = $true
                }
                if (-not $retries.ContainsKey($fileSeq)) { $retries[$fileSeq] = @{ Attempts = 0 } }
                $received = Receive-WinstPackageFile -Plan $Plan -Retry $retries[$fileSeq] -Context $Context -FilePlan $filePlan -FileSeq $fileSeq -PkgDir $PkgDir `
                    -Id $Id -SourceName $SourceName -Bootstrap:$Bootstrap -Quiet:$Quiet
                if ($received['RefreshPlan']) {
                    $Plan = $received.RefreshPlan
                    $read = Read-WinstCacheIndex -PkgDir $Context.PkgDir -Ids @($Id)
                    $PrevEntry = $read.Index[$Id]
                    $Plans = @(Get-WinstPackageFilePlans -Context $Context -Index $read.Index -Id $Id -Files $Plan.download.files `
                        -ManifestOrigin $SourceName -RequireCurrent)
                    # 本次重试需要从头取当前文件，即使同名正式缓存仍然存在。
                    $Plans[$fileSeq]['NeedDownload'] = $true
                    continue downloadPlan
                }
                if (-not $received.Ok) { return $received }
            }
            if ($received) { $downloadedNames += $name }

            if ($fileSeq -eq 0) {
                $mainReady = $true
                if ($filePlan['NeedDownload']) {
                    $version = ''
                    if (-not $fromPackage) { $version = Get-EntryString -Entry $Plan -Key 'version' }
                }
            }
            try {
                try {
                    # 取版文件若已通过复用判定，主包就绪时即可登记；需下载的附件则等该文件到手。
                    if ($mainReady -and $versionInput -and
                            (-not $Plans[$versionInput.Index]['NeedDownload'] -or $downloadedNames -contains $versionInput.Name)) {
                        $version = Read-WinstPackageVersion -Context $Context -Plan $Plan -PkgDir $PkgDir -InputName $versionInput.Name -Quiet:$Quiet
                        $versionInput = $null
                    }
                } finally {
                    Update-WinstPackageCacheIndex -Context $Context -Id $Id -FilePlan $filePlan -PlanNames $planNames `
                        -Version $version -Downloaded:($filePlan['NeedDownload']) -Complete:($fileSeq -eq $order[-1])
                }
            } catch {
                return @{ Ok = $false; Changed = [bool]$received; Action = 'Register'; Error = ('{0} 缓存登记失败：{1}' -f $name, $_.Exception.Message); Network = $false }
            }
            if ($received) {
                try { Complete-WinstPackageDownload -Download $received.Download -DestDir $downloadDir }
                catch {
                    return @{ Ok = $false; Changed = $true; Network = $false; Action = 'Register'
                        Error = ('{0} 已存入缓存，清理下载记录失败：{1}' -f $name, $_.Exception.Message) }
                }
            }
        }

        try {
            if (Test-Path -LiteralPath $downloadDir -PathType Container) {
                $null = Remove-WinstReplacedDownloadFiles -DestDir $downloadDir -Config $Context.Config -FileNames $planNames
                Clear-WinstEmptyDownloadStage -PkgDir $PkgDir -DownloadComplete
            }
        }
        catch {
            return @{ Ok = $false; Network = $false
                Error = ('文件已就绪：{0}。下载目录清理失败（{1}）：{2}' -f (($Plans | ForEach-Object { $_['Target'] }) -join '、'), (Join-WinstPath $PkgDir 'winst-download'), $_.Exception.Message) }
        }
        return @{ Ok = $true; Names = @($downloadedNames | Where-Object { $planNames -contains $_ } | Select-Object -Unique)
            Version = $version; Plan = $Plan; Plans = $Plans }
    }
}
