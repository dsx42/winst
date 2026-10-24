#Requires -Version 5.1

function Get-WinstPackageDerivedVersion {
    <#
    .SYNOPSIS
        从「已下载的安装包」派生版本号的路由：声明 source.packageVersion 的条目用 7-Zip 读包内结构
        （权威口径，文件版本信息不可信的安装包）；未声明的条目维持读主包文件信息。
    .DESCRIPTION
        返回失败时由调用方走「缓存索引 version」回退（上次下载完成时按同一套口径写入的值）。
        规格来自计划里编译好的 packageVersion 块（解析锁里读回的是 PSCustomObject，统一走 Get-Entry* 助手）。
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

    $spec = Get-EntryValue -Entry $Plan -Key 'packageVersion' -Default $null
    if ($null -ne $spec) {
        # 主包路径：规格声明 file 时按通配在包目录里找；否则用调用方给的主包名
        $packagePath = ''
        $fileGlob = ([string](Get-EntryString -Entry $spec -Key 'file')).Trim()
        if ($PkgDir -and (Test-Path -LiteralPath $PkgDir -PathType Container)) {
            if ($fileGlob) {
                $hit = @(Get-ChildItem -LiteralPath $PkgDir -File -ErrorAction SilentlyContinue | Where-Object { $_.Name -like $fileGlob } | Select-Object -First 1)
                if ($hit.Count -gt 0) { $packagePath = [string]$hit[0].FullName }
            }
            if (-not $packagePath -and $FileName) {
                $candidate = Join-Path $PkgDir $FileName
                if (Test-Path -LiteralPath $candidate -PathType Leaf) { $packagePath = $candidate }
            }
        }
        if (-not $packagePath) {
            $result.Error = '缓存里没有可读的安装包，无法按包内结构识别版本'
            return $result
        }
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
        $result.Ok = $true
        $result.Version = [string]$derived.Version
        $result.Source = 'packagePath'
        $result.MatchedPath = [string]$derived.MatchedPath
        return $result
    }

    # 未声明规格：读主包文件信息
    $fileVersion = ''
    if ($PkgDir -and $FileName) { $fileVersion = Get-WinstPackageFileVersion -PkgDir $PkgDir -FileName $FileName }
    if ($fileVersion) {
        $result.Ok = $true
        $result.Version = [string]$fileVersion
        $result.Source = 'fileInfo'
        return $result
    }
    $result.Error = '安装包不在缓存里或读不出版本'
    return $result
}
