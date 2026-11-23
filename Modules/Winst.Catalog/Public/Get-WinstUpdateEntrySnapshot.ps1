#Requires -Version 5.1

function Get-WinstUpdateEntrySnapshot {
    <#
    .SYNOPSIS
        比较一个可用来源的当前版本和本机版本，包内版本须已确认新鲜度。
    #>
    param([hashtable]$Context, $Chosen, [string]$InstalledVersion, $Ledger)

    $plan = $Chosen['Plan']
    $latest = ''
    $versionFromPackage = Get-EntryBool -Entry $plan -Key 'versionFromPackage'
    $remoteFresh = ''
    if ($versionFromPackage) {
        $remoteFresh = Get-EntryString -Entry $plan -Key 'remoteFresh'
        if ($remoteFresh -ieq 'unchanged') {
            $hash = Get-EntryString -Entry $plan -Key 'remoteFreshHash'
            if ($hash) {
                $matchedMainHash = ''
                $latest = Get-WinstCachedPackageVersion -Context $Context -Plan $plan -MainHash $hash -MatchedMainHash ([ref]$matchedMainHash)
                $latest = Get-WinstMainUpdateVersion -Ledger $Ledger -Plan $plan -SourceName $Chosen['Source'] -Version $latest `
                    -InstalledVersion $InstalledVersion -MainHash $matchedMainHash
            }
        }
    } elseif (-not (Get-EntryBool -Entry $plan -Key 'versionFromCache')) {
        $latest = [string]$Chosen['Version']
    }
    if ($latest -ieq 'unknown') { $latest = '' }

    $comparable = [bool]($InstalledVersion -and $InstalledVersion -ine 'unknown')
    $cmp = 0
    if ($comparable -and $latest) { $cmp = Compare-WinstVersion -A $latest -B $InstalledVersion }

    return @{
        Latest = $latest; LatestSource = [string]$Chosen['Source']; VersionFromPackage = $versionFromPackage
        RemoteFresh = $remoteFresh; Comparable = $comparable; Cmp = $cmp
    }
}
