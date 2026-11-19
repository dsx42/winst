#Requires -Version 5.1

function Invoke-WinstUninstallCachePayload {
    <#
    .SYNOPSIS
        只下载类型（理论上不入安装记录）：删除已下载的软件包。
    #>
    param([hashtable]$Context, [string]$Id, [switch]$Quiet)

    # 台账键 → 目录名：与 Remove-WinstCachedPackage 同一道闸，id 越界时不删
    if (-not $Context.PkgDir -or -not (Test-WinstSafePathSegment -Name $Id)) {
        return @{ Abort = $true; Error = ('安装包位置为空或软件 id 不合法，已保留安装记录：' + $Id) }
    }
    $cacheDir = Join-WinstPath $Context.PkgDir $Id
    if (-not (Test-WinstPathUnderRoot -Path $cacheDir -Root $Context.PkgDir)) {
        return @{ Abort = $true; Error = ('缓存目录不在安装包位置之下，已保留安装记录：' + $cacheDir) }
    }
    try {
        if (Test-WinstFileSystemPath -Path $cacheDir) {
            Invoke-WinstFileStep -Name '删除缓存目录' -Quiet:$Quiet -Action { Remove-WinstDirectoryTree -Path $cacheDir }
        }
    } catch {
        return @{ Abort = $true; Error = ('删除缓存目录失败，已保留安装记录：' + $_.Exception.Message) }
    }
    return @{ Abort = $false; Error = '' }
}
