#Requires -Version 5.1

function Get-WinstPackageDerivedVersion {
    <#
    .SYNOPSIS
        从「已下载的安装包」派生版本号的路由：声明 source.packageVersion 的条目用 7-Zip 读包内结构
        （权威口径，文件版本信息不可信的安装包）；未声明的条目维持读主包文件信息。
    .DESCRIPTION
        按计划中的 sourceVersionRewrite 归一结果。
    .OUTPUTS
        @{ Ok; Version; Source; MatchedPath; Error }   Source: packagePath（包内结构）/ fileInfo（文件信息）
    #>
    param(
        $Context,
        [string]$PkgDir,
        $Plan,
        [string]$FileName
    )

    $result = @{ Ok = $false; Version = ''; Source = ''; MatchedPath = ''; Error = '' }

    if (-not $PkgDir -or -not (Test-WinstSafePathSegment -Name $FileName)) {
        $result.Error = '缓存里没有可读的安装包'
        return $result
    }
    $packagePath = Join-WinstPath $PkgDir $FileName
    if (-not (Test-Path -LiteralPath $packagePath -PathType Leaf)) {
        $result.Error = '缓存里没有可读的安装包'
        return $result
    }
    $spec = Get-EntryValue -Entry $Plan -Key 'packageVersion' -Default $null

    if ($null -ne $spec) {
        $sevenZip = ''
        if ($Context) { $sevenZip = Get-WinstEngineExe -Context $Context -Id (Get-WinstExtractEngineId) }
        if (-not $sevenZip) {
            $result.Error = '解压引擎（7-Zip-CLI）不可用，无法按包内结构识别版本'
            return $result
        }
        $derived = Get-WinstArchiveInnerVersion -SevenZip $sevenZip -PackagePath $packagePath -Spec $spec
        if (-not $derived.Ok) {
            $result.Error = [string]$derived.Error
            return $result
        }
        $version = [string]$derived.Version
        $result.Source = 'packagePath'
        $result.MatchedPath = [string]$derived.MatchedPath
    } else {
        $version = Get-WinstPackageFileVersion -PkgDir $PkgDir -FileName $FileName
        if (-not $version) {
            $result.Error = '安装包不在缓存里或读不出版本'
            return $result
        }
        $result.Source = 'fileInfo'
    }
    $rules = @(Get-EntryArray -Entry $Plan -Key 'sourceVersionRewrite')
    if ($rules.Count -gt 0) {
        $version = Get-WinstRewrittenVersion -Version $version -Rules $rules
        if (-not $version) {
            $result.Error = 'source.version.rewrite 改写后版本号为空'
            return $result
        }
    }
    $result.Ok = $true
    $result.Version = $version
    return $result
}
