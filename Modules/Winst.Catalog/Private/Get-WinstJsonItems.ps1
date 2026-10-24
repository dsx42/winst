#Requires -Version 5.1

function Get-WinstJsonItems {
    <#
    .SYNOPSIS
        ① 抓取 JSON 接口并取出条目集合（itemsKey 缺省时整个响应就是一个条目）。
    .OUTPUTS
        @{ Error; Items }
    #>
    param([hashtable]$Context, $Source, [string]$ApiUrl)

    # 走 IWR + 进程内 TTL 缓存 + 代理链路；带浏览器式请求头——
    # 部分站点（如 opencode.ai）按客户端特征拒绝自动化请求（PowerShell UA 直接报错）
    try {
        $response = Invoke-WinstHttpRequest -Uri $ApiUrl -Context $Context -Headers (Get-WinstBrowserHeaders)
    } catch {
        return @{ Error = ('无法打开 JSON 接口 {0}：{1}' -f $ApiUrl, $_.Exception.Message); Items = @() }
    }

    $data = $null
    try { $data = ([string]$response.Content) | ConvertFrom-Json } catch { $data = $null }
    if ($null -eq $data) {
        return @{ Error = ('JSON 接口 {0} 返回的内容不是合法 JSON；可能是接口变更，需要更新软件源' -f $ApiUrl); Items = @() }
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
    return @{ Error = ''; Items = $items }
}
