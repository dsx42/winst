#Requires -Version 5.1

function New-WinstInstalledItem {
    <#
    .SYNOPSIS
        由安装记录条目 + 软件清单行生成「已装软件」的展示视图对象。
    .OUTPUTS
        [ordered]@{ CompanionVersionLines; Id; DisplayName; Group; Version; RawVersion; Type; TypeText; InstallDir;
                    InstalledAt; UpdatedAt; ManifestOrigin; SourceText; Managed; ManagedText; InCatalog;
                    LatestVersion; LatestSource; HasUpdate; UpdateHint; UpdateState; OtherSourcesText;
                    OldVersions; OldVersionsText; HasOldVersions;
                    CacheDir; CacheVersion; CacheHas; CacheDirMissing; CacheFiles;
                    DirMissing; Row; Ledger; InstalledVersion; InstalledVersionText; InstalledDirMissing;
                    InstalledUpdateState; InstalledUpdateHint; BestVersion; BestSource }
    #>
    param(
        [Parameter(Mandatory = $true)][hashtable]$Context,
        [Parameter(Mandatory = $true)][string]$Id,
        [Parameter(Mandatory = $true)]$Entry,
        $Row = $null,
        $CacheIndex = $null
    )

    $rawVersion = Get-EntryString -Entry $Entry -Key 'version'
    $managed = Get-EntryString -Entry $Entry -Key 'managed'
    if (-not $managed) { $managed = 'winst' }

    $facts = Get-WinstRowViewFacts -Id $Id -Row $Row -Ledger $Entry
    $installedFacet = Get-WinstInstalledFacet -Ledger $Entry -Facts $facts
    $displayName = [string]$facts.DisplayName
    $inCatalog = [bool]$facts.InCatalog
    $sourceText = [string]$facts.SourceText
    $group = [string]$facts.Group
    $type = [string]$facts.Type

    $installDir = Get-EntryString -Entry $Entry -Key 'installDir'
    $dirMissing = [bool]$installedFacet.DirMissing
    $latest = [string]$facts.BestVersion
    $latestSource = [string]$facts.BestSource
    $hasUpdate = [bool]$installedFacet.HasUpdate
    $updateHint = [string]$installedFacet.UpdateHint
    $updateState = [string]$installedFacet.UpdateState
    $otherSourcesText = ''
    if ($inCatalog) {
        # package 来源尚无确定远端版本时，不再列出其它来源的版本比较。
        $freshBranch = [bool]($facts.VersionFromPackage -and $latest -and ([string]$facts.RemoteFresh) -ine 'unchanged')
        if ($latest -and -not $freshBranch) {
            # 其它来源的版本（版本行里已经体现了最高版本与它的来源，这里只列出剩下的，避免重复展示）
            $others = @()
            foreach ($sourceEntry in @($Row['Sources'])) {
                $name = [string]$sourceEntry['Source']
                if (-not $name) { continue }
                if ($latestSource -and $name -ieq $latestSource) { continue }
                $version = [string]$sourceEntry['Version']
                if (-not $version) { $version = '未知' }
                $mark = ''
                if (-not $sourceEntry['Ok']) { $mark = '·不可用' }
                $others += ('{0} ({1}){2}' -f $name, $version, $mark)
            }
            $otherSourcesText = ($others -join '、')
        }
    }

    $versionText = '未知'
    if ($rawVersion) { $versionText = $rawVersion }

    # 本机并存的低版本（低于本机版本）：供列表与详情提醒用户清理
    $oldVersions = @()
    foreach ($item in @(Get-EntryArray -Entry $Entry -Key 'oldVersions')) {
        $oldVersion = Get-EntryString -Entry $item -Key 'version'
        if (-not $oldVersion) { continue }
        if ($rawVersion -and $rawVersion -ne 'unknown') {
            $cmp = 0
            try { $cmp = Compare-WinstVersion -A $oldVersion -B $rawVersion } catch { $cmp = 0 }
            if ($cmp -ge 0) { continue }
        }
        $oldVersions += [ordered]@{
            Version   = $oldVersion
            Detail    = (Get-EntryString -Entry $item -Key 'detail')
            RecordKey = (Get-EntryString -Entry $item -Key 'recordKey')
        }
    }
    $oldVersionsText = Format-WinstOldVersionText -OldVersions $oldVersions

    # 已下载的安装包
    $cacheDir = ''
    $cacheVersion = ''
    $cacheHas = $false
    $cacheDirMissing = $false
    $cacheFiles = @()
    if ($Context.PkgDir) {
        $cacheDir = Join-WinstPath $Context.PkgDir $Id
        $cacheEntry = $null
        if ($CacheIndex -and $CacheIndex.Contains($Id)) { $cacheEntry = $CacheIndex[$Id] }
        if ($cacheEntry) {
            $cacheVersion = Get-EntryString -Entry $cacheEntry -Key 'version'
            $cacheFiles = @(Get-EntryArray -Entry $cacheEntry -Key 'files')
        }
        if (Test-Path -LiteralPath $cacheDir -PathType Container) {
            $downloads = @()
            # 注意：循环变量不能叫 $entry —— 会覆盖同名参数 $Entry（PowerShell 变量名不区分大小写）
            foreach ($fileName in @($cacheFiles)) {
                if ([string]$fileName) { $downloads += [string]$fileName }
            }
            if ($downloads.Count -eq 0) {
                foreach ($file in @(Get-ChildItem -LiteralPath $cacheDir -File -ErrorAction SilentlyContinue)) { $downloads += [string]$file.Name }
            }
            $cacheFiles = @($downloads)
            if ($cacheFiles.Count -gt 0) { $cacheHas = $true }
        } elseif ($cacheEntry) {
            $cacheHas = $true
            $cacheDirMissing = $true
        }
    }

    return [ordered]@{
        CompanionVersionLines = @(Get-WinstCompanionVersionLines -Context $Context -Id $Id -Row $Row -Ledger $Entry -CacheIndex $CacheIndex)
        Id               = $Id
        DisplayName      = $displayName
        Group            = $group
        Version          = $versionText
        RawVersion       = $rawVersion
        Type             = $type
        TypeText         = (Get-PlanTypeText -Type $type)
        InstallDir       = $installDir
        InstalledAt      = (Get-EntryString -Entry $Entry -Key 'installedAt')
        UpdatedAt        = (Get-EntryString -Entry $Entry -Key 'updatedAt')
        ManifestOrigin   = (Get-EntryString -Entry $Entry -Key 'manifestOrigin')
        SourceText       = $sourceText
        Managed          = $managed
        ManagedText      = (Get-WinstInstalledManagedText -Managed $managed -Type $type)
        InCatalog        = $inCatalog
        LatestVersion    = $latest
        LatestSource     = $latestSource
        HasUpdate        = $hasUpdate
        UpdateHint       = $updateHint
        UpdateState      = $updateState
        OtherSourcesText = $otherSourcesText
        OldVersions      = @($oldVersions)
        OldVersionsText  = $oldVersionsText
        HasOldVersions   = [bool]($oldVersions.Count -gt 0)
        CacheDir         = $cacheDir
        CacheVersion     = $cacheVersion
        CacheHas         = $cacheHas
        CacheDirMissing  = $cacheDirMissing
        CacheFiles       = @($cacheFiles)
        DirMissing       = $dirMissing
        Row              = $Row
        Ledger           = $Entry
        # 通用视图字段，与缓存和软件列表的同义字段保持一致。
        InstalledVersion      = $versionText
        InstalledVersionText  = $versionText
        InstalledDirMissing   = $dirMissing
        InstalledUpdateState  = $updateState
        InstalledUpdateHint   = $updateHint
        BestVersion           = $latest
        BestSource            = $latestSource
    }
}
