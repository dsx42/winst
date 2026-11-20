#Requires -Version 5.1

function Test-WinstUpdateUpToDateByPackage {
    <#
    .SYNOPSIS
        远端无新包时，比较本机版本与已下载的安装包版本。
    .OUTPUTS
        UpToDate 表示本机版本不低于安装包，Newer 表示本机版本更高。
    #>
    param($Snap, [string]$InstalledVersion)

    $result = @{ UpToDate = $false; Newer = $false }
    if ($Snap.RemoteFresh -ine 'unchanged') { return $result }
    if (-not $Snap.CachedPackageVersion -or $Snap.CachedPackageVersion -ieq 'unknown') { return $result }
    if (-not $InstalledVersion -or $InstalledVersion -ieq 'unknown') { return $result }

    $cmp = Compare-WinstVersion -A $InstalledVersion -B ([string]$Snap.CachedPackageVersion)
    $result.UpToDate = ($cmp -ge 0)
    $result.Newer = ($cmp -gt 0)
    return $result
}
