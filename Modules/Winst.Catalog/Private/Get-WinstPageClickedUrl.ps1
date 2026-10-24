#Requires -Version 5.1

function Get-WinstPageClickedUrl {
    <#
    .SYNOPSIS
        点击取址：用无头 Edge 按 click 序列点按钮，从浏览器上报的下载事件里取地址。
    .OUTPUTS
        @{ Ok; Error; Url; Html }
    #>
    param($Context, $Source, [string]$PageUrl, $ClickSpec, $FileRule, $Item, $Result)

    # ---- 点击取址：地址不写在页面里，点了按钮才由页面脚本生成 ----
    $clickSteps = @($ClickSpec)
    if ($clickSteps.Count -eq 0) {
        return @{ Ok = $false; Error = 'source.click 里没有写任何点击步骤'; Url = ''; Html = '' }
    }

    $clickFetchWith = (Get-EntryString -Entry $Source -Key 'fetchWith').Trim().ToLowerInvariant()
    if ($clickFetchWith -ne 'browser') {
        return @{ Ok = $false; Error = 'source.click 要用无头浏览器点按钮取地址，必须同时声明 fetchWith: "browser"'; Url = ''; Html = '' }
    }

    # 版本要从页面里取时（versionKey / versionFrom: page），把点击之后的 DOM 一并带回来
    $clickVersionKey = (Get-EntryString -Entry $Source -Key 'versionKey').Trim()
    $clickVersionFrom = (Get-EntryString -Entry $Source -Key 'versionFrom').Trim().ToLowerInvariant()
    # 版本要从页面里取、或 files[0].hashFrom: "page"（校验值就在页面数据里，如飞牛官网的 MD5）时，
    # 把点击之后的 DOM 一并带回来
    $wantPageHash = ($null -ne $Item -and ((Get-EntryString -Entry $Item -Key 'hashFrom').Trim() -ieq 'page'))
    $wantPageHtml = [bool]$clickVersionKey -or ($clickVersionFrom -eq 'page') -or $wantPageHash

    $clicked = Get-WinstBrowserClickedLink -Context $Context -Url $PageUrl -ClickSpecs $clickSteps -WantHtml:$wantPageHtml
    foreach ($note in @($clicked.Notes)) { if ($note) { $Result.Notes += $note } }
    if (-not $clicked.Ok) {
        return @{ Ok = $false; Error = [string]$clicked.Error; Url = ''; Html = '' }
    }
    $html = [string]$clicked.Html

    $clickUrls = @(Get-DistinctValues -Values @($clicked.DownloadUrls))
    if ($FileRule) {
        $clickUrls = @(Select-WinstUrlByFileRule -Urls $clickUrls -FileRule $FileRule)
        if ($clickUrls.Count -eq 0) {
            return @{ Ok = $false; Error = ('点击下载页 {1} 上的按钮后，浏览器拿到的地址都不符合「{0}」' -f $FileRule.Source, $PageUrl); Url = ''; Html = $html }
        }
    }
    if ($clickUrls.Count -gt 1) {
        $Result.Notes += ('点击后浏览器发起了 {0} 个下载，已取第一个' -f $clickUrls.Count)
    }
    return @{ Ok = $true; Error = ''; Url = [string]$clickUrls[0]; Html = $html }
}
