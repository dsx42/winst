#Requires -Version 5.1

function ConvertFrom-GitHubReleaseListHtml {
    <#
    .SYNOPSIS
        从 releases 列表页 HTML 里解析出每条发布（tag / 标题 / 正文 / 时间 / 是否预发布）。
    .DESCRIPTION
        页面结构（GitHub 当前的 releases 列表，每条发布一个 section）：

        ```
        <section id="release-<tag>" data-release-anchor="release-<tag>" ...>
          <h2 ...><a href="/owner/repo/releases/tag/<tag>">标题</a></h2>
          <span ...>Pre-release</span>                      仅预发布才有
          <relative-time datetime="2026-10-25T17:26:05Z">     发布时间（绝对时间在 datetime 属性里）
          <div class="markdown-body ...">...正文...</div>     发布正文
        </section>
        ```

        按 `section id="release-..."` 切块，比全局正则扫 `/releases/tag/` 更稳：
        正文里也可能出现指向其它发布的 tag 链接（「见上一版」之类），全局扫会误把它们当成条目。

        标题与正文都转成纯文本（`ConvertTo-HtmlText`），供 `versionFrom: releaseTitle` /
        `releaseBody` 用 `versionBetween` 截取版本号。
    .OUTPUTS
        @( @{ Tag; Title; Body; UpdatedAt; Prerelease } )
    #>
    param([string]$Html)

    $items = @()
    if (-not $Html) { return $items }

    # 注意变量名不能叫 $matches：那是 PowerShell 的正则自动变量（$Matches），
    # 一赋值就会与内置语义打架，取到的内容不可靠
    $blocks = [regex]::Matches($Html, '(?is)<section\s+id="release-([^"]+)"[^>]*>(.*?)(?=<section\s+id="release-|\z)')
    foreach ($block in $blocks) {
        # tag 优先取 section id（页面锚点就是 tag，且已做过 HTML 转义）
        $tag = [System.Net.WebUtility]::HtmlDecode($block.Groups[1].Value).Trim()
        $text = $block.Groups[2].Value
        if (-not $tag) {
            $fallback = [regex]::Match($text, '/releases/tag/([^"''?#<>]+)')
            if (-not $fallback.Success) { continue }
            $tag = [Uri]::UnescapeDataString($fallback.Groups[1].Value).Trim()
        }
        if (-not $tag) { continue }

        # 标题：h2 里的第一个链接文本
        $titleText = ''
        $titleMatch = [regex]::Match($text, '(?is)<h2[^>]*>(.*?)</h2>')
        if ($titleMatch.Success) { $titleText = ConvertTo-HtmlText -Html $titleMatch.Groups[1].Value }

        # 正文：markdown-body 里的内容（正文里不会嵌第二个 markdown-body）
        $body = ''
        $bodyMatch = [regex]::Match($text, '(?is)<div[^>]*class="[^"]*markdown-body[^"]*"[^>]*>(.*)')
        if ($bodyMatch.Success) {
            # 截到「发布页脚」（Assets / 表情反应）之前，避免把整页剩余内容都当成正文
            $rawBody = $bodyMatch.Groups[1].Value
            $cut = [regex]::Match($rawBody, '(?is)<div[^>]*(?:Box-footer|release-footer|d-flex\s+flex-items-center)|<include-fragment')
            if ($cut.Success) { $rawBody = $rawBody.Substring(0, $cut.Index) }
            $body = ConvertTo-HtmlText -Html $rawBody
        }

        # 发布时间：relative-time 的 datetime 属性是绝对时间（ISO 8601）
        $updatedAt = ''
        $timeMatch = [regex]::Match($text, '(?is)<relative-time[^>]*datetime="([^"]+)"')
        if ($timeMatch.Success) {
            $parsed = [datetime]::MinValue
            if ([datetime]::TryParse($timeMatch.Groups[1].Value, [ref]$parsed)) { $updatedAt = $parsed.ToString('s') }
        }

        # 预发布标记：页面上的 Pre-release 标签
        $prerelease = $text.IndexOf('Pre-release', [StringComparison]::OrdinalIgnoreCase) -ge 0

        $items += [ordered]@{
            Tag        = $tag
            Title      = $titleText
            Body       = $body
            UpdatedAt  = $updatedAt
            Prerelease = [bool]$prerelease
        }
    }

    # 返回数组本身（不要写成 `,@($items)`）：调用方统一用 `@(...)` 包住来取条目数。
    # PowerShell 的两条规则叠在一起容易踩坑：
    #   ① 函数 `return $items` 且只有 1 项时，值会被展开成单个字典交给调用方；
    #   ② `[ordered]` 字典的 .Count 是「键的数量」而不是条目数，`[0]` 还会取到键名而非条目。
    # 因此调用方必须写 `@(ConvertFrom-GitHubReleaseListHtml -Html $html)` 再取 .Count / [0]；
    # 若这里改成 `return ,@($items)`，调用方的 `@()` 反而会多包一层，条目取值就全错。
    return $items
}
