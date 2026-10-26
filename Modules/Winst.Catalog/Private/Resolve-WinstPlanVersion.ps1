#Requires -Version 5.1

function Resolve-WinstPlanVersion {
    <#
    .SYNOPSIS
        确定条目的版本号：versionFromPackage 从已下载主包派生，源侧 versionRewrite 归一写法。
    .OUTPUTS
        @{ Version; Notes; Error }
    #>
    param(
        $Plan,
        $Entry,
        [string]$PkgDir = '',
        $Context = $null,
        $Notes = @()
    )

    $notes = @($Notes)
    $version = [string]$Plan['version']
    $id = [string]$Plan['id']
    $fileList = @($Plan['download']['files'])

    # 清单 / 接口都拿不到版本号时，可以从「已下载的主包」里取：
    # 这里先看缓存里有没有现成的包（下载流程结束时还会再读一次并写进缓存索引）。
    $versionFromPackage = Test-EntryVersionFromPackage -Entry $Entry
    if ($versionFromPackage) {
        $Plan['versionFromPackage'] = $true
        # source.packageVersion：编译进计划，解析期派生 / 下载完成后重读共用；
        # 校验已在来源解析时做过，这里只是再取一次（清单加载侧改写不会碰这个字段）
        $packageVersionSpec = Get-WinstPackageVersionSpec -Source (Get-EntryValue -Entry $Entry -Key 'source' -Default $null)
        if ($packageVersionSpec.Ok -and $packageVersionSpec.Spec) { $Plan['packageVersion'] = $packageVersionSpec.Spec }
        if (-not $version) {
            $mainName = ''
            if ($fileList.Count -gt 0) {
                $mainName = Get-EntryString -Entry $fileList[0] -Key 'name'
                if (-not $mainName) { $mainName = Get-FileNameFromUrl -Url ([string]$fileList[0]['url']) }
            }
            $derived = ''
            $deriveNote = ''
            $deriveError = ''
            if ($PkgDir -and $mainName) {
                $derivedResult = Get-WinstPackageDerivedVersion -Context $Context -PkgDir (Join-WinstPath $PkgDir $id) -Plan $Plan -FileName $mainName
                if ($derivedResult.Ok) {
                    $derived = [string]$derivedResult.Version
                    if ([string]$derivedResult.Source -eq 'packagePath') {
                        $deriveNote = ('版本号取自安装包内结构（packageVersion 命中 {0}）: {1}' -f ([string]$derivedResult.MatchedPath), $derived)
                    } else {
                        $deriveNote = ('版本号取自已下载的安装包文件信息: {0}' -f $derived)
                    }
                } else {
                    $deriveError = [string]$derivedResult.Error
                }
            }
            $fromIndex = $false
            if (-not $derived -and $PkgDir) {
                # 包内派生不出（没下载过 / 包内结构变化 / 引擎不可用）：退而读缓存索引——下载完成时已把
                # 按同一套口径确认的版本号写进索引，同样只代表「缓存里那份」
                $indexRead = Read-WinstCacheIndex -PkgDir $PkgDir
                if ($indexRead -and -not $indexRead.Error -and $indexRead.Index.Contains($id)) {
                    $derived = ([string](Get-EntryString -Entry $indexRead.Index[$id] -Key 'version')).Trim()
                    $fromIndex = [bool]$derived
                }
            }
            if ($derived) {
                $version = $derived
                $Plan['version'] = $derived
                # 记下「这个版本号取自缓存里那份包」：它不是软件源当前这一份的版本，展示与判断都要区别对待
                $Plan['versionFromCache'] = $true
                if ($fromIndex) {
                    $noteText = ('版本号取自已下载的安装包（缓存索引里上次下载时确认的）: {0}' -f $derived)
                    if ($deriveError) { $noteText += ('（按 packageVersion 读包内版本失败: {0}）' -f $deriveError) }
                    $notes += $noteText
                } elseif ($deriveNote) {
                    $notes += $deriveNote
                }
                $Plan['notes'] = $notes
            }
        }
    }

    # 版本号写法归一：**源侧**解析出的版本（tag / 文件名 / 页面 / 接口，以及 source.versionFrom: "package"
    # 从包内文件信息取到的那个）按 source.versionRewrite 改写后再用于比较 / 展示 / 写台账；**本机检测**出的版本
    # 由 detect.versionRewrite 负责（编译后的规则放进 detect 块，见下方 ⑥）。{version} 占位符仍用上游原始版本
    # 展开（下载文件名带的是上游写法），改写前的值记在 sourceVersion 里。
    $sourceNode = Get-EntryValue -Entry $Entry -Key 'source' -Default $null
    $rewrite = New-WinstVersionRewriteRules -Spec (Get-EntryValue -Entry $sourceNode -Key 'versionRewrite' -Default $null)
    if (-not $rewrite.Ok) {
        $Plan['error'] = ('source.versionRewrite 有误: {0}' -f $rewrite.Error)
        $Plan['notes'] = $notes
        return @{ Version = $version; Notes = $notes; Error = [string]$Plan['error'] }
    }
    if ($rewrite.Rules.Count -gt 0 -and $version) {
        $rewrittenVersion = Get-WinstRewrittenVersion -Version $version -Rules $rewrite.Rules
        if (-not $rewrittenVersion) {
            $Plan['error'] = ('source.versionRewrite 改写后版本号为空（软件源里的版本是 {0}）；请检查 pattern / replace' -f $version)
            $Plan['notes'] = $notes
            return @{ Version = $version; Notes = $notes; Error = [string]$Plan['error'] }
        }
        $Plan['sourceVersion'] = $version
        $Plan['sourceVersionRewrite'] = @($rewrite.Rules)
        $Plan['version'] = $rewrittenVersion
        if ($rewrittenVersion -ne $version) {
            $notes += ('版本号已统一写作 {0}（软件源里是 {1}）' -f $rewrittenVersion, $version)
            $Plan['notes'] = $notes
        }
        $version = $rewrittenVersion
    }

    return @{ Version = $version; Notes = $notes; Error = '' }
}
