#Requires -Version 5.1

function Get-WinstBrowserPageHtml {
    <#
    .SYNOPSIS
        用系统自带的 Microsoft Edge（无头模式）抓取页面 HTML（page 源声明 fetchWith: browser 时使用）。
    .DESCRIPTION
        与浏览器一致地访问页面：真实 User-Agent（Get-WinstBrowserHeaders）、禁用 UA-CH 客户端提示
        （不禁用的话无头模式会自报 HeadlessChrome，同样被站点拒绝）、限时等待后输出 DOM。
        浏览器用户数据目录指向**进程级复用的临时 profile**（Get-WinstBrowserProfileDir，不碰用户正在
        使用的浏览器配置）：每次新建 profile 会反复触发新用户目录的首次运行导入器扫描，又慢又吵；
        抓取失败时删掉该 profile 重建（防坏目录复用），进程正常退出时清理。
        代理与其它元数据请求同一口径（直连 → 代理重试）。
        抓取结果经管道直读（Invoke-WinstCapturedCommand，子进程不接触当前控制台），**不落临时文件**：
        `Start-Process -RedirectStandardOutput` 写文件再读的写法有句柄竞态——Edge 主进程退出 ≠ 输出流关闭
        （子进程或重定向复制仍在写），紧接着读文件会撞上「文件正由另一进程使用」。
        部分站点（如 filezilla-project.org）会拒绝 IWR / curl / 下载引擎（403），本函数抓取正常；页面里带签名的
        安装包地址（?h=…&x=…）下载引擎能正常下载——所以只有「抓页面」这一步需要浏览器。
    .OUTPUTS
        @{ Ok; Html; Error; Engine }
    #>
    param(
        [hashtable]$Context,
        [Parameter(Mandatory = $true)][string]$Url,
        [int]$TimeoutSec = 60
    )

    $result = @{ Ok = $false; Html = ''; Error = ''; Engine = '' }
    $exe = Get-WinstSystemBrowserExe
    if (-not $exe) {
        $result.Error = '系统里没有找到 Microsoft Edge（Windows 自带的浏览器内核，无头抓取只用它）'
        return $result
    }
    $result.Engine = Split-Path -Leaf $exe

    $ua = ''
    $headers = Get-WinstBrowserHeaders
    if ($headers -and $headers['User-Agent']) { $ua = [string]$headers['User-Agent'] }

    $attempts = @(Get-WinstProxyAttempts -Context $Context)
    $lastError = ''
    foreach ($proxyUrl in $attempts) {
        try {
            $profileDir = Get-WinstBrowserProfileDir

            # 逐项按 Windows argv 规则加引号（Format-WinstCommandArgument）：profile 目录来自
            # %TEMP%，用户名带空格时（C:\Users\John Smith\...）不加引号会被空格截断，
            # 浏览器会把后半段当成要打开的地址，profile 落到非预期位置
            $argList = @(
                '--headless=new'
                '--disable-gpu'
                '--no-first-run'
                '--no-default-browser-check'
                '--disable-extensions'
                '--disable-features=UserAgentClientHint'
                ('--user-agent=' + (Format-WinstCommandArgument -Value $ua))
                ('--user-data-dir=' + (Format-WinstCommandArgument -Value $profileDir))
                '--virtual-time-budget=8000'
            )
            if ($proxyUrl) { $argList += ('--proxy-server=' + (Format-WinstCommandArgument -Value ([string]$proxyUrl))) }
            $argList += '--dump-dom'
            $argList += (Format-WinstCommandArgument -Value $Url)

            if ((Get-WinstState -Name WinstOptions) -and (Get-WinstState -Name WinstOptions).Verbose) {
                $note = ''
                if ($proxyUrl) { $note = ('（代理 {0}）' -f $proxyUrl) }
                Write-Host ('  [verbose] 用系统浏览器抓取 {0}{1}' -f $Url, $note) -ForegroundColor DarkGray
            }

            $run = Invoke-WinstCapturedCommand -FilePath $exe -Arguments ($argList -join ' ') -TimeoutMs ($TimeoutSec * 1000)
            if ($run.TimedOut) {
                $lastError = ('浏览器抓取超时（{0} 秒未完成）' -f $TimeoutSec)
                Reset-WinstBrowserProfile
                continue
            }
            if (-not $run.Ok) {
                $lastError = ('启动系统浏览器失败：{0}' -f [string]$run.Error)
                Reset-WinstBrowserProfile
                continue
            }

            $html = [string]$run.Text
            if (-not $html) {
                $lastError = '浏览器没有返回页面内容'
                Reset-WinstBrowserProfile
                continue
            }

            $result.Html = $html
            $result.Ok = $true
            $lastError = ''
            break
        } catch {
            $lastError = $_.Exception.Message
            Reset-WinstBrowserProfile
        }
    }

    if (-not $result.Ok) {
        $result.Error = $lastError
        if (@($attempts).Count -gt 1) { $result.Error = ('{0}（直连与代理均失败）' -f $lastError) }
    }
    return $result
}
