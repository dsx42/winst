#Requires -Version 5.1

function Get-WinstPageLinkUrl {
    <#
    .SYNOPSIS
        link 取址：抓下载页 → 按 link 规则匹配锚点（必要时跟随 iframe）→ 可选 thenClick / thenLink 两跳。
    .OUTPUTS
        @{ Ok; Error; Url; Html }
    #>
    param($Context, $Source, [string]$PageUrl, $LinkSpec, $ThenClickSpec, $ThenLinkSpec, $FileRule, $Result)

    # 抓页面：缺省走 IWR + 浏览器式请求头（部分站点按 UA 拒绝自动化请求）；声明 fetchWith: browser 时
    # 改用系统自带的 Microsoft Edge 抓取——IWR / curl 在客户端特征层面被整体拒绝的站点只能用这条路，
    # 但页面给出的地址（如 filezilla CDN 带签名的 zip 链接）下载引擎照常能下
    $page = Get-SourcePageHtml -Context $Context -Source $Source -PageUrl $PageUrl -Label '下载页'
    if (-not $page.Ok) {
        return @{ Ok = $false; Error = [string]$page.Error; Url = ''; Html = '' }
    }
    $html = [string]$page.Html
    $anchors = @($page.Anchors)
    if ($page.Notes.Count -gt 0) { $Result.Notes += $page.Notes }

    $matchedAnchors = @()
    foreach ($anchor in $anchors) {
        if (Test-AnchorMatches -Anchor $anchor -Spec $LinkSpec) { $matchedAnchors += $anchor }
    }

    # 跟随 iframe：主页面没有任何命中时才抓取页面里声明的 iframe 页面并入后重新匹配
    if ($matchedAnchors.Count -eq 0) {
        $iframe = Get-WinstPageIframeAnchors -Context $Context -Source $Source -PageUrl $PageUrl -Html $html `
            -Anchors $anchors -LinkSpec $LinkSpec -Result $Result
        $anchors = @($iframe.Anchors)
        $html = [string]$iframe.Html
        $matchedAnchors = @($iframe.Matched)
    }
    if ($matchedAnchors.Count -eq 0) {
        return @{ Ok = $false; Error = ('在下载页 {1} 上没有找到符合条件（{0}）的下载按钮；可能是页面结构变更，需要更新软件源' -f (Format-LinkSpec -Spec $LinkSpec), $PageUrl); Url = ''; Html = $html }
    }

    $absoluteUrls = @()
    foreach ($anchor in $matchedAnchors) {
        $href = ([string]$anchor['Href']).Trim()
        if (-not $href) { continue }
        if ($href -match '^(?i)(javascript:|mailto:|#)') { continue }
        $absolute = $href
        try { $absolute = ([Uri]::new([Uri]$PageUrl, $href)).AbsoluteUri } catch { $absolute = $href }
        $absoluteUrls += $absolute
    }
    $absoluteUrls = @(Get-DistinctValues -Values $absoluteUrls)

    if ($FileRule) {
        $absoluteUrls = @(Select-WinstUrlByFileRule -Urls $absoluteUrls -FileRule $FileRule)
        if ($absoluteUrls.Count -eq 0) {
            return @{ Ok = $false; Error = ('下载页 {1} 上的链接都不符合「{0}」' -f $FileRule.Source, $PageUrl); Url = ''; Html = $html }
        }
    }
    if ($absoluteUrls.Count -eq 0) {
        return @{ Ok = $false; Error = ('在下载页 {1} 上没有提取到下载地址；可能是页面结构变更，需要更新软件源' -f '', $PageUrl); Url = ''; Html = $html }
    }
    if ($absoluteUrls.Count -gt 1) {
        $Result.Notes += ('页面上一共找到 {0} 个下载链接，已取第一个' -f $absoluteUrls.Count)
    }

    $downloadUrl = [string]$absoluteUrls[0]

    if ($null -ne $ThenClickSpec) {
        $thenClick = Get-WinstThenClickUrl -Context $Context -Source $Source -PageUrl $PageUrl -IntermediateUrl $downloadUrl `
            -FileRule $FileRule -Result $Result
        if (-not $thenClick.Ok) { return @{ Ok = $false; Error = [string]$thenClick.Error; Url = ''; Html = $html } }
        $downloadUrl = [string]$thenClick.Url
    }

    if ($null -ne $ThenLinkSpec) {
        $thenLink = Get-WinstThenLinkUrl -Context $Context -Source $Source -TransitUrl $downloadUrl -ThenLinkSpec $ThenLinkSpec `
            -FileRule $FileRule -Result $Result
        if (-not $thenLink.Ok) { return @{ Ok = $false; Error = [string]$thenLink.Error; Url = ''; Html = $html } }
        $downloadUrl = [string]$thenLink.Url
    }

    return @{ Ok = $true; Error = ''; Url = $downloadUrl; Html = $html }
}
