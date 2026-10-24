#Requires -Version 5.1

function Update-WinstPlanVersionFromPackage {
    <#
    .SYNOPSIS
        下载完成后重读主包版本（versionFromPackage）；版本号原本取自缓存时也要重读一次。
    .OUTPUTS
        [string] 更新后的版本号
    #>
    param([hashtable]$Context, $Plan, $Plans, [string]$PkgDir, [string]$Version, [bool]$VersionFromCachedPackage, [switch]$Quiet)

    if (($Version -and -not $VersionFromCachedPackage) -or -not (Get-EntryBool -Entry $Plan -Key 'versionFromPackage')) {
        return $Version
    }

    # 派生路由：声明 packageVersion 的条目用 7-Zip 读包内结构（权威口径），否则读主包文件信息
    $derivedResult = Get-WinstPackageDerivedVersion -Context $Context -PkgDir $PkgDir -Plan $Plan -FileName ([string]$Plans[0]['Name'])
    if ($derivedResult.Ok) {
        $derived = [string]$derivedResult.Version
        # 同上一处：包内派生的版本按源侧规则 source.versionRewrite 改写
        $rules = @(Get-EntryArray -Entry $Plan -Key 'sourceVersionRewrite')
        if ($rules.Count -gt 0) {
            $rewritten = Get-WinstRewrittenVersion -Version $derived -Rules $rules
            if ($rewritten) { $derived = $rewritten }
        }
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
    if (-not $Quiet) {
        Write-Host ('    提示: 按 packageVersion 读包内版本失败（{0}），版本号沿用既有记录' -f [string]$derivedResult.Error) -ForegroundColor DarkYellow
    }
    return $Version
}
