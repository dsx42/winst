#Requires -Version 5.1

function Get-WinstPageIframeAnchors {
    <#
    .SYNOPSIS
        主页面没有命中下载链接时，抓取页面里声明的 iframe（最多 3 个、去重）并匹配其中的链接。
    .OUTPUTS
        @{ Html; Matched }
    #>
    param($Context, $Source, [string]$PageUrl, [string]$Html, $LinkSpec, $Result, $HrefRule, [Collections.ArrayList]$Sessions)

    $matchedAnchors = @()

    $iframeUrls = @()
    foreach ($iframeTag in [regex]::Matches($html, '(?is)<iframe\b([^>]*)>')) {
        $src = (Get-HtmlAttributeValue -Attributes $iframeTag.Groups[1].Value -Name 'src').Trim()
        if (-not $src -or $src -match '^(?i)(javascript:|data:|about:)') { continue }
        try { $iframeUrls += ([Uri]::new([Uri]$PageUrl, $src)).AbsoluteUri } catch { }
    }
    $iframeUrls = @(Get-DistinctValues -Values $iframeUrls) | Select-Object -First 3
    foreach ($iframeUrl in $iframeUrls) {
        $iframePage = Get-SourcePageHtml -Context $Context -Source $Source -PageUrl $iframeUrl -Label 'iframe 页面' -Sessions $Sessions
        if (-not $iframePage.Ok) {
            $Result.Notes += ('未能打开 iframe 页面 {0}：{1}' -f $iframeUrl, $iframePage.Error)
            continue
        }
        foreach ($note in @($iframePage.Notes)) { if ($note) { $Result.Notes += $note } }
        $html += (' ' + [string]$iframePage.Html)
        foreach ($anchor in @($iframePage.Anchors)) {
            $href = ([string]$anchor['Href']).Trim()
            if (-not $href -or $href -match '^(?i)(javascript:|mailto:|#)') { continue }
            try { $href = ([Uri]::new([Uri]$iframePage.BaseUrl, $href)).AbsoluteUri } catch { }
            $copy = Copy-WinstObjectShallow -InputObject $anchor
            $copy['Href'] = $href
            $copy['Session'] = $iframePage.Session
            if (Test-AnchorMatches -Anchor $copy -Spec $LinkSpec -HrefRule $HrefRule) { $matchedAnchors += $copy }
        }
        $Result.Notes += ('主页面没有命中下载链接，已跟随 iframe（{0}）' -f $iframeUrl)
    }

    return @{ Html = $html; Matched = $matchedAnchors }
}
