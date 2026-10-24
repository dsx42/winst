#Requires -Version 5.1

function Write-WinstUpdateCheckUnknownLine {
    <#
    .SYNOPSIS
        检查更新时「版本号取自主包文件信息」条目的报告行。
    #>
    param([string]$DisplayName, [string]$InstalledVersion, $Snap, [string]$Reason, [string]$ActionText, [switch]$Quiet)

    if ($Quiet) { return }
    $installedText = $InstalledVersion
    if (-not $installedText) { $installedText = '未知' }
    if ($Snap.VersionFromPackage -and $Snap.RemoteFresh -ieq 'changed') {
        Write-Host ('  {0}: 当前 {1}  →  新版本（远端有新包，HEAD 检测）  ↑' -f $DisplayName, $installedText) -ForegroundColor Green
    } elseif ($Snap.VersionFromPackage -and $Snap.RemoteFresh -ieq 'unchanged' -and $Snap.CachedPackageVersion) {
        Write-Host ('  {0}: 当前 {1}  →  {2}（远端无新包，取已下载的安装包版本）  ↑' -f $DisplayName, $installedText, [string]$Snap.CachedPackageVersion) -ForegroundColor Green
    } else {
        Write-Host ('  {0}: 无法比较版本（{1}），{2}。' -f $DisplayName, $Reason, $ActionText) -ForegroundColor DarkYellow
    }
}
