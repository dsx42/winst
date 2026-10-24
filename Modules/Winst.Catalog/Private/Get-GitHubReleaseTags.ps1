#Requires -Version 5.1

function Get-GitHubReleaseTags {
    <#
    .SYNOPSIS
        读取 GitHub 仓库的发布 tag 列表（走 releases Atom feed，不消耗 API 配额，且包含预发布版本）。
    .DESCRIPTION
        GitHub 的 API 匿名配额按出口 IP 计（60 次/小时，多机共享），且可能被网络策略拦截；
        Atom feed 由 github.com 直接提供，无配额限制、体积小。feed 固定只含最近约 10 条发布，
        对本工具的「取最新版本」用途足够。
    .OUTPUTS
        @( @{ Tag; Title; Body; UpdatedAt } )，按 feed 顺序（最新在前）
    #>
    param(
        [hashtable]$Context,
        [Parameter(Mandatory = $true)][string]$Repo
    )

    $items = @()
    if (-not $Repo) { return $items }

    $feedUrl = 'https://github.com/{0}/releases.atom' -f $Repo
    $text = Invoke-WinstHttpGet -Uri $feedUrl -Context $Context

    foreach ($m in [regex]::Matches($text, '(?is)<entry>(.*?)</entry>')) {
        $block = $m.Groups[1].Value

        $tag = ''
        $linkMatch = [regex]::Match($block, '(?is)<link[^>]*href="([^"]+)"')
        if ($linkMatch.Success) {
            $href = [System.Net.WebUtility]::HtmlDecode($linkMatch.Groups[1].Value)
            $tagMatch = [regex]::Match($href, '/releases/tag/(.+)$')
            if ($tagMatch.Success) { $tag = ([Uri]::UnescapeDataString($tagMatch.Groups[1].Value)).Trim() }
        }
        if (-not $tag) {
            # 兜底：entry 的 id 形如 tag:github.com,2008:Repository/123/.0
            $idMatch = [regex]::Match($block, '(?is)<id>[^<]*?/([^/<>]+)</id>')
            if ($idMatch.Success) { $tag = ([Uri]::UnescapeDataString($idMatch.Groups[1].Value)).Trim() }
        }
        if (-not $tag) { continue }

        $title = ''
        $titleMatch = [regex]::Match($block, '(?is)<title>(.*?)</title>')
        if ($titleMatch.Success) { $title = ConvertTo-HtmlText -Html $titleMatch.Groups[1].Value }

        # 正文（release body 的 HTML 渲染结果，feed 条目的 <content> 自带）：供 versionFrom: releaseBody
        # 从正文里识别版本
        $body = ''
        $contentMatch = [regex]::Match($block, '(?is)<content[^>]*>(.*?)</content>')
        if ($contentMatch.Success) { $body = ConvertTo-HtmlText -Html $contentMatch.Groups[1].Value }

        $updatedAt = ''
        $updatedMatch = [regex]::Match($block, '(?is)<updated>(.*?)</updated>')
        if ($updatedMatch.Success) { $updatedAt = $updatedMatch.Groups[1].Value.Trim() }

        $items += [ordered]@{ Tag = $tag; Title = $title; Body = $body; UpdatedAt = $updatedAt }
    }
    return $items
}
