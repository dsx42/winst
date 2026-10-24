#Requires -Version 5.1

function Test-WinstTechnicalNote {
    <#
    .SYNOPSIS
        判断一条解析备注是不是「解析过程的中间结论」（技术细节）。
    .DESCRIPTION
        page / click 源解析时会留下几条过程性备注（页面上有几个候选链接、地址由无头浏览器点击取得、
        SHA-256 从页面哪个位置提取等）——写进解析锁备查，但普通展示里没有参考价值：用户关心的是
        「下载什么、存到哪、怎么校验」，不是解析器怎么算出地址的。这些备注只在 --verbose 下展示；
        排查问题的口径（口径变化时这里要同步）：
          ① 页面上一共找到 N 个下载链接，已取第一个           —— page 源 link 多候选
          ② 点击后浏览器发起了 N 个下载，已取第一个           —— page 源 click 多下载
          ③ 点击中间页后浏览器发起了 N 个下载，已取第一个     —— page 源 thenClick 多下载
          ④ 下载地址由系统浏览器（…）点击页面按钮取得。       —— click / thenClick 取址方式
          ⑤ 已按文件名从下载页提取主包的 SHA-256（…）         —— files[].hashFrom: "page"
    #>
    param([string]$Note)

    if (-not $Note) { return $false }
    $technicalPrefixes = @(
        '页面上一共找到 ',
        '点击后浏览器发起了 ',
        '点击中间页后浏览器发起了 ',
        '下载地址由系统浏览器',
        '已按文件名从下载页提取主包的 '
    )
    foreach ($prefix in $technicalPrefixes) {
        if ($Note.StartsWith($prefix)) { return $true }
    }
    return $false
}
