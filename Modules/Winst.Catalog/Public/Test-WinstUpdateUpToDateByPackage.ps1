#Requires -Version 5.1

function Test-WinstUpdateUpToDateByPackage {
    <#
    .SYNOPSIS
        三条件判「已是最新」：远端无新包 + 已下载包有版本号 + 已安装版本（或安装台账版本）与包版本一致。
    .DESCRIPTION
        优先用本次检测到的已安装版本；系统安装记录里找不到该软件（检测定义没覆盖 / 记录被清）时，
        退回安装台账里记着的版本——版本号本来就是 winst 从同一个安装包读出来的，
        远端包没变且版本一致就说明没有更新可做，不该为了「版本未知」重跑安装器。
    .OUTPUTS
        @{ UpToDate; Basis }——Basis = detected（系统记录检测值）/ ledger（安装台账版本）/ ''（不成立）
    #>
    param($Snap, [string]$InstalledVersion, [string]$LedgerVersion = '')

    $result = @{ UpToDate = $false; Basis = '' }
    if ($Snap.RemoteFresh -ine 'unchanged') { return $result }
    if (-not $Snap.CachedPackageVersion) { return $result }

    $candidates = @()
    if ($InstalledVersion -and $InstalledVersion -ine 'unknown') {
        $candidates += @{ Version = $InstalledVersion; Basis = 'detected' }
    }
    elseif ($LedgerVersion -and $LedgerVersion -ine 'unknown') {
        $candidates += @{ Version = $LedgerVersion; Basis = 'ledger' }
    }

    foreach ($one in $candidates) {
        $version = [string]$one['Version']
        $cmp = 1
        try { $cmp = Compare-WinstVersion -A $version -B ([string]$Snap.CachedPackageVersion) } catch { $cmp = 1 }
        if ($cmp -eq 0 -or $version -ieq [string]$Snap.CachedPackageVersion) {
            $result.UpToDate = $true
            $result.Basis = [string]$one['Basis']
            return $result
        }
    }
    return $result
}
