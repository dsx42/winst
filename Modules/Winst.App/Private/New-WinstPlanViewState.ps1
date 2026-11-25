#Requires -Version 5.1

function New-WinstPlanViewState {
    <#
    .SYNOPSIS
        计算渲染软件清单需要的派生值（目录 / 快捷方式路径 / 版本展示口径），供各 Stage 只读使用。
    .OUTPUTS
        [hashtable]
    #>
    param(
        $Plan,
        $CacheEntry,
        [switch]$UseCacheVersion,
        [int]$Index,
        [int]$Total,
        [string]$SourceName,
        [string]$InstallRoot,
        [string]$PkgDir,
        [string]$DesktopDir,
        [string]$StartMenuDir,
        [string]$InstalledVersion,
        [string]$InstalledDir
    )

    $id = Get-EntryString -Entry $Plan -Key 'id'
    $displayName = Get-EntryString -Entry $Plan -Key 'name'
    if (-not $displayName) { $displayName = $id }
    $type = ConvertTo-WinstEntryType -Type (Get-EntryString -Entry $Plan -Key 'type')
    # 仅下载类型（download）：这类软件只有「下载软件包」与「删除已下载的软件包」两件事
    $isDownloadPlanType = ($type -eq 'download')
    $packageNoun = '安装包'
    if ($isDownloadPlanType) { $packageNoun = '软件包' }

    $cacheVersion = Get-EntryString -Entry $CacheEntry -Key 'version'
    $versionText = Get-EntryString -Entry $Plan -Key 'version'
    if ($UseCacheVersion) {
        $versionText = $cacheVersion
        if (-not $versionText) { $versionText = '缓存版本未知' }
    } elseif (Get-EntryBool -Entry $Plan -Key 'versionFromPackage') {
        $versionText = Get-WinstRemoteFreshTargetText -Fresh (Get-EntryString -Entry $Plan -Key 'remoteFresh') -FallbackVersion $cacheVersion
    } elseif (-not $versionText) { $versionText = '未知' }

    $cacheText = ''
    if ($CacheEntry -and -not $UseCacheVersion) {
        if ($cacheVersion) { $cacheText = '缓存版本 ' + $cacheVersion }
        else { $cacheText = '缓存版本未知' }
    }

    # 安装目录一律以 id 命名
    $installDir = ''
    if ($InstallRoot -and $id) { $installDir = Join-WinstPath $InstallRoot $id }

    $pkgTarget = ''
    if ($PkgDir -and $id) { $pkgTarget = Join-WinstPath $PkgDir $id }

    $shortcutName = ''
    $shortcuts = Get-EntryValue -Entry $Plan -Key 'shortcuts' -Default $null
    $desktopOn = Get-EntryBool -Entry $shortcuts -Key 'desktop'
    $startMenuOn = Get-EntryBool -Entry $shortcuts -Key 'startMenu'
    if ($desktopOn -or $startMenuOn) { $shortcutName = ConvertTo-ShortcutName -Name $displayName }
    $desktopLink = ''
    if ($desktopOn -and $DesktopDir -and $shortcutName) { $desktopLink = Join-WinstPath $DesktopDir $shortcutName }
    $startMenuLink = ''
    if ($startMenuOn -and $StartMenuDir -and $shortcutName) { $startMenuLink = Join-WinstPath $StartMenuDir $shortcutName }

    $position = ''
    if ($Total -gt 0) { $position = ('[{0}/{1}] ' -f $Index, $Total) }

    return @{
        Id                 = $id
        DisplayName        = $displayName
        Type               = $type
        IsDownloadType     = $isDownloadPlanType
        PackageNoun        = $packageNoun
        Ok                 = [bool](Get-EntryBool -Entry $Plan -Key 'ok')
        CacheText          = $cacheText
        VersionText        = $versionText
        InstallDir         = $installDir
        InstallRoot        = $InstallRoot
        PkgTarget          = $pkgTarget
        DesktopLink        = $desktopLink
        StartMenuLink      = $startMenuLink
        Position           = $position
        SourceName         = $SourceName
        InstalledVersion   = $InstalledVersion
        InstalledDir       = $InstalledDir
    }
}
