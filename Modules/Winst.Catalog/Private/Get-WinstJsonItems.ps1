#Requires -Version 5.1

function Get-WinstJsonItems {
    <#
    .SYNOPSIS
        ① 抓取 JSON 接口并取出条目集合（itemsKey 缺省时整个响应就是一个条目）。
    .OUTPUTS
        @{ Error; Items; ApiUrl }
    #>
    param([hashtable]$Context, $Source, [string]$ApiUrl, $Follow, $FollowSelection)

    $read = Read-WinstJsonSourceResponse -Context $Context -ApiUrl $ApiUrl
    if ($read.Error) { return @{ Error = $read.Error; Items = @() } }
    $data = $read.Data
    if ($null -ne $Follow) {
        $followKey = (Get-EntryString -Entry $Follow -Key 'itemsKey').Trim()
        $container = $data
        if ($followKey) {
            $found = Get-JsonNodeValue -Node $data -Key $followKey
            if (-not $found.Ok) { return @{ Error = ('source.follow 找不到字段：' + $followKey); Items = @() } }
            $container = $found.Node
        }
        $pick = Select-WinstJsonVersionItems -Items @($container) -Selection $FollowSelection -Label 'source.follow'
        if ($pick.Error) { return @{ Error = $pick.Error; Items = @() } }
        if (@($pick.Items).Count -ne 1) {
            return @{ Error = 'source.follow 必须选中唯一候选，请配置版本过滤或排序'; Items = @() }
        }
        $nextUrl = (Get-EntryString -Entry $Follow -Key 'apiUrl').Trim()
        if ($nextUrl) {
            if ($nextUrl -cmatch '\{version(Major|Minor)?\}') {
                $found = Get-JsonNodeValue -Node $pick.Items[0] -Key $FollowSelection.VersionKey
                if (-not $found.Ok -or -not (Get-WinstVersionFromText -Text ([string]$found.Node))) {
                    return @{ Error = ('source.follow 无法取得地址模板所需的完整版本号：' + $FollowSelection.VersionKey); Items = @() }
                }
                $version = Get-NormalizedVersionString -Value ([string]$found.Node)
                $nextUrl = Expand-VersionPlaceholder -Text $nextUrl -Version $version
            }
        }
        else {
            $urlKey = Get-EntryString -Entry $Follow -Key 'urlKey'
            $found = Get-JsonNodeValue -Node $pick.Items[0] -Key $urlKey
            if (-not $found.Ok -or $found.Node -isnot [string]) {
                return @{ Error = ('source.follow 的字段必须是绝对 HTTP(S) 地址：' + $urlKey); Items = @() }
            }
            $nextUrl = [string]$found.Node
        }
        $nextUri = $null
        if (-not [Uri]::TryCreate($nextUrl, [UriKind]::Absolute, [ref]$nextUri) -or @('http', 'https') -notcontains $nextUri.Scheme) {
            return @{ Error = ('source.follow 的接口地址必须是绝对 HTTP(S) 地址：' + $nextUrl); Items = @() }
        }
        $ApiUrl = $nextUri.AbsoluteUri
        $read = Read-WinstJsonSourceResponse -Context $Context -ApiUrl $ApiUrl
        if ($read.Error) { return @{ Error = $read.Error; Items = @() } }
        $data = $read.Data
    }

    # ② 条目：itemsKey 取到的可能是数组，也可能是单个对象（单元素数组会被 ConvertFrom-Json 解包）
    $itemsKey = (Get-EntryString -Entry $Source -Key 'itemsKey').Trim()
    $container = $data
    if ($itemsKey) {
        $found = Get-JsonNodeValue -Node $data -Key $itemsKey
        if (-not $found.Ok) {
            return @{ Error = ('JSON 接口 {0} 里没有找到「{1}」这个字段（顶层字段: {2}）；可能是接口变更，需要更新软件源' -f `
                        $ApiUrl, $itemsKey, (Get-JsonFieldNameText -Node $data)); Items = @() }
        }
        $container = $found.Node
    }
    $items = @($container)
    if ($items.Count -eq 0) {
        return @{ Error = ('JSON 接口 {0} 里没有任何条目；可能是接口变更，需要更新软件源' -f $ApiUrl); Items = @() }
    }
    return @{ Error = ''; Items = $items; ApiUrl = $ApiUrl }
}
