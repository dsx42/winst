#Requires -Version 5.1

function Test-WinstUpdateUpToDateByPackage {
    <#
    .SYNOPSIS
        三条件判「已是最新」：远端无新包 + 已下载包有版本号 + 已安装版本与包版本一致。
    .OUTPUTS
        [bool]
    #>
    param($Snap, [string]$InstalledVersion)

    if ($Snap.RemoteFresh -ine 'unchanged') { return $false }
    if (-not $Snap.CachedPackageVersion) { return $false }
    if (-not $InstalledVersion -or $InstalledVersion -eq 'unknown') { return $false }
    if ((Compare-WinstVersion -A $InstalledVersion -B $Snap.CachedPackageVersion) -eq 0) { return $true }
    return ([string]$InstalledVersion -ieq [string]$Snap.CachedPackageVersion)
}
