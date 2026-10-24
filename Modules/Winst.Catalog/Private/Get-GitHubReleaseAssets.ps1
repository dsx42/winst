#Requires -Version 5.1

function Get-GitHubReleaseAssets {
    <#
    .SYNOPSIS
        读取某个 GitHub 发布里的资产文件名（走网页版的资产列表片段，不消耗 API 配额）。
    .OUTPUTS
        @( <文件名> )；读取失败返回空数组
    #>
    param(
        [hashtable]$Context,
        [Parameter(Mandatory = $true)][string]$Repo,
        [Parameter(Mandatory = $true)][string]$Tag
    )

    $names = @()
    if (-not $Repo -or -not $Tag) { return $names }

    $url = 'https://github.com/{0}/releases/expanded_assets/{1}' -f $Repo, ([Uri]::EscapeDataString($Tag))
    $html = ''
    try {
        $html = Invoke-WinstHttpGet -Uri $url -Context $Context
    } catch {
        return $names
    }

    foreach ($m in [regex]::Matches($html, '(?is)href="([^"]*)"')) {
        $href = [System.Net.WebUtility]::HtmlDecode($m.Groups[1].Value)
        if ($href -notmatch '/releases/download/') { continue }

        $cut = $href.IndexOfAny([char[]]@('?', '#'))
        if ($cut -ge 0) { $href = $href.Substring(0, $cut) }
        $slash = $href.LastIndexOf('/')
        if ($slash -lt 0) { continue }

        $name = $href.Substring($slash + 1)
        try { $name = [Uri]::UnescapeDataString($name) } catch { }
        if ($name) { $names += $name }
    }
    return @(Get-DistinctValues -Values $names)
}
