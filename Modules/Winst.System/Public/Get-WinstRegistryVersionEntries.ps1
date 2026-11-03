#Requires -Version 5.1

function Get-WinstRegistryVersionEntries {
    <#
    .SYNOPSIS
        按统一产品记录与版本规则返回可比较的注册表记录，供目录定位和版本检测共用。
    .OUTPUTS
        @( @{ Entry; Version; CompareVersion } )；Version 尚未改写，CompareVersion 已按检测规则改写。
    #>
    param($Plan, [string]$InstallDir = '', [hashtable]$Status = $null)

    $hits = @(Get-WinstRegistryEntriesForPlan -Plan $Plan -InstallDir $InstallDir -Status $Status)
    if ($null -ne $Status) { $Status.Found = ($hits.Count -gt 0) }
    $nonMsi = @($hits | Where-Object { -not (Test-WinstRegistryEntryIsMsi -Entry $_) })
    if ($nonMsi.Count -gt 0) { $hits = $nonMsi }
    $detect = Get-EntryValue -Entry $Plan -Key 'detect' -Default $null
    $kind = Get-EntryString -Entry $detect -Key 'versionKind'
    $between = @(Get-EntryArray -Entry $detect -Key 'versionBetween')
    $rules = @(Get-EntryArray -Entry $detect -Key 'versionRewrite')
    foreach ($hit in $hits) {
        $raw = Get-EntryString -Entry $hit -Key 'DisplayVersion'
        $version = Get-WinstVersionFromText -Text $raw -Kind $kind -Between $between
        if (-not $version -and -not $kind -and $between.Count -eq 0) { $version = Get-WinstFirstVersionLike -Text $raw }
        if (-not $version) { continue }
        $comparable = Get-WinstRewrittenVersion -Version $version -Rules $rules
        [ordered]@{ Entry = $hit; Version = $version; CompareVersion = $comparable }
    }
}
