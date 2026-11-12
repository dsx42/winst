#Requires -Version 5.1

function Get-WinstPageClickedUrl {
    <#
    .SYNOPSIS
        点击取址：用无头 Edge 按 click 序列点按钮，从浏览器上报的下载事件里取地址。
    .OUTPUTS
        @{ Ok; Error; Url; Html; PageHash }
    #>
    param($Context, $Source, [string]$PageUrl, $ClickSpec, $FileRule, $Item, $Result)
    try { Assert-WinstHttpUrl -Url $PageUrl -Label 'source.pageUrl' }
    catch { return @{ Ok = $false; Error = $_.Exception.Message; Url = ''; Html = ''; PageHash = '' } }

    # ---- 点击取址：地址不写在页面里，点了按钮才由页面脚本生成 ----
    $clickSteps = @($ClickSpec)
    if ($clickSteps.Count -eq 0) {
        return @{ Ok = $false; Error = 'source.click 里没有写任何点击步骤'; Url = ''; Html = ''; PageHash = '' }
    }

    $clickFetchWith = (Get-EntryString -Entry $Source -Key 'fetchWith').Trim().ToLowerInvariant()
    if ($clickFetchWith -and $clickFetchWith -ne 'browser') {
        return @{ Ok = $false; Error = 'source.click 使用无头浏览器取地址，fetchWith 只能省略或填写 "browser"'; Url = ''; Html = ''; PageHash = '' }
    }

    # 版本要从页面里取时（versionKey / versionFrom: page），把点击之后的 DOM 一并带回来
    $clickVersionKey = (Get-EntryString -Entry $Source -Key 'versionKey').Trim()
    $clickVersionFrom = (Get-EntryString -Entry $Source -Key 'versionFrom').Trim().ToLowerInvariant()
    # 版本要从页面里取、或 files[0].hashFrom: "page" 时，把点击之后的 DOM 一并带回来（就近刮取）。
    # 若另声明了 source.hashClick，同一会话在取址成功后再按该序列点控件读摘要（见 WantPageHash）。
    $hashClickSteps = @(Get-EntryArray -Entry $Source -Key 'hashClick')
    $wantPageHash = ($null -ne $Item -and ((Get-EntryString -Entry $Item -Key 'hashFrom').Trim() -ieq 'page') -and $hashClickSteps.Count -gt 0)
    $wantPageHtml = ([bool]$clickVersionKey -and @('header', 'json') -notcontains $clickVersionFrom) -or ($clickVersionFrom -eq 'page') -or ($null -ne $Item -and ((Get-EntryString -Entry $Item -Key 'hashFrom').Trim() -ieq 'page'))

    $clicked = Get-WinstBrowserClickedLink -Context $Context -Url $PageUrl -ClickSpecs $clickSteps -WantHtml:$wantPageHtml -WantPageHash:$wantPageHash -HashClickSpecs $hashClickSteps
    foreach ($note in @($clicked.Notes)) { if ($note) { $Result.Notes += $note } }
    if (-not $clicked.Ok) {
        return @{ Ok = $false; Error = [string]$clicked.Error; Url = ''; Html = ''; PageHash = '' }
    }
    $html = [string]$clicked.Html
    $pageHash = [string]$clicked.PageHash

    $clickUrls = @(Get-DistinctValues -Values @($clicked.DownloadUrls))
    if ($FileRule) {
        $clickUrls = @(Select-WinstUrlByFileRule -Urls $clickUrls -FileRule $FileRule)
        if ($clickUrls.Count -eq 0) {
            return @{ Ok = $false; Error = ('点击下载页 {1} 上的按钮后，浏览器拿到的地址都不符合「{0}」' -f $FileRule.Source, $PageUrl); Url = ''; Html = $html; PageHash = $pageHash }
        }
    }
    if ($clickUrls.Count -gt 1) {
        $Result.Notes += ('点击后浏览器发起了 {0} 个下载，已取第一个' -f $clickUrls.Count)
    }
    if ($clickUrls.Count -eq 0) { return @{ Ok = $false; Error = '点击后没有取得下载地址'; Url = ''; Html = $html; PageHash = $pageHash } }
    try { Assert-WinstHttpUrl -Url ([string]$clickUrls[0]) }
    catch { return @{ Ok = $false; Error = $_.Exception.Message; Url = ''; Html = $html; PageHash = $pageHash } }
    return @{ Ok = $true; Error = ''; Url = [string]$clickUrls[0]; Html = $html; PageHash = $pageHash }
}
