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
        $skip = Write-WinstUpdateMissingEntry -Id $Id -RowById $RowById -Result $Result
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

    $snap = Get-WinstUpdateEntrySnapshot -Context $Context -Row $row -Ledger $ledger -InstalledVersion $installedVersion
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
        if ($Check -and $snap.VersionFromPackage) {
            # 三条件满足 = 远端无新包 + 已下载安装包有版本号 + 已安装版本与已下载包版本一致 → 按「已是最新」处理
            if (Test-WinstUpdateUpToDateByPackage -Snap $snap -InstalledVersion $installedVersion) {
                $Result.UpToDate++
                $entryResult.Action = 'latest'
                $entryResult.Latest = [string]$snap.CachedPackageVersion
                $entryResult.PackageVersion = [string]$snap.CachedPackageVersion
                $entryResult.RemoteFresh = [string]$snap.RemoteFresh
                if (-not $Quiet) {
                    Write-Host ('  {0}: 已是最新版本（{1}；远端无新包，与已下载的安装包一致）。' -f $displayName, $installedVersion) -ForegroundColor Gray
                }
                return @{ Entries = @($entryResult); Installed = $true; DownloadOnlySkipped = $false; RefreshState = $false }
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
        -FilesOnly:$FilesOnly -ForceSystemItems:$ForceSystemItems -SourceName $SourceName -Result $Result

    return @{ Entries = @($entryResult); Installed = $true; DownloadOnlySkipped = $false; RefreshState = [bool]$exec.RefreshState }
}
