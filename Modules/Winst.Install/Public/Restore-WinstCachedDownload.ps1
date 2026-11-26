#Requires -Version 5.1

function Restore-WinstCachedDownload {
    <#
    .SYNOPSIS
        检查下载目录，将已完成的文件移入缓存，返回详情页可执行的操作。
    #>
    param([hashtable]$Context, [string]$Id)

    $state = @{ Action = ''; Message = ''; Changed = $false }
    $lock = $null
    try {
        $lock = Enter-WinstPackageLock -PkgDir $Context.PkgDir -Id $Id
        $dir = Join-WinstPath $Context.PkgDir $Id
        $stage = Join-WinstPath $dir 'winst-download'
        if (-not (Test-Path -LiteralPath $stage -PathType Container)) { return $state }
        $options = Get-WinstState -Name WinstOptions
        if ($options -and $options.DryRun) { $state.Message = '预览模式，跳过下载检查。'; return $state }

        $records = Get-WinstDownloadTaskRecords -DestDir $stage
        if (-not $records.Count) {
            $index = (Read-WinstCacheIndex -PkgDir $Context.PkgDir -Ids @($Id)).Index
            $names = @(Get-EntryArray $index[$Id] 'files')
            $state.Changed = Remove-WinstReplacedDownloadFiles -DestDir $stage -Config $Context.Config -FileNames $names -DuplicatesOnly
            Clear-WinstEmptyDownloadStage -PkgDir $dir
            if (Test-Path -LiteralPath $stage -PathType Container) {
                $state.Message = '暂存中仍有文件，可重新下载。确认原下载进程已停止后，也可用 winst clean <id> 删除该软件的全部缓存。'
                $state.Action = 'Redownload'
            } else { $state.Changed = $true }
            return $state
        }

        $source = Get-EntryString ($records.Values | Select-Object -First 1) 'sourceName'
        $resolved = Get-WinstManifestAppPlan -Context $Context -Id $Id -RequiredSource $source
        if (-not $resolved.Ok) { throw $resolved.Error }
        $plan = $resolved.Plan
        $index = (Read-WinstCacheIndex -PkgDir $Context.PkgDir -Ids @($Id)).Index
        $files = @(Get-EntryArray $plan.download 'files')
        $nameError = Get-WinstDuplicateDownloadNameError -Files $files
        if ($nameError) { throw $nameError }
        $plans = @(Get-WinstPackageFilePlans -Context $Context -Id $Id -Index $index -ManifestOrigin $source -Files $files -Offline)
        if (-not @($plans | Where-Object { $_.Name -and $records.Contains($_.Name) }).Count) {
            $state.Action = 'Redownload'
            $state.Message = '软件源的文件已更新。'
            return $state
        }
        $offline = $options -and $options.Offline
        $result = Invoke-WinstPackageDownloadLoop -Context $Context -Plan $plan -Plans $plans -Id $Id -DisplayName $Id `
            -PkgDir $dir -SourceName $source -PrevEntry $index[$Id] -Quiet -Inspect -Offline:$offline
        if ($result.Ok) {
            $state.Message = '下载完成，文件已存入缓存。'
            $state.Changed = $true
        } else {
            $state.Action = [string]$result['Action']
            if (-not $state.Action) { $state.Action = 'Inspect' }
            $state.Message = [string]$result.Error
            $state.Changed = [bool]$result['Changed']
        }
    } catch {
        $state.Action = 'Inspect'
        $state.Message = $_.Exception.Message
    }
    finally { if ($lock) { $lock.Dispose() } }
    return $state
}
