#Requires -Version 5.1

function Get-GitHubReleaseListTags {
    <#
    .SYNOPSIS
        读取 GitHub 仓库 releases 列表页里的发布（tag / 标题 / 正文 / 是否预发布），走网页、不消耗 API 配额。
    .DESCRIPTION
        最多读取两页，保留页面顺序和预发布标记。调用方按需筛选并比较版本。
    .OUTPUTS
        @( @{ Tag; Title; Body; UpdatedAt; Prerelease } )；任一页读取失败抛出错误，不返回不完整结果
        UpdatedAt 由页面上的 relative-time 绝对时间换算成 ISO 8601（取不到时为空串）
    #>
    param(
        [hashtable]$Context,
        [Parameter(Mandatory = $true)][string]$Repo
    )

    $items = @()

    $seen = New-Object 'System.Collections.Generic.HashSet[string]' ([StringComparer]::Ordinal)

    for ($page = 1; $page -le 2; $page++) {
        $url = 'https://github.com/{0}/releases' -f $Repo
        if ($page -gt 1) { $url = '{0}?page={1}' -f $url, $page }
        try {
            $html = Invoke-WinstHttpGet -Uri $url -Context $Context
        } catch {
            if ($page -eq 1) { throw }
            throw ('{0} 的发布列表结果不完整，第 {1} 页读取失败：{2}' -f $Repo, $page, $_.Exception.Message)
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
