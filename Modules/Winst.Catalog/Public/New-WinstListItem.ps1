#Requires -Version 5.1

function New-WinstListItem {
    <#
    .SYNOPSIS
        把清单里的一行（id 或 id==版本）解析成「清单条目」视图对象。
    .DESCRIPTION
        PlanAvailable 表示可执行的下载计划；VersionPending 表示计划可用、版本需取包后确认。
        固定版本通常与软件源比较，离线套件安装时与选定来源的本地包比较。
    .OUTPUTS
        [ordered]@{ Id; DisplayName; PinnedVersion; PinMismatch; PinUnknown; InCatalog; PlanAvailable; VersionPending; SourceText;
                    BestVersion; BestSource; Row; Installed; InstalledVersion; InstalledVersionText;
                    InstalledDirMissing; UpdateState; CacheHas; CacheVersion; CacheVersionText;
                    CacheFiles; CacheDir; CacheSizeText; CacheFileCount; HasPackageUpdate;
                    Type }
    #>
    param(
        [Parameter(Mandatory = $true)][hashtable]$Context,
        [Parameter(Mandatory = $true)][string]$Id,
        [string]$PinnedVersion = '',
        [Parameter(Mandatory = $true)][hashtable]$Lookup
    )

    $row = $null
    if ($Lookup.RowById.Contains($Id)) { $row = $Lookup.RowById[$Id] }

    $ledger = $null
    if ($Lookup.State) { $ledger = Get-WinstInstalledApp -State $Lookup.State -Id $Id }
    $facts = Get-WinstRowViewFacts -Id $Id -Row $row -Ledger $ledger
    $planAvailable = [bool]$facts.Chosen
    $installedFacet = Get-WinstInstalledFacet -Context $Context -Lookup $Lookup -Ledger $ledger -Row $row

    $cacheInfo = $null
    if ($Lookup.CacheDirById.Contains($Id)) { $cacheInfo = $Lookup.CacheDirById[$Id] }
    $cacheHas = [bool]($null -ne $cacheInfo)
    $cacheFiles = @()
    $cacheDirPath = ''
    $cacheSizeText = ''
    if ($cacheInfo) {
        $cacheFiles = @($cacheInfo['Files'])
        $cacheDirPath = [string]$cacheInfo['Path']
        $cacheSizeText = [string]$cacheInfo['SizeText']
    }
    $cacheVersion = ''
    if ($Lookup.CacheIndex.Contains($Id)) { $cacheVersion = Get-EntryString -Entry $Lookup.CacheIndex[$Id] -Key 'version' }
    $packageFacet = Get-WinstPackageFacet -Facts $facts -CacheVersion $cacheVersion -Evaluate

    $pinMismatch = $false
    $pinUnknown = $false
    $pinSource = '软件源'
    $pinVersion = [string]$facts.RemoteVersion
    if ($PinnedVersion) {
        if ($Context.ContainsKey('BundleDependencyIndex')) {
            $pinSource = '缓存包'
            $pinVersion = ''
            if ($planAvailable -and $cacheHas) {
                # 旧套件可能保留多个来源，批量安装按行顺序选第一个可用计划。
                $bundlePlan = Get-WinstRowBestPlanEntry -Row $row -Best $null
                $pinVersion = Get-WinstOfflinePackageVersion -Context $Context -Plan $bundlePlan['Plan'] -CacheIndex $Lookup.CacheIndex
            }
        }
        if (-not $pinVersion -or $pinVersion -ieq 'unknown') { $pinUnknown = $true }
        elseif ((Compare-WinstVersion -A $PinnedVersion -B $pinVersion) -ne 0) { $pinMismatch = $true }
    }

    # 条目类型（download = 「仅下载软件包」）：下载流程据此把「安装包」换成「软件包」措辞
    $typeText = ''
    if ($row) { $typeText = Get-WinstRowType -Row $row }

    return [ordered]@{
        CompanionVersionLines = @(Get-WinstCompanionVersionLines -Context $Context -Id $Id -Row $row -Ledger $ledger -CacheIndex $Lookup.CacheIndex)
        Id                   = $Id
        DisplayName          = [string]$facts.DisplayName
        Type                 = $typeText
        PinnedVersion        = $PinnedVersion
        PinSource            = $pinSource
        PinVersion           = $pinVersion
        PinMismatch          = $pinMismatch
        PinUnknown           = $pinUnknown
        InCatalog            = [bool]$facts.InCatalog
        PlanEntry            = $facts.Chosen
        PlanAvailable        = $planAvailable
        VersionPending       = [bool]($planAvailable -and -not $facts.BestVersion)
        SourceText           = [string]$facts.SourceText
        BestVersion          = [string]$facts.BestVersion
        BestSource           = [string]$facts.BestSource
        Row                  = $row
        Installed            = [bool]$installedFacet.Installed
        InstalledVersion     = [string]$installedFacet.Version
        InstalledVersionText = [string]$installedFacet.VersionText
        InstalledDirMissing  = [bool]$installedFacet.DirMissing
        UpdateState          = [string]$installedFacet.UpdateState
        CacheHas             = $cacheHas
        CacheVersion         = $cacheVersion
        CacheVersionText     = [string]$packageFacet.VersionText
        CacheFiles           = @($cacheFiles)
        CacheDir             = $cacheDirPath
        CacheSizeText        = $cacheSizeText
        CacheFileCount       = @($cacheFiles).Count
        HasPackageUpdate     = [bool]$packageFacet.HasUpdate
        HasUpdate            = [bool]$installedFacet.HasUpdate
        LatestVersion        = [string]$installedFacet.Latest
        LatestSource         = [string]$installedFacet.LatestSource
        DirMissing           = [bool]$installedFacet.DirMissing
        Version              = [string]$installedFacet.VersionText
        PackageUpdateState   = [string]$packageFacet.State
        PackageUpdateHint    = [string]$packageFacet.Hint
        InstalledUpdateState = [string]$installedFacet.UpdateState
        UpdateHint            = [string]$installedFacet.UpdateHint
        InstalledUpdateHint  = [string]$installedFacet.UpdateHint
    }
}
