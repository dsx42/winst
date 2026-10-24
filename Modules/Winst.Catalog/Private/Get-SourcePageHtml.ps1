#Requires -Version 5.1

function Get-SourcePageHtml {
    <#
    .SYNOPSIS
        抓取来源页面（page 源的下载页 / direct 源的版本页）：IWR + 浏览器式请求头，或 fetchWith: browser 的系统浏览器。
    .OUTPUTS
        @{ Ok; Html; Anchors; Notes; Error }
    #>
    param([hashtable]$Context, $Source, [string]$PageUrl, [string]$Label = '页面')

    $result = @{ Ok = $false; Html = ''; Anchors = @(); Notes = @(); Error = '' }
    if (-not $PageUrl) {
        $result.Error = ('没有填写{0}地址（source.pageUrl）' -f $Label)
        return $result
    }

    # 缺省走 IWR + 浏览器式请求头（部分站点按 UA 拒绝自动化请求）；声明 fetchWith: browser 时改用系统自带的
    # Microsoft Edge 抓取——IWR / curl 在客户端特征层面被整体拒绝的站点只能用这条路
    $fetchWith = (Get-EntryString -Entry $Source -Key 'fetchWith').Trim().ToLowerInvariant()
    if ($fetchWith -and $fetchWith -ne 'iwr' -and $fetchWith -ne 'browser') {
        $result.Error = ('不认识的页面抓取方式「{0}」（source.fetchWith）；可用 iwr（缺省）或 browser' -f $fetchWith)
        return $result
    }

    if ($fetchWith -eq 'browser') {
        $browserPage = Get-WinstBrowserPageHtml -Context $Context -Url $PageUrl
        if (-not $browserPage.Ok) {
            $result.Error = ('无法用系统浏览器打开{0} {1}：{2}' -f $Label, $PageUrl, $browserPage.Error)
            return $result
        }
        $result.Ok = $true
        $result.Html = [string]$browserPage.Html
        $result.Anchors = @(Get-HtmlAnchorList -Html $result.Html)
        $result.Notes += ('{0}由系统浏览器（{1}）抓取。' -f $Label, [string]$browserPage.Engine)
        return $result
    }

    try {
        $response = Invoke-WinstHttpRequest -Uri $PageUrl -Context $Context -Headers (Get-WinstBrowserHeaders)
    } catch {
        $result.Error = ('无法打开{0} {1}：{2}' -f $Label, $PageUrl, $_.Exception.Message)
        return $result
    }
    $result.Ok = $true
    $result.Html = [string]$response.Content
    $result.Anchors = @($response.Links)
    return $result
}
