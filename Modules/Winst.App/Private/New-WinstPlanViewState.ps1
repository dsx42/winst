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
        [int]$Index = 0,
        [int]$Total = 0,
        [string]$SourceName = '',
        [string]$InstallRoot = '',
        [string]$PkgDir = '',
        [string]$DesktopDir = '',
        [string]$StartMenuDir = '',
        [string]$InstalledVersion = '',
        [string]$InstalledDir = ''
    )

    $id = Get-EntryString -Entry $Plan -Key 'id'
    $displayName = Get-EntryString -Entry $Plan -Key 'name'
    if (-not $displayName) { $displayName = $id }
    $type = ConvertTo-WinstEntryType -Type (Get-EntryString -Entry $Plan -Key 'type')
    # 仅下载类型（download）：这类软件只有「下载软件包」与「删除已下载的软件包」两件事
    $isDownloadPlanType = (([string]$type).Trim().ToLowerInvariant() -eq 'download')
    $packageNoun = '安装包'
    if ($isDownloadPlanType) { $packageNoun = '软件包' }

    $version = Get-EntryString -Entry $Plan -Key 'version'
    $versionText = $version
    if (-not $versionText) { $versionText = '未知' }
    # 版本号取自「缓存里那份包」：远端无新包（remoteFresh unchanged）
    # 时缓存里那份就是软件源当前这一份，版本号即确认值；远端有新包 / 没比出结论时才标「取包后确认」
    $versionFromCache = [bool](Get-EntryBool -Entry $Plan -Key 'versionFromCache')
    $versionNeedsConfirm = ($versionFromCache -and ([string](Get-EntryString -Entry $Plan -Key 'remoteFresh')) -ine 'unchanged')

    # 安装目录一律以 id 命名
    $installDir = ''
    if ($InstallRoot -and $id) { $installDir = Join-Path $InstallRoot $id }

    $pkgTarget = ''
    if ($PkgDir -and $id) { $pkgTarget = Join-Path $PkgDir $id }

    $shortcutName = ConvertTo-ShortcutName -Name $displayName
    $desktopLink = ''
    if ($DesktopDir -and $shortcutName) { $desktopLink = Join-Path $DesktopDir $shortcutName }
    $startMenuLink = ''
    if ($StartMenuDir -and $shortcutName) { $startMenuLink = Join-Path $StartMenuDir $shortcutName }

    $position = ''
    if ($Total -gt 0) { $position = ('[{0}/{1}] ' -f $Index, $Total) }

    return @{
        Id                 = $id
        DisplayName        = $displayName
        Type               = $type
        IsDownloadType     = $isDownloadPlanType
        PackageNoun        = $packageNoun
        Ok                 = [bool](Get-EntryBool -Entry $Plan -Key 'ok')
        Version            = $version
        VersionText        = $versionText
        VersionNeedsConfirm = $versionNeedsConfirm
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
