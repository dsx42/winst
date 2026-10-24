#Requires -Version 5.1

function Get-WinstGithubTag {
    <#
    .SYNOPSIS
        ① 取发布 tag：声明 releaseTag 前缀时按前缀过滤 feed，否则用「最新正式发布」，再退回最近一次发布。
    .OUTPUTS
        @{ Error; Tag; Releases; Notes }
    #>
    param([hashtable]$Context, [string]$Repo, [string]$ReleaseTagPrefix = '')

    $chosenTag = ''
    $releases = @()
    $notes = @()

    if ($ReleaseTagPrefix) {
        # 声明了 tag 前缀（同一仓库按产品线分开发布，如 cli-v*）→ 用 Atom feed 过滤，含预发布
        try {
            $releases = @(Get-GitHubReleaseTags -Context $Context -Repo $Repo)
        } catch {
            return @{ Error = ('无法读取 {0} 的发布列表：{1}' -f $Repo, $_.Exception.Message); Tag = ''; Releases = @(); Notes = @() }
        }
        foreach ($item in $releases) {
            $candidateTag = [string]$item['Tag']
            if ($candidateTag.StartsWith($ReleaseTagPrefix, [StringComparison]::OrdinalIgnoreCase)) {
                $chosenTag = $candidateTag
                break
            }
        }
        if (-not $chosenTag) {
            if ($releases.Count -eq 0) {
                return @{ Error = ('{0} 这个仓库还没有发布任何版本；等发布后再刷新即可' -f $Repo); Tag = ''; Releases = $releases; Notes = @() }
            }
            return @{
                Error = ('{0} 最近的 {1} 个发布里没有以 "{2}" 开头的版本；请核对 GitHub 上的 tag 命名' -f $Repo, $releases.Count, $ReleaseTagPrefix)
                Tag = ''; Releases = $releases; Notes = @()
            }
        }
        return @{ Error = ''; Tag = $chosenTag; Releases = $releases; Notes = @() }
    }

    # 未声明前缀 → 用 GitHub 自己认定的「最新正式发布」（Atom feed 的顺序对个别仓库并不等于最新）
    try {
        $chosenTag = Get-GitHubLatestTag -Context $Context -Repo $Repo
    } catch {
        $chosenTag = ''
    }
    if ($chosenTag) { return @{ Error = ''; Tag = $chosenTag; Releases = $releases; Notes = @() } }

    try {
        $releases = @(Get-GitHubReleaseTags -Context $Context -Repo $Repo)
    } catch {
        return @{ Error = ('无法读取 {0} 的发布列表：{1}' -f $Repo, $_.Exception.Message); Tag = ''; Releases = @(); Notes = @() }
    }
    if ($releases.Count -eq 0) {
        return @{ Error = ('{0} 这个仓库还没有发布任何版本；等发布后再刷新即可' -f $Repo); Tag = ''; Releases = @(); Notes = @() }
    }
    $notes += '这个仓库没有标记为「最新」的正式发布，已改用发布日期最近的一次发布。'
    return @{ Error = ''; Tag = [string]$releases[0]['Tag']; Releases = $releases; Notes = $notes }
}
