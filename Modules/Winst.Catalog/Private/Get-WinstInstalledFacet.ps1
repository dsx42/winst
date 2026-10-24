#Requires -Version 5.1

function Get-WinstInstalledFacet {
    <#
    .SYNOPSIS
        由安装记录与共用行事实生成各列表一致的安装状态和更新结论。
    #>
    param($Ledger, [Parameter(Mandatory = $true)]$Facts)

    $installed = [bool]($null -ne $Ledger)
    $version = ''
    $dirMissing = $false
    $state = ''
    $hint = ''
    $hasUpdate = $false
    if ($installed) {
        $version = Get-EntryString -Entry $Ledger -Key 'version'
        $installDir = Get-EntryString -Entry $Ledger -Key 'installDir'
        if ($installDir -and -not (Test-Path -LiteralPath $installDir -PathType Container)) { $dirMissing = $true }
        if (-not $Facts.InCatalog) {
            $state = 'missing'
        } else {
            $verdict = Get-WinstUpdateVerdict -BestVersion ([string]$Facts.BestVersion) -CurrentVersion $version `
                -VersionFromPackage ([bool]$Facts.VersionFromPackage) -RemoteFresh ([string]$Facts.RemoteFresh) -Row $Facts.Row
            $state = $verdict.State
            $hint = $verdict.Hint
            $hasUpdate = $verdict.HasUpdate
        }
    }
    $versionText = '未知'
    if ($version) { $versionText = $version }

    return [ordered]@{
        Installed   = $installed
        Version     = $version
        VersionText = $versionText
        DirMissing  = $dirMissing
        UpdateState = $state
        UpdateHint  = $hint
        HasUpdate   = $hasUpdate
    }
}
