#Requires -Version 5.1

function Invoke-WinstUninstallCachePayload {
    <#
    .SYNOPSIS
        只下载类型（理论上不入安装记录）：删除已下载的软件包。
    #>
    param([hashtable]$Context, [string]$Id, [switch]$Quiet)

    # 台账键 → 目录名：与 Remove-WinstCachedPackage 同一道闸，id 越界时不删
    if (-not $Context.PkgDir -or -not (Test-WinstSafePathSegment -Name $Id)) {
        if (-not $Quiet) { Write-Host ('    提示: 软件 id 不合法，已跳过删除已下载的软件包：{0}' -f $Id) -ForegroundColor DarkYellow }
        return
    }
    $cacheDir = Join-Path $Context.PkgDir $Id
    if (-not (Test-Path -LiteralPath $cacheDir -PathType Container)) { return }
    if (-not $Quiet) { Write-Host ('    正在删除已下载的软件包 {0} …' -f $cacheDir) -ForegroundColor Gray }
    Clear-WinstInstallDir -Dir $cacheDir -AllowedRoot $Context.PkgDir
}
