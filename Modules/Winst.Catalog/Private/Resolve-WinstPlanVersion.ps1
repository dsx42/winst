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
        [hashtable]$Context,
        $Notes,
        $PackageVersionSpec
    )

    $notes = @($Notes)
    $version = [string]$Plan['version']
    $versionAlreadyNormalized = $false

    # 来源原始读数在此归一；索引已有版本不再改写。下载声明已使用来源原始版本展开，
    # 随后的安装计划字段使用归一后的版本；本机检测由 detect.versionRewrite 独立处理。
    $sourceNode = Get-EntryValue -Entry $Entry -Key 'source' -Default $null
    $rewrite = New-WinstVersionRewriteRules -Spec (Get-EntryValue -Entry $sourceNode -Key 'versionRewrite' -Default $null)
    if (-not $rewrite.Ok) {
        $Plan['error'] = ('source.versionRewrite 有误: {0}' -f $rewrite.Error)
        $Plan['notes'] = $notes
        return @{ Version = $version; Notes = $notes; Error = [string]$Plan['error'] }
    }
    if ($rewrite.Rules.Count -gt 0) { $Plan['sourceVersionRewrite'] = @($rewrite.Rules) }

    # 取版规则和改写规则均匹配时，索引里的版本已经归一。
    $versionFromPackage = Test-EntryVersionFromPackage -Entry $Entry
    if ($versionFromPackage) {
        $Plan['versionFromPackage'] = $true
        if ($PackageVersionSpec) { $Plan['packageVersion'] = $PackageVersionSpec }
        if (-not $version) {
            $version = Get-WinstCachedPackageVersion -Context $Context -Plan $Plan
            if ($version) {
                $Plan['version'] = $version
                $Plan['versionFromCache'] = $true
                $versionAlreadyNormalized = $true
                $notes += ('版本号取自本地缓存包: {0}' -f $version)
            }
        }
    }

    if ($rewrite.Rules.Count -gt 0 -and $version -and -not $versionAlreadyNormalized) {
        $rewrittenVersion = Get-WinstRewrittenVersion -Version $version -Rules $rewrite.Rules
        if (-not $rewrittenVersion) {
            $Plan['error'] = ('source.versionRewrite 改写后版本号为空（软件源里的版本是 {0}）；请检查 pattern / replace' -f $version)
            $Plan['notes'] = $notes
            return @{ Version = $version; Notes = $notes; Error = [string]$Plan['error'] }
        }
        $Plan['sourceVersion'] = $version
        $Plan['version'] = $rewrittenVersion
        if ($rewrittenVersion -ne $version) {
            $notes += ('版本号已统一写作 {0}（软件源里是 {1}）' -f $rewrittenVersion, $version)
            $Plan['notes'] = $notes
        }
        $version = $rewrittenVersion
    }

    return @{ Version = $version; Notes = $notes; Error = '' }
}
