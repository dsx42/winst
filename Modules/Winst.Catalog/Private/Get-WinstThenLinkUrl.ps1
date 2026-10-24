#Requires -Version 5.1

function Get-WinstThenLinkUrl {
    <#
    .SYNOPSIS
        两跳取址（thenLink）：抓中转页 HTML，按 thenLink.link（或 files[0].file）再定位真正的下载地址。
    .OUTPUTS
        @{ Ok; Error; Url }
    #>
    param($Context, $Source, [string]$TransitUrl, $ThenLinkSpec, $FileRule, $Result)

    # 中转页二次提取：
    # link 命中的是「中转页」地址（如镜像选择页 download.php?file=…，GET 返回 text/html，
    # 下载引擎拿到必然失败）——抓取中转页 HTML，按 thenLink.link（与主页面同一套 link 定位规则，
    # 不针对具体站点）再定位一次真正的下载地址；未写 thenLink.link 时按 files[0].file 规则
    # 过滤中转页全部链接后取第一个。相对链接按中转页地址补全为绝对地址。
    $transitPage = Get-SourcePageHtml -Context $Context -Source $Source -PageUrl $TransitUrl -Label '中转页'
    if (-not $transitPage.Ok) {
        return @{ Ok = $false; Error = ('无法打开中转页 {0}：{1}' -f $TransitUrl, $transitPage.Error); Url = '' }
    }
    foreach ($note in @($transitPage.Notes)) { if ($note) { $Result.Notes += $note } }

    $thenLinkLocator = Get-EntryValue -Entry $ThenLinkSpec -Key 'link' -Default $null
    $transitMatches = @()
    foreach ($anchor in @($transitPage.Anchors)) {
        if ($null -ne $thenLinkLocator -and -not (Test-AnchorMatches -Anchor $anchor -Spec $thenLinkLocator)) { continue }
        $href = ([string]$anchor['Href']).Trim()
        if (-not $href) { continue }
        if ($href -match '^(?i)(javascript:|mailto:|#)') { continue }
        $absolute = $href
        try { $absolute = ([Uri]::new([Uri]$TransitUrl, $href)).AbsoluteUri } catch { $absolute = $href }
        $transitMatches += $absolute
    }
    $transitMatches = @(Get-DistinctValues -Values $transitMatches)
    # files[0].file 规则只在「未声明 thenLink.link」时参与过滤：声明了定位规则就由它说了算——
    # 中转页给出的最终地址常带附加参数（如 …&r=1），按 *.zip 这类文件名规则匹配整串会误杀
    if ($null -eq $thenLinkLocator -and $FileRule) {
        $transitMatches = @(Select-WinstUrlByFileRule -Urls $transitMatches -FileRule $FileRule)
    }
    if ($transitMatches.Count -eq 0) {
        if ($null -ne $thenLinkLocator) {
            return @{ Ok = $false; Error = ('在中转页 {1} 上没有找到符合条件的下载地址（{0}）；可能是页面结构变更，需要更新软件源' -f (Format-LinkSpec -Spec $thenLinkLocator), $TransitUrl); Url = '' }
        }
        return @{ Ok = $false; Error = ('在中转页 {1} 上没有找到符合文件名规则（{0}）的下载地址；可能是页面结构变更，需要更新软件源' -f $FileRule.Source, $TransitUrl); Url = '' }
    }
    if ($transitMatches.Count -gt 1) {
        $Result.Notes += ('中转页上一共找到 {0} 个下载链接，已取第一个' -f $transitMatches.Count)
    }
    return @{ Ok = $true; Error = ''; Url = [string]$transitMatches[0] }
}
