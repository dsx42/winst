#Requires -Version 5.1

function Get-WinstUpdateEntrySnapshot {
    <#
    .SYNOPSIS
        比较一个可用来源的当前版本和本机版本，包内版本须已确认新鲜度。
    #>
    param($Chosen, [string]$InstalledVersion)

    $plan = $Chosen['Plan']
    $latest = [string]$Chosen['Version']
    $versionFromPackage = Get-EntryBool -Entry $plan -Key 'versionFromPackage'
    $remoteFresh = Get-EntryString -Entry $plan -Key 'remoteFresh'
    if ($latest -ieq 'unknown') { $latest = '' }

    $comparable = [bool]($InstalledVersion -and $InstalledVersion -ine 'unknown')
    $cmp = 0
    if ($comparable -and $latest) { $cmp = Compare-WinstVersion -A $latest -B $InstalledVersion }

    return @{
        Latest = $latest; LatestSource = [string]$Chosen['Source']; VersionFromPackage = $versionFromPackage
        RemoteFresh = $remoteFresh; Comparable = $comparable; Cmp = $cmp
    }
}
