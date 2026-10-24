#Requires -Version 5.1

function New-WinstSoftwareItem {
    <#
    .SYNOPSIS
        由「软件清单行 + 安装记录 + 已下载的安装包」生成「软件列表」的展示视图对象。
    .DESCRIPTION
        「软件列表」列的是**软件源里的全部软件**，因此每行同时给出三件事：
          ① 版本信息：软件源里各来源的版本（**全部来源并排**）与最高可用版本及它的来源；
          ② 安装状态：未安装 / 已安装 x.y（含已装能否升级、安装目录是否还在）；
          ③ 下载状态：未下载 / 已下载包 a.b（大小、文件数，含安装包能否更新）。
        结论文案与「已装软件」「已下载包」共用一处定义（Get-WinstVersionConclusion），不另写一套。
    .OUTPUTS
        [ordered]@{ Id; DisplayName; Group; Description; Type; TypeText; Row;
                    SourceText; BestVersion; BestSource;
                    Installed; InstalledVersion; InstalledVersionText; InstalledDirMissing;
                    InstalledUpdateState; InstalledUpdateHint;
                    CacheHas; CacheVersion; CacheVersionText; CacheDir; CacheFiles; CacheFileCount;
                    CacheSizeBytes; CacheSizeText; PackageUpdateState; PackageUpdateHint; HasPackageUpdate }
    #>
    param(
        [Parameter(Mandatory = $true)][hashtable]$Context,
        [Parameter(Mandatory = $true)][string]$Id,
        $Row = $null,
        $Ledger = $null,
        [string]$CacheDir = '',
        [string[]]$CacheFiles = @(),
        [long]$CacheSizeBytes = 0,
        [string]$CacheVersion = ''
    )

    $facts = Get-WinstRowViewFacts -Id $Id -Row $Row -Ledger $Ledger
    $installedFacet = Get-WinstInstalledFacet -Ledger $Ledger -Facts $facts
    $cacheHas = [bool](@($CacheFiles).Count -gt 0)
    $packageFacet = Get-WinstPackageFacet -Facts $facts -CacheVersion $CacheVersion -CacheFiles $CacheFiles -Evaluate:$cacheHas

    return [ordered]@{
        Id                   = $Id
        DisplayName          = [string]$facts.DisplayName
        Group                = [string]$facts.Group
        Description          = [string]$facts.Description
        Type                 = [string]$facts.Type
        TypeText             = (Get-PlanTypeText -Type ([string]$facts.Type))
        Row                  = $Row
        SourceText           = [string]$facts.SourceText
        BestVersion          = [string]$facts.BestVersion
        BestSource           = [string]$facts.BestSource
        Installed            = [bool]$installedFacet.Installed
        InstalledVersion     = [string]$installedFacet.Version
        InstalledVersionText = [string]$installedFacet.VersionText
        InstalledDirMissing  = [bool]$installedFacet.DirMissing
        InstalledUpdateState = [string]$installedFacet.UpdateState
        InstalledUpdateHint  = [string]$installedFacet.UpdateHint
        CacheHas             = $cacheHas
        CacheVersion         = $CacheVersion
        CacheVersionText     = [string]$packageFacet.VersionText
        CacheDir             = $CacheDir
        CacheFiles           = @($CacheFiles)
        CacheFileCount       = @($CacheFiles).Count
        CacheSizeText        = (Format-WinstSizeText -Bytes $CacheSizeBytes)
        PackageUpdateState   = [string]$packageFacet.State
        PackageUpdateHint    = [string]$packageFacet.Hint
        HasPackageUpdate     = [bool]$packageFacet.HasUpdate
        Ledger               = $Ledger
        # —— 标准键别名（P1-2）：见 New-WinstInstalledItem 的说明 ——
        LatestVersion        = [string]$facts.BestVersion
        LatestSource         = [string]$facts.BestSource
        HasUpdate            = [bool]$installedFacet.HasUpdate
        UpdateHint           = [string]$installedFacet.UpdateHint
        UpdateState          = [string]$installedFacet.UpdateState
        DirMissing           = [bool]$installedFacet.DirMissing
        Version              = [string]$installedFacet.VersionText
    }
}
