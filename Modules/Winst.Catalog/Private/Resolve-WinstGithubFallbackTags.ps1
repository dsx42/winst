#Requires -Version 5.1

function Resolve-WinstGithubFallbackTags {
    <#
    .SYNOPSIS
        按版本从高到低返回严格早于所选发布、且符合发布通道的候选。
    .DESCRIPTION
        未限定 releaseTag 时只使用正式发布；所选发布本身为预发布时允许同通道候选。
        releaseTag 前缀允许该前缀的预发布。无法比较版本的候选不进入自动回退。
    #>
    param(
        [hashtable]$Context,
        [Parameter(Mandatory = $true)][string]$Repo,
        [string]$ChosenTag = '',
        $Releases = @(),
        [string]$ReleaseTagPrefix = ''
    )

    $releaseItems = @($Releases)
    if ($releaseItems.Count -eq 0) { $releaseItems = @(Get-GitHubReleaseListTags -Context $Context -Repo $Repo) }
    $chosenKey = Get-WinstVersionSortKey -Version $ChosenTag
    if (-not $chosenKey) { return @() }
    $allowPrerelease = [bool]$ReleaseTagPrefix
    foreach ($item in $releaseItems) {
        if ((Get-EntryString -Entry $item -Key 'Tag') -ceq $ChosenTag) {
            if (Get-EntryBool -Entry $item -Key 'Prerelease') { $allowPrerelease = $true }
            break
        }
    }

    $seen = New-Object 'System.Collections.Generic.HashSet[string]' ([StringComparer]::Ordinal)
    $pool = @()
    $sequence = 0
    foreach ($item in $releaseItems) {
        $tag = Get-EntryString -Entry $item -Key 'Tag'
        if (-not $tag -or $tag -ceq $ChosenTag -or -not $seen.Add($tag)) { continue }
        if (-not $allowPrerelease -and (Get-EntryBool -Entry $item -Key 'Prerelease')) { continue }
        if ($ReleaseTagPrefix -and -not $tag.StartsWith($ReleaseTagPrefix, [StringComparison]::OrdinalIgnoreCase)) { continue }
        $key = Get-WinstVersionSortKey -Version $tag
        if (-not $key) { continue }
        $candidateVersion = $tag
        $chosenVersion = $ChosenTag
        if ($ReleaseTagPrefix) {
            $candidateVersion = $candidateVersion.Substring($ReleaseTagPrefix.Length)
            if ($chosenVersion.StartsWith($ReleaseTagPrefix, [StringComparison]::OrdinalIgnoreCase)) {
                $chosenVersion = $chosenVersion.Substring($ReleaseTagPrefix.Length)
            }
        }
        if ((Compare-WinstVersion -A $candidateVersion -B $chosenVersion) -ge 0) { continue }
        $sequence++
        $pool += @{ Tag = $tag; Version = $candidateVersion; Sequence = $sequence }
    }
    $sorted = New-Object 'System.Collections.Generic.List[object]'
    foreach ($item in $pool) {
        $at = 0
        while ($at -lt $sorted.Count -and (Compare-WinstVersion -A $item.Version -B $sorted[$at].Version) -le 0) { $at++ }
        $sorted.Insert($at, $item)
    }
    return @($sorted | ForEach-Object { [string]$_['Tag'] })
}
