#Requires -Version 5.1

function Get-WinstSystemBrowserExe {
    <#
    .SYNOPSIS
        找系统自带的浏览器可执行文件（只用 Microsoft Edge）；找不到返回空串。
    .DESCRIPTION
        个别站点在客户端特征层面拒绝自动化请求（Invoke-WebRequest / curl 一律 403），
        系统自带的浏览器却能正常访问；page 源声明 fetchWith: browser 时用它抓页面。
        **只认 Edge**：Windows 10/11 自带（与 WebView2 同内核），属于操作系统组件、不引入任何额外依赖。
        用户自己安装的 Google Chrome **不探测、不使用**：
        兜底等于给 winst 加一条「机器上恰好装了 Chrome 才能用」的隐式依赖，与本项目「只用系统自带组件」的
        口径冲突——真找不到 Edge 时按失败明确报错，不做静默降级。
    #>
    $candidates = @()
    $pf86 = ''
    try { $pf86 = [string]${env:ProgramFiles(x86)} } catch { $pf86 = '' }
    $pf = ''
    try { $pf = [string]$env:ProgramFiles } catch { $pf = '' }
    if ($pf86) { $candidates += (Join-WinstPath $pf86 'Microsoft\Edge\Application\msedge.exe') }
    if ($pf) { $candidates += (Join-WinstPath $pf 'Microsoft\Edge\Application\msedge.exe') }

    foreach ($one in $candidates) {
        if ($one -and (Test-Path -LiteralPath $one -PathType Leaf)) { return $one }
    }
    return ''
}
