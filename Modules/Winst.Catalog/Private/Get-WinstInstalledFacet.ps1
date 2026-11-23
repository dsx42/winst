#Requires -Version 5.1

function Get-WinstInstalledFacet {
    <#
    .SYNOPSIS
        由安装记录与共用行事实生成各列表一致的安装状态和更新结论。
    #>
    param([hashtable]$Context, $Ledger, $Row, [hashtable]$Lookup)

    $installed = [bool]($null -ne $Ledger)
    $version = ''
    $dirMissing = $false
    $state = ''
    $hint = ''
    $hasUpdate = $false
    $chosen = $null
    $latest = ''
    $latestSource = ''
    if ($installed) {
        $version = Get-EntryString -Entry $Ledger -Key 'version'
        $installDir = Get-EntryString -Entry $Ledger -Key 'installDir'
        if ($installDir -and -not (Test-Path -LiteralPath $installDir -PathType Container)) { $dirMissing = $true }
        if (-not $Row) {
            $state = 'missing'
        } else {
            $chosen = Get-WinstDefaultUpdateSource -Context $Context -Row $Row -Ledger $Ledger -InstalledVersion $version -Lookup $Lookup
            $state = 'unknown'
            if ($chosen) {
                $snap = Get-WinstUpdateEntrySnapshot -Context $Context -Chosen $chosen -InstalledVersion $version -Ledger $Ledger
                $latest = $snap.Latest
                $latestSource = $snap.LatestSource
                $verdict = Get-WinstUpdateVerdict -BestVersion $latest -CurrentVersion $version -BestSource $latestSource `
                    -VersionFromPackage $snap.VersionFromPackage -RemoteFresh $snap.RemoteFresh
                $state = $verdict.State
                $hint = $verdict.Hint
                $hasUpdate = $verdict.HasUpdate
            }
        }
    }
    $versionText = '未知'
    if ($version) { $versionText = $version }

    return [ordered]@{
        Chosen      = $chosen
        Latest      = $latest
        LatestSource = $latestSource
        Installed   = $installed
        Version     = $version
        VersionText = $versionText
        DirMissing  = $dirMissing
        UpdateState = $state
        UpdateHint  = $hint
        HasUpdate   = $hasUpdate
    }
}
