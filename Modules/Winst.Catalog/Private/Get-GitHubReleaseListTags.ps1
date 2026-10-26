#Requires -Version 5.1

function Get-GitHubReleaseListTags {
    <#
    .SYNOPSIS
        读取 GitHub 仓库 releases 列表页里的发布（tag / 标题 / 正文 / 是否预发布），走网页、不消耗 API 配额。
    .DESCRIPTION
        列表页是发布信息的**完整来源**：每条发布都带 tag 链接、标题、正文（`markdown-body`）与
        `Pre-release` 标记。`releases.atom` 只给最近约 10 条，而且与真实列表可能完全脱节
        （adoptium 的 temurin21/temurin25 feed 里是 2023 年的 nightly beta，近期正式版一条都没有），
        因此统一以列表页为准。
        每页 10 条，按页面顺序取。**页内顺序是 GitHub 的展示顺序，不代表版本高低**
        （temurin21 页面上 `21.0.9+10` 排在 `21.0.13+9` 前面），调用方需要自己按版本排序。
    .OUTPUTS
        @( @{ Tag; Title; Body; UpdatedAt; Prerelease } )；读取失败返回空数组
        UpdatedAt 由页面上的 relative-time 绝对时间换算成 ISO 8601（取不到时为空串）
    #>
    param(
        [hashtable]$Context,
        [Parameter(Mandatory = $true)][string]$Repo,
        [int]$Pages = 2
    )

    $items = @()
    if (-not $Repo) { return $items }
    if ($Pages -lt 1) { $Pages = 1 }

    $seen = New-Object 'System.Collections.Generic.HashSet[string]' ([StringComparer]::Ordinal)

    for ($page = 1; $page -le $Pages; $page++) {
        $url = 'https://github.com/{0}/releases' -f $Repo
        if ($page -gt 1) { $url = '{0}?page={1}' -f $url, $page }
        $html = ''
        try {
            $html = Invoke-WinstHttpGet -Uri $url -Context $Context
        } catch {
            break
        }
        if (-not $html) { break }

        # 必须用 @() 包住：函数返回 1 条时 PowerShell 会把它展开成单个字典，
        # 而字典的 .Count 是键的数量（5），不是条目数
        $pageItems = @(ConvertFrom-GitHubReleaseListHtml -Html $html)
        if ($pageItems.Count -eq 0) { break }

        $added = 0
        foreach ($item in $pageItems) {
            if ($seen.Add([string]$item['Tag'])) {
                $items += $item
                $added++
            }
        }
        # 整页都是已见过的 tag → 说明翻页没有给出新内容，停止
        if ($added -eq 0) { break }
    }

    # 返回数组本身：调用方统一用 `@(...)` 包住来取条目数（见 ConvertFrom-GitHubReleaseListHtml 的说明）
    return $items
}
