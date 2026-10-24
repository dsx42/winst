#Requires -Version 5.1

function Get-WinstPackageFacet {
    <#
    .SYNOPSIS
        由缓存版本、文件与共用行事实生成各列表一致的安装包状态和更新结论。
    #>
    param(
        [Parameter(Mandatory = $true)]$Facts,
        [string]$CacheVersion = '',
        [string[]]$CacheFiles = @(),
        [switch]$Evaluate
    )

    $state = 'missing'
    $hint = ''
    $hasUpdate = $false
    if ($Evaluate -and $Facts.InCatalog) {
        $verdict = Get-WinstUpdateVerdict -ForPackage -BestVersion ([string]$Facts.BestVersion) `
            -CurrentVersion $CacheVersion -VersionFromPackage ([bool]$Facts.VersionFromPackage) `
            -RemoteFresh ([string]$Facts.RemoteFresh)
        $state = $verdict.State
        $hint = $verdict.Hint
        $hasUpdate = $verdict.HasUpdate
    }
    $versionText = '未知'
    if ($CacheVersion) { $versionText = $CacheVersion }

    return [ordered]@{
        Has         = [bool](@($CacheFiles).Count -gt 0)
        Version     = $CacheVersion
        VersionText = $versionText
        State       = $state
        Hint        = $hint
        HasUpdate   = $hasUpdate
    }
}
