#Requires -Version 5.1

function New-WinstCachedItem {
    <#
    .SYNOPSIS
        由「已下载的安装包 + 安装记录 + 软件清单行」生成「已下载包」的展示视图对象。
    .DESCRIPTION
        一个条目同时表达安装包、本机安装与软件源信息：
          ① 安装包本身：缓存版本、文件数、大小；
          ② 本机是否已安装：Installed / InstalledVersion / InstalledDirMissing；
          ③ 已装软件能否升级：InstalledUpdateState / InstalledUpdateHint（update / latest / newer / unknown / missing）；
          ④ 软件源里的版本：SourceText（**全部来源并排**，如 `local (21.0.5)、dsx42/winst-manifest (21.0.6)`）；
          ⑤ 安装包能否更新：HasPackageUpdate / PackageUpdateHint（缓存版本 vs 软件源最高可用版本）。
    .OUTPUTS
        [ordered]@{ CompanionVersionLines; Id; DisplayName; Group; CacheVersionText; CacheDir; CacheFiles; CacheFileCount;
                    CacheSizeText; Installed; InstalledVersion; InstalledVersionText;
                    InstalledDirMissing; InstalledUpdateState; InstalledUpdateHint; SourceText;
                    BestVersion; BestSource; PackageUpdateState; PackageUpdateHint; HasPackageUpdate;
                    InCatalog; Type; TypeText; Row; LatestVersion; LatestSource }
    #>
    param(
        [Parameter(Mandatory = $true)][hashtable]$Context,
        [Parameter(Mandatory = $true)][string]$Id,
        [string]$CacheDir,
        [string[]]$CacheFiles,
        [long]$CacheSizeBytes,
        [switch]$HasDownloadStage,
        [string]$CacheVersion,
        $Ledger,
        $Row,
        $CacheIndex,
        [hashtable]$SourceLookup
    )

    $facts = Get-WinstRowViewFacts -Id $Id -Row $Row -Ledger $Ledger

    $installedFacet = Get-WinstInstalledFacet -Context $Context -Lookup $SourceLookup -Ledger $Ledger -Row $Row
    $packageFacet = Get-WinstPackageFacet -Facts $facts -CacheVersion $CacheVersion -Evaluate:($CacheFiles.Count -gt 0)

    return [ordered]@{
        CompanionVersionLines = @(Get-WinstCompanionVersionLines -Context $Context -Id $Id -Plan (Get-EntryValue -Entry $facts.Chosen -Key 'Plan') -Ledger $Ledger -CacheIndex $CacheIndex)
        Id                  = $Id
        DisplayName         = [string]$facts.DisplayName
        Group               = [string]$facts.Group
        HasDownloadStage    = [bool]$HasDownloadStage
        CacheVersionText    = if ($CacheFiles.Count) { [string]$packageFacet.VersionText } else { '未下载' }
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
        LatestVersion       = [string]$installedFacet.Latest
        LatestSource        = [string]$installedFacet.LatestSource
    }
}
