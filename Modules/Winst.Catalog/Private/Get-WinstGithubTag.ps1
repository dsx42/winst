#Requires -Version 5.1

function Get-WinstGithubTag {
    <#
    .SYNOPSIS
        ① 取发布 tag：声明 releaseTag 前缀时取该前缀里版本最高的发布，否则用「最新正式发布」，
        再退回发布列表里版本最高的一条。
    .DESCRIPTION
        - 声明了 `releaseTag` 前缀：在该前缀的发布里按版本号取最高（含预发布，由前缀自行约定）
        - 未声明：优先 `releases/latest`（GitHub 认定的最新**正式**发布，不会命中预发布）；
          取不到时退回列表里版本最高的**非预发布**条目；列表里一条正式发布都没有时，
          用列表第一条（可能是预发布）并在 Notes 里说明
    .OUTPUTS
        @{ Error; Tag; Releases; Notes }
    #>
    param([hashtable]$Context, [string]$Repo, [string]$ReleaseTagPrefix)

    $chosenTag = ''
    $notes = @()

    if (-not $ReleaseTagPrefix) {
        try { $chosenTag = Get-GitHubLatestTag -Context $Context -Repo $Repo } catch { $chosenTag = '' }
        if ($chosenTag) { return @{ Error = ''; Tag = $chosenTag; Releases = @(); Notes = @() } }
    }

    try {
        $releases = @(Get-GitHubReleaseListTags -Context $Context -Repo $Repo)
    } catch {
        return @{ Error = ('无法读取 {0} 的发布列表：{1}' -f $Repo, $_.Exception.Message); Tag = ''; Releases = @(); Notes = @() }
    }

    if ($releases.Count -eq 0) {
        return @{ Error = ('{0} 的近期发布列表中没有找到可用版本；请核对发布页后重试' -f $Repo); Tag = ''; Releases = @(); Notes = @() }
    }
    $matched = @(foreach ($item in $releases) {
        if ($ReleaseTagPrefix) {
            if (([string]$item['Tag']).StartsWith($ReleaseTagPrefix, [StringComparison]::OrdinalIgnoreCase)) { $item }
        } elseif (-not [bool]$item['Prerelease']) { $item }
    })
    if ($matched.Count -eq 0) {
        if ($ReleaseTagPrefix) {
            return @{
                Error = ('{0} 最近的 {1} 个发布里没有以 "{2}" 开头的版本；请核对 GitHub 上的 tag 命名' -f $Repo, $releases.Count, $ReleaseTagPrefix)
                Tag = ''; Releases = $releases; Notes = @()
            }
        }
        $notes += ('{0} 还没有标记为「最新」的正式发布，已改用发布日期最近的一次发布（可能是预发布）。' -f $Repo)
        return @{ Error = ''; Tag = [string]$releases[0]['Tag']; Releases = $releases; Notes = $notes }
    }

    $best = $null
    $bestVersion = ''
    foreach ($item in $matched) {
        $version = Get-WinstGithubTagVersion -Tag ([string]$item['Tag']) -ReleaseTagPrefix $ReleaseTagPrefix
        if ($best -and $version -notmatch '\d') { continue }
        if (-not $best -or $bestVersion -notmatch '\d' -or (Compare-WinstVersion -A $version -B $bestVersion) -gt 0) {
            $best = $item
            $bestVersion = $version
        }
    }
    if (-not $ReleaseTagPrefix) {
        $notes += ('{0} 没有标记为「最新」的正式发布，已改用发布列表里版本最高的正式发布 {1}。' -f $Repo, [string]$best['Tag'])
    }
    return @{ Error = ''; Tag = [string]$best['Tag']; Releases = $releases; Notes = $notes }
}
