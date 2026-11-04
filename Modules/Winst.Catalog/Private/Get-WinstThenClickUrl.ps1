#Requires -Version 5.1

function Get-WinstThenClickUrl {
    <#
    .SYNOPSIS
        两跳取址（thenClick）：打开中间页、按点击序列点按钮，从下载事件里取真正的地址。
    .OUTPUTS
        @{ Ok; Error; Url; PageHash }
    #>
    param($Context, $Source, [string]$PageUrl, [string]$IntermediateUrl, $FileRule, $Item, $Result)

    # 两跳取址：link 命中的是「中间页」地址（如 NTriver 的镜像页：列表页上只有
    # 文件名 + SHA-256 + 镜像页链接，真正的下载地址要在镜像页上点 Download 按钮才生成）——
    # 用无头浏览器打开中间页、执行 thenClick 的点击序列，从浏览器上报的下载事件里取地址
    #（与 click 同一套机制，见 Get-WinstBrowserClickedLink）。
    # 若 files[0].hashFrom: "page" 且声明了 source.hashClick，取址成功后再按 hashClick 读摘要。
    $hashClickSteps = @(Get-EntryArray -Entry $Source -Key 'hashClick')
    $wantPageHash = ($null -ne $Item -and ((Get-EntryString -Entry $Item -Key 'hashFrom').Trim() -ieq 'page') -and $hashClickSteps.Count -gt 0)
    $clicked = Get-WinstBrowserClickedLink -Context $Context -Url $IntermediateUrl -ClickSpecs @(Get-EntryArray -Entry $Source -Key 'thenClick') `
        -WantPageHash:$wantPageHash -HashClickSpecs $hashClickSteps
    foreach ($note in @($clicked.Notes)) { if ($note) { $Result.Notes += $note } }
    if (-not $clicked.Ok) {
        return @{ Ok = $false; Error = ('已在 {1} 上找到中间页地址 {0}，但打开它点按钮取下载地址失败：{2}' -f $IntermediateUrl, $PageUrl, $clicked.Error); Url = ''; PageHash = '' }
    }
    $thenUrls = @(Get-DistinctValues -Values @($clicked.DownloadUrls))
    if ($FileRule) {
        $thenUrls = @(Select-WinstUrlByFileRule -Urls $thenUrls -FileRule $FileRule)
        if ($thenUrls.Count -eq 0) {
            return @{ Ok = $false; Error = ('点击中间页 {1} 上的按钮后，浏览器拿到的地址都不符合「{0}」' -f $FileRule.Source, $IntermediateUrl); Url = ''; PageHash = '' }
        }
    }
    if ($thenUrls.Count -gt 1) {
        $Result.Notes += ('点击中间页后浏览器发起了 {0} 个下载，已取第一个' -f $thenUrls.Count)
    }
    return @{ Ok = $true; Error = ''; Url = [string]$thenUrls[0]; PageHash = [string]$clicked.PageHash }
}
