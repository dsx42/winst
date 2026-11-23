#Requires -Version 5.1

function Get-WinstMainUpdateVersion {
    <#
    .SYNOPSIS
        版本来自附件时，按上次成功落位的主包摘要判断主包是否仍对应已装版本。
    #>
    param($Ledger, $Plan, [string]$SourceName, [string]$Version, [string]$InstalledVersion, [string]$MainHash)

    $baseline = Get-EntryValue -Entry $Ledger -Key 'companionVersionBaseline'
    if (-not $baseline -or -not $MainHash -or -not $InstalledVersion -or
        $MainHash -ine (Get-EntryString -Entry $baseline -Key 'mainHash') -or
        $SourceName -ine (Get-EntryString -Entry $baseline -Key 'source') -or
        (Compare-WinstVersion -A $InstalledVersion -B (Get-EntryString -Entry $baseline -Key 'installedVersion')) -ne 0) { return $Version }
    $fileRule = Get-EntryString -Entry (Get-EntryValue -Entry $Plan -Key 'packageVersion') -Key 'file'
    if (-not $fileRule) { return $Version }
    $versionInput = Get-WinstPackageVersionInput -Plan $Plan
    if (-not $versionInput -or $versionInput.Index -eq 0) { return $Version }
    $recordedRule = Get-EntryString -Entry $baseline -Key 'fileRule'
    if ($recordedRule) {
        if ($fileRule -ine $recordedRule) { return $Version }
    } elseif ($versionInput.Name -ine (Get-EntryString -Entry $baseline -Key 'file') -or
            $Version -cne (Get-EntryString -Entry $baseline -Key 'version')) {
        return $Version
    }
    return $InstalledVersion
}
