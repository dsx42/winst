#Requires -Version 5.1

function Get-WinstGithubTag {
    <#
    .SYNOPSIS
        ① 取发布 tag：声明 releaseTag 前缀时取该前缀里版本最高的发布，否则用「最新正式发布」，
        再退回发布列表里版本最高的一条。
    .DESCRIPTION
        发布列表统一取自 `releases` 列表页（`Get-GitHubReleaseListTags`）：它给出全部近期发布，
        含标题 / 正文 / 时间 / 预发布标记，而 `releases.atom` 只含最近约 10 条且与真实列表可能
        完全脱节（adoptium 的 temurin 仓库 feed 里是上一年的 nightly beta）。

        - 声明了 `releaseTag` 前缀：在该前缀的发布里按版本号取最高（含预发布，由前缀自行约定）
        - 未声明：优先 `releases/latest`（GitHub 认定的最新**正式**发布，不会命中预发布）；
          取不到时退回列表里版本最高的**非预发布**条目
    .OUTPUTS
        @{ Error; Tag; Releases; Notes }
    #>
    param([hashtable]$Context, [string]$Repo, [string]$ReleaseTagPrefix = '')

    $chosenTag = ''
    $releases = @()
    $notes = @()

    try {
        $releases = @(Get-GitHubReleaseListTags -Context $Context -Repo $Repo)
    } catch {
        return @{ Error = ('无法读取 {0} 的发布列表：{1}' -f $Repo, $_.Exception.Message); Tag = ''; Releases = @(); Notes = @() }
    }

    if ($ReleaseTagPrefix) {
        # 同一仓库按产品线分开发布（如 cli-v*）：筛选前缀后按版本号取最高
        $matched = @()
        foreach ($item in $releases) {
            $candidateTag = [string]$item['Tag']
            if (-not $candidateTag) { continue }
            if (-not $candidateTag.StartsWith($ReleaseTagPrefix, [StringComparison]::OrdinalIgnoreCase)) { continue }
            $matched += $item
        }
        if ($matched.Count -eq 0) {
            if ($releases.Count -eq 0) {
                return @{ Error = ('{0} 这个仓库还没有发布任何版本；等发布后再刷新即可' -f $Repo); Tag = ''; Releases = $releases; Notes = @() }
            }
            return @{
                Error = ('{0} 最近的 {1} 个发布里没有以 "{2}" 开头的版本；请核对 GitHub 上的 tag 命名' -f $Repo, $releases.Count, $ReleaseTagPrefix)
                Tag = ''; Releases = $releases; Notes = @()
            }
        }
        # 前缀内部的版本线也可能有多条（cli-v1 / cli-v2）：按版本号取最高
        $best = $null
        $bestKey = ''
        foreach ($item in $matched) {
            $key = Get-WinstVersionSortKey -Version ([string]$item['Tag'])
            if (-not $best -or [string]::CompareOrdinal($key, $bestKey) -gt 0) {
                $best = $item
                $bestKey = $key
            }
        }
        return @{ Error = ''; Tag = [string]$best['Tag']; Releases = $releases; Notes = @() }
    }

    # 未声明前缀 → 用 GitHub 自己认定的「最新正式发布」（不会命中预发布）
    try {
        $chosenTag = Get-GitHubLatestTag -Context $Context -Repo $Repo
    } catch {
        $chosenTag = ''
    }
    if ($chosenTag) { return @{ Error = ''; Tag = $chosenTag; Releases = $releases; Notes = @() } }

    # 仓库只有预发布时 releases/latest 会跳到发布列表页（取不到 tag）：退回列表里版本最高的正式发布
    $stable = @()
    foreach ($item in $releases) {
        if ([bool]$item['Prerelease']) { continue }
        $stable += $item
    }
    if ($stable.Count -eq 0) {
        if ($releases.Count -eq 0) {
            return @{ Error = ('{0} 这个仓库还没有发布任何版本；等发布后再刷新即可' -f $Repo); Tag = ''; Releases = @(); Notes = @() }
        }
        $notes += ('{0} 还没有标记为「最新」的正式发布，已改用发布日期最近的一次发布（可能是预发布）。' -f $Repo)
        return @{ Error = ''; Tag = [string]$releases[0]['Tag']; Releases = $releases; Notes = $notes }
    }

    $best = $null
    $bestKey = ''
    foreach ($item in $stable) {
        $key = Get-WinstVersionSortKey -Version ([string]$item['Tag'])
        if (-not $best -or [string]::CompareOrdinal($key, $bestKey) -gt 0) {
            $best = $item
            $bestKey = $key
        }
    }
    $notes += ('{0} 没有标记为「最新」的正式发布，已改用发布列表里版本最高的正式发布 {1}。' -f $Repo, [string]$best['Tag'])
    return @{ Error = ''; Tag = [string]$best['Tag']; Releases = $releases; Notes = $notes }
}
