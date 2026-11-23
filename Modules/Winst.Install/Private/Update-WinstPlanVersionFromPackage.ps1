#Requires -Version 5.1

function Update-WinstPlanVersionFromPackage {
    <#
    .SYNOPSIS
        未登记包内版本或替换相关缓存后，从实际选中的文件取版。
    #>
    param([hashtable]$Context, $Plan, [string]$PkgDir, [string]$InputName, [string]$Version, [switch]$Quiet)

    if ($Version -or -not (Get-EntryBool -Entry $Plan -Key 'versionFromPackage')) { return $Version }
    $derivedResult = Get-WinstPackageDerivedVersion -Context $Context -PkgDir $PkgDir -Plan $Plan -FileName $InputName
    if (-not $derivedResult.Ok) {
        throw ('无法读取安装包版本：{0}' -f [string]$derivedResult.Error)
    }
    $derived = [string]$derivedResult.Version
    $null = Set-EntryValue -Entry $Plan -Key 'version' -Value $derived
    if (-not $Quiet) {
        if ([string]$derivedResult.Source -eq 'packagePath') {
            Write-Host ('    版本号取自安装包内结构（packageVersion 命中 {0}）: {1}' -f ([string]$derivedResult.MatchedPath), $derived) -ForegroundColor Gray
        } else {
            Write-Host ('    版本号取自已下载的安装包文件信息: {0}' -f $derived) -ForegroundColor Gray
        }
    }
    return $derived
}