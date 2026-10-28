#Requires -Version 5.1

function Get-WinstBrowserHeaders {
    <#
    .SYNOPSIS
        软件官网下载页抓取用的浏览器式请求头。
    .DESCRIPTION
        部分站点（如 filezilla-project.org）会按客户端特征拒绝自动化请求，只给浏览器放行：
        page 源的页面抓取（IWR 通道）带上这组请求头；部分 HEAD 探测调用点也会显式传入，
        取值与本机真实浏览器（Windows 自带的 Microsoft Edge）一致：User-Agent + Accept + Accept-Language + Cache-Control；
        无头浏览器抓取（Get-WinstBrowserPageHtml）也复用这里的 User-Agent。
        User-Agent 串是 Chromium 系通用的「Chrome/xxx」形态（Edge 自报的 UA 也是这个形状），它只是一串
        请求头文本，不代表 winst 依赖 Google Chrome（浏览器只认系统自带的 Edge，见 Get-WinstSystemBrowserExe）。
        **不带 Accept-Encoding**：PowerShell 5.1 的 Invoke-WebRequest 不会自动解压响应，
        声明 gzip / br 只会把正文变成压缩字节（乱码）；不声明时服务器按未压缩返回，内容才可读。
    #>
    return @{
        'User-Agent'      = 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/152.0.0.0 Safari/537.36'
        'Accept'          = 'text/html,application/xhtml+xml,application/xml;q=0.9,image/avif,image/webp,image/apng,*/*;q=0.8,application/signed-exchange;v=b3;q=0.7'
        'Accept-Language' = 'zh-CN,zh;q=0.9'
        'Cache-Control'   = 'no-cache'
    }
}
