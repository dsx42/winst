#Requires -Version 5.1

function Read-WinstPackageVersion {
    <#
    .SYNOPSIS
        按清单从选中的缓存文件读取并归一软件版本。
    #>
    param([hashtable]$Context, $Plan, [string]$PkgDir, [string]$InputName, [switch]$Quiet)

    $derivedResult = Get-WinstPackageDerivedVersion -Context $Context -PkgDir $PkgDir -Plan $Plan -FileName $InputName
    if (-not $derivedResult.Ok) {
        throw ('无法读取安装包版本：{0}' -f [string]$derivedResult.Error)
    }
    $derived = [string]$derivedResult.Version
    if (-not $Quiet) {
        if ([string]$derivedResult.Source -eq 'packagePath') {
            Write-Host ('    版本号取自安装包内结构（packageVersion 命中 {0}）: {1}' -f ([string]$derivedResult.MatchedPath), $derived) -ForegroundColor Gray
        } else {
            Write-Host ('    版本号取自已下载的安装包文件信息: {0}' -f $derived) -ForegroundColor Gray
        }
    }
    return $derived
}
