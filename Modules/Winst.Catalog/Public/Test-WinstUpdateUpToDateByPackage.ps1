#Requires -Version 5.1

function Test-WinstUpdateUpToDateByPackage {
    <#
    .SYNOPSIS
        远端无新包且已装版本不低于缓存包时，返回无需更新及本机是否较新。
    .DESCRIPTION
        优先用本次检测到的已安装版本；系统安装记录里找不到该软件（检测定义没覆盖 / 记录被清）时，
        退回安装台账里记着的版本——版本号本来就是 winst 从同一个安装包读出来的，
        远端包没变且版本一致就说明没有更新可做，不该为了「版本未知」重跑安装器。
    .OUTPUTS
        @{ UpToDate; Basis; Newer }——Basis = detected（系统记录检测值）/ ledger（安装台账版本）/ ''（不成立）
    #>
    param($Snap, [string]$InstalledVersion, [string]$LedgerVersion = '')

    $result = @{ UpToDate = $false; Basis = ''; Newer = $false }
    if ($Snap.RemoteFresh -ine 'unchanged') { return $result }
    if (-not $Snap.CachedPackageVersion -or $Snap.CachedPackageVersion -ieq 'unknown') { return $result }

    $candidates = @()
    if ($InstalledVersion -and $InstalledVersion -ine 'unknown') {
        $candidates += @{ Version = $InstalledVersion; Basis = 'detected' }
    }
    elseif ($LedgerVersion -and $LedgerVersion -ine 'unknown') {
        $candidates += @{ Version = $LedgerVersion; Basis = 'ledger' }
    }

    foreach ($one in $candidates) {
        $version = [string]$one['Version']
        $cmp = Compare-WinstVersion -A $version -B ([string]$Snap.CachedPackageVersion)
        if ($cmp -ge 0) {
            $result.UpToDate = $true
            $result.Newer = ($cmp -gt 0)
            $result.Basis = [string]$one['Basis']
            return $result
        }
    }
    return $result
}
