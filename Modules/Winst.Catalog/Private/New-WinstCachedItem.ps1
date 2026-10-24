#Requires -Version 5.1

function New-WinstCachedItem {
    <#
    .SYNOPSIS
        由「已下载的安装包 + 安装记录 + 软件清单行」生成「已下载包」的展示视图对象。
    .DESCRIPTION
        一个条目同时表达四件事：
          ① 安装包本身：缓存版本、文件数、大小；
          ② 本机是否已安装：Installed / InstalledVersion / InstalledDirMissing；
          ③ 已装软件能否升级：InstalledUpdateState / InstalledUpdateHint（update / latest / newer / unknown / missing）；
          ④ 软件源里的版本：SourceText（**全部来源并排**，如 `local (21.0.5)、dsx42/winst-manifest (21.0.6)`）；
          ⑤ 安装包能否更新：HasPackageUpdate / PackageUpdateHint（缓存版本 vs 软件源最高可用版本）。
        版本结论的文案与「已装软件」共用同一套（Get-WinstRowBestEntry / Get-WinstUpgradeHint），不另写一份。
    .OUTPUTS
        [ordered]@{ Id; DisplayName; Group; CacheVersion; CacheVersionText; CacheDir; CacheFiles; CacheFileCount;
                    CacheSizeBytes; CacheSizeText; Installed; InstalledVersion; InstalledVersionText;
                    InstalledDirMissing; InstalledUpdateState; InstalledUpdateHint; SourceText;
                    BestVersion; BestSource; PackageUpdateState; PackageUpdateHint; HasPackageUpdate;
                    InCatalog; Type; TypeText; Row }
    #>
    param(
        [Parameter(Mandatory = $true)][hashtable]$Context,
        [Parameter(Mandatory = $true)][string]$Id,
        [string]$CacheDir = '',
        [string[]]$CacheFiles = @(),
        [long]$CacheSizeBytes = 0,
        [string]$CacheVersion = '',
        $Ledger = $null,
        $Row = $null
    )

    $facts = Get-WinstRowViewFacts -Id $Id -Row $Row -Ledger $Ledger

    # 缓存里记录的版本是「下载当时」的写法：软件源后来声明了 source.versionRewrite（写法归一）时，
    # 缓存记录可能还没跟上，同一个版本会被当成两个。展示与比较前先按同一组规则归一缓存版本；
    # 规则匹配不上（如两者本来就同写法）时原样保留
    if ($Row -and $CacheVersion) {
        $rowSources = @($Row['Sources'])
        foreach ($rowSource in $rowSources) {
            $cacheRules = @(Get-EntryArray -Entry $rowSource['Plan'] -Key 'sourceVersionRewrite')
            if ($cacheRules.Count -eq 0) { continue }
            $normalizedCache = Get-WinstRewrittenVersion -Version ([string]$CacheVersion) -Rules $cacheRules
            if ($normalizedCache) { $CacheVersion = $normalizedCache }
            break
        }
    }

    $installedFacet = Get-WinstInstalledFacet -Ledger $Ledger -Facts $facts
    $packageFacet = Get-WinstPackageFacet -Facts $facts -CacheVersion $CacheVersion -CacheFiles $CacheFiles -Evaluate

    return [ordered]@{
        Id                  = $Id
        DisplayName         = [string]$facts.DisplayName
        Group               = [string]$facts.Group
        CacheVersion        = $CacheVersion
        CacheVersionText    = [string]$packageFacet.VersionText
        CacheDir            = $CacheDir
        CacheFiles          = @($CacheFiles)
        CacheFileCount      = @($CacheFiles).Count
        CacheSizeText       = (Format-WinstSizeText -Bytes $CacheSizeBytes)
        Installed           = [bool]$installedFacet.Installed
        InstalledVersion    = [string]$installedFacet.Version
        InstalledVersionText = [string]$installedFacet.VersionText
        InstalledDirMissing = [bool]$installedFacet.DirMissing
        InstalledUpdateState = [string]$installedFacet.UpdateState
        InstalledUpdateHint = [string]$installedFacet.UpdateHint
        SourceText          = [string]$facts.SourceText
        BestVersion         = [string]$facts.BestVersion
        BestSource          = [string]$facts.BestSource
        PackageUpdateState  = [string]$packageFacet.State
        PackageUpdateHint   = [string]$packageFacet.Hint
        HasPackageUpdate    = [bool]$packageFacet.HasUpdate
        InCatalog           = [bool]$facts.InCatalog
        Type                = [string]$facts.Type
        TypeText            = (Get-PlanTypeText -Type ([string]$facts.Type))
        Row                 = $Row
        # —— 标准键别名（P1-2）：见 New-WinstInstalledItem 的说明 ——
        LatestVersion       = [string]$facts.BestVersion
        LatestSource        = [string]$facts.BestSource
        HasUpdate           = [bool]$installedFacet.HasUpdate
        UpdateHint          = [string]$installedFacet.UpdateHint
        UpdateState         = [string]$installedFacet.UpdateState
        DirMissing          = [bool]$installedFacet.DirMissing
        Version             = [string]$installedFacet.VersionText
    }
}
