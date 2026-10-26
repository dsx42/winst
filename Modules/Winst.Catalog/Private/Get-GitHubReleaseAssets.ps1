#Requires -Version 5.1

function Get-GitHubReleaseAssets {
    <#
    .SYNOPSIS
        读取某个 GitHub 发布里的资产文件名（走网页版的资产列表片段，不消耗 API 配额）。
    .DESCRIPTION
        区分「读取失败」与「这个发布确实一个文件都没有」，两者对调用方的含义完全不同：

        - `Ok = $false`：页面读不到（网络 / 页面结构变化）→ 换发布也不会好，直接报错
        - `Ok = $true` 且 `Names` 为空：这个发布还没有上传任何资产（上游刚建好 release 时就是这样）
          → 调用方可以退回更早的发布
    .OUTPUTS
        @{ Ok; Names }
    #>
    param(
        [hashtable]$Context,
        [Parameter(Mandatory = $true)][string]$Repo,
        [Parameter(Mandatory = $true)][string]$Tag
    )

    $result = @{ Ok = $false; Names = @() }
    if (-not $Repo -or -not $Tag) { return $result }

    $url = 'https://github.com/{0}/releases/expanded_assets/{1}' -f $Repo, ([Uri]::EscapeDataString($Tag))
    $html = ''
    try {
        $html = Invoke-WinstHttpGet -Uri $url -Context $Context
    } catch {
        return $result
    }
    # 页面读到空内容等同于读失败：无法据此判断「这个发布里有没有文件」
    if (-not $html) { return $result }
    $result.Ok = $true

    $names = @()
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
    $result.Names = @(Get-DistinctValues -Values $names)
    return $result
}
