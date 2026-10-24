#Requires -Version 5.1

function New-WinstListItem {
    <#
    .SYNOPSIS
        把清单里的一行（id 或 id==版本）解析成「清单条目」视图对象。
    .DESCRIPTION
        结论口径与「已装软件 / 已下载包 / 软件列表」共用同一批判定函数（Get-WinstRowBestEntry /
        Get-WinstRowSourceText / Compare-WinstVersion），不另写一套版本结论。
        PinMismatch：清单里写了 `id==版本`，而软件源里最高可用版本不是它（由调用方提示，不悄悄忽略）。
    .OUTPUTS
        [ordered]@{ Id; DisplayName; PinnedVersion; PinMismatch; PinUnknown; InCatalog; SourceText;
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
    $installedFacet = Get-WinstInstalledFacet -Ledger $ledger -Facts $facts

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
    $packageFacet = Get-WinstPackageFacet -Facts $facts -CacheVersion $cacheVersion -CacheFiles $cacheFiles -Evaluate

    $pinMismatch = $false
    $pinUnknown = $false
    if ($PinnedVersion) {
        if (-not $facts.BestVersion) { $pinUnknown = $true }
        elseif ((Compare-WinstVersion -A $PinnedVersion -B ([string]$facts.BestVersion)) -ne 0) { $pinMismatch = $true }
    }

    # 条目类型（download = 「仅下载软件包」）：下载流程据此把「安装包」换成「软件包」措辞
    $typeText = ''
    if ($row) { $typeText = Get-WinstRowType -Row $row }

    return [ordered]@{
        Id                   = $Id
        DisplayName          = [string]$facts.DisplayName
        Type                 = $typeText
        PinnedVersion        = $PinnedVersion
        PinMismatch          = $pinMismatch
        PinUnknown           = $pinUnknown
        InCatalog            = [bool]$facts.InCatalog
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
        LatestVersion        = [string]$facts.BestVersion
        LatestSource         = [string]$facts.BestSource
        DirMissing           = [bool]$installedFacet.DirMissing
        Version              = [string]$installedFacet.VersionText
        PackageUpdateState   = [string]$packageFacet.State
        PackageUpdateHint    = [string]$packageFacet.Hint
        InstalledUpdateState = [string]$installedFacet.UpdateState
        UpdateHint            = [string]$installedFacet.UpdateHint
        InstalledUpdateHint  = [string]$installedFacet.UpdateHint
    }
}
