#Requires -Version 5.1

function Resolve-PageSource {
    <#
    .SYNOPSIS
        解析 page 源：在详情页锚点中按 link（class / id / text / href）定位下载地址，并识别版本。
    .DESCRIPTION
        取地址有两条路，二选一（同时写会报错）：
        ① source.link —— 页面上的链接就是下载地址（含 fetchWith: browser 抓渲染后的 DOM）；
        ② source.click —— 地址不写在页面里、点了按钮才生成：用无头 Edge 按点击序列点按钮，
           从浏览器上报的下载事件里取地址（fetchWith 必须是 browser，见 Get-WinstBrowserClickedLink）。
        link 还可以搭配 source.thenClick 做两跳取址：link 命中的是「中间页」地址（如 NTriver 的镜像页：
        列表页只有文件名 + SHA-256 + 镜像页链接，真正的下载地址要在镜像页上点 Download 按钮才生成），
        此时用无头浏览器打开命中地址、执行 thenClick 的点击序列取真正的下载地址（与 click 同一套机制）。
        版本识别优先级：versionKey（页面数据里的字段名）→ versionKind / versionBetween（在 versionFrom
        指定的位置识别，默认从下载地址识别）→ 回退条目里的 version；声明 versionFrom: "package" 时以上都不做
        。
        files[] 第一条 = 主包：用于在多个候选链接里挑出要下载的文件（file 通配），并可声明校验信息；
        校验值随版本更新的站点可声明 files[0].hashFrom: "page"（按文件名在页面上就近提取 SHA-256，见上）；
        第 2 条起 = 配套文件：写成带 {version} 的完整地址（url）+ dest，与其它来源一致。
        本函数只做编排，校验 / 取址 / 版本 / 落位各由独立函数承担。
    #>
    param([hashtable]$Context, $Entry)

    $result = New-SourceResolveResult -Kind 'page'
    $source = Get-EntryValue -Entry $Entry -Key 'source' -Default $null
    $pageUrl = (Get-EntryString -Entry $source -Key 'pageUrl').Trim()
    if (-not $pageUrl) {
        $result.Error = '软件源里没有填写下载页地址（source.pageUrl）'
        return $result
    }

    # 版本识别规则（versionKind / versionBetween）：与 listing / json / magnet 共用同一套校验
    $versionRule = Get-WinstVersionRule -Source $source
    if (-not $versionRule.Ok) { $result.Error = $versionRule.Error; return $result }

    $versionOption = Get-WinstPageVersionOption -Source $source
    if ($versionOption.Error) { $result.Error = $versionOption.Error; return $result }
    $versionFrom = $versionOption.VersionFrom

    # files[] / link / click / thenClick / thenLink 的写法校验
    $spec = Get-WinstPageAddressSpec -Source $source -Result $result
    if ($spec.Error) { $result.Error = $spec.Error; return $result }
    $item = $spec.Item
    $declared = @($spec.Declared)
    $fileRule = $spec.FileRule

    $pageHeaders = Get-WinstBrowserHeaders
    $html = ''
    $downloadUrl = ''

    if ($null -ne $spec.ClickSpec) {
        $click = Get-WinstPageClickedUrl -Context $Context -Source $source -PageUrl $pageUrl -ClickSpec $spec.ClickSpec `
            -FileRule $fileRule -Item $item -Result $result
        if (-not $click.Ok) { $result.Error = $click.Error; return $result }
        $html = [string]$click.Html
        $downloadUrl = [string]$click.Url
    } else {
        $link = Get-WinstPageLinkUrl -Context $Context -Source $source -PageUrl $pageUrl -LinkSpec $spec.LinkSpec `
            -ThenClickSpec $spec.ThenClickSpec -ThenLinkSpec $spec.ThenLinkSpec -FileRule $fileRule -Result $result
        if (-not $link.Ok) { $result.Error = $link.Error; return $result }
        $html = [string]$link.Html
        $downloadUrl = [string]$link.Url
    }

    $pageHash = Get-WinstPageHashFromPage -Item $item -Html $html -Url $downloadUrl -PageUrl $pageUrl -Result $result
    if ($result.Error) { return $result }

    $versionResult = Resolve-WinstPageVersion -Entry $Entry -Source $source -Html $html -DownloadUrl $downloadUrl `
        -VersionFrom $versionFrom -PageUrl $pageUrl
    if ($versionResult.Error) { $result.Error = $versionResult.Error; return $result }
    $result.Version = [string]$versionResult.Version

    # 页面上的链接可能已失效，探测一次以便尽早发现（同样带浏览器式请求头，见上）
    $skipCheck = Get-EntryBool -Entry $source -Key 'skipExistsCheck'
    $urlProbe = Test-WinstManifestUrlOrNote -Context $Context -Url $downloadUrl -Skip $skipCheck -Headers $pageHeaders `
        -MissingError ('下载页给出的地址不存在（HTTP 404）: {0}；可能是页面上的链接已失效' -f $downloadUrl)
    if (-not $urlProbe.Ok) { $result.Error = [string]$urlProbe.Error; return $result }
    if ($urlProbe.Note) { $result.Notes += [string]$urlProbe.Note }

    $filesResult = New-WinstPageResolvedFiles -Context $Context -Source $source -Item $item -Declared $declared `
        -DownloadUrl $downloadUrl -Version $result.Version -PageHash $pageHash -Result $result
    if ($filesResult.Error) { $result.Error = $filesResult.Error; return $result }

    $result.Ok = $true
    $result.Files = @($filesResult.Files)
    return $result
}
