#Requires -Version 5.1

function Get-GitHubLatestTag {
    <#
    .SYNOPSIS
        取 GitHub 仓库「最新正式发布」的 tag：读 releases/latest 的动态跳转（不消耗 API 配额）。
    .DESCRIPTION
        发布列表页的顺序不等于「版本最新」（temurin21 的页面上 `21.0.9+10` 排在 `21.0.13+9` 前面），
        因此未声明 releaseTag 时以 GitHub 自己认定的 latest 为准；仓库只有预发布时该地址会跳到
        发布列表页，此时返回空串，由调用方退回发布列表。
    .OUTPUTS
        tag 文本；取不到时返回空串
    #>
    param(
        [hashtable]$Context,
        [Parameter(Mandatory = $true)][string]$Repo
    )

    if (-not $Repo) { return '' }
    $url = 'https://github.com/{0}/releases/latest' -f $Repo
    # ① 先试 HEAD：读到跳转目标最省流量，不必把整个 release 页面下载下来
    $response = Invoke-WinstHttpRequest -Uri $url -Context $Context -Method 'Head'

    $finalUri = ''
    if ($response) { $finalUri = [string]$response.FinalUri }
    $tag = Get-GitHubTagFromLocation -Text $finalUri
    if ($tag) { return $tag }

    # ② HEAD 拿不到最终地址时（部分网络 / 代理环境下 IWR 不暴露跳转目标）退回 GET：
    #    releases/latest 会跳到「最新正式发布」的页面，页面里的 og:url 就是它的 tag。
    #    预发布不会被 /releases/latest 命中（这正是这里要用的语义）。
    $page = ''
    try { $page = Invoke-WinstHttpGet -Uri $url -Context $Context } catch { return '' }
    if (-not $page) { return '' }

    $ogUrl = [regex]::Match($page, '(?i)<meta\s+property="og:url"\s+content="([^"]+)"')
    if (-not $ogUrl.Success) { return '' }
    return (Get-GitHubTagFromLocation -Text $ogUrl.Groups[1].Value)
}
