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

        **两条通道**：`--dump-dom`（走子进程 stdout，快）与 DevTools 协议（走 WebSocket，见
        Get-WinstBrowserPageHtmlByDevTools）。**提权进程里只用后者**：Edge 从提权进程启动时会把自己降权重启，
        重定向到 winst 的 stdout / stderr 一个字都收不到（profile 却建得好好的、也没有崩溃），
        `--dump-dom` 因此在提权进程里注定空白；winst 安装和刷新都跑在提权进程里，这条不是偶发。
        非提权进程先走 `--dump-dom`，拿不到内容再用 CDP 兜一次。

        两条通道都失败才会报错。`--dump-dom` 这条还会先清掉占着 profile 的残留浏览器
        （Stop-WinstBrowserProfileProcesses）：profile 被占用时它会把命令行转交给在跑的实例、自己立刻退出，
        stdout 同样为空；清理后仍拿不到内容时删掉 profile、换新目录再试一轮（每个代理最多两轮）。
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

    # 提权与否决定先走哪条通道（见上方说明）：提权进程里 --dump-dom 的 stdout 是空的，先试它只会白等一轮
    $isElevated = $false
    try {
        $isElevated = (New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())).IsInRole(
            [Security.Principal.WindowsBuiltInRole]::Administrator)
    } catch { $isElevated = $false }

    $devToolsError = ''
    if ($isElevated) {
        $viaDevTools = Get-WinstBrowserPageHtmlByDevTools -Context $Context -Url $Url -TimeoutSec $TimeoutSec
        if ($viaDevTools.Ok) {
            $result.Html = [string]$viaDevTools.Html
            $result.Ok = $true
            $result.Engine = [string]$viaDevTools.Engine
            return $result
        }
        $devToolsError = [string]$viaDevTools.Error
    }

    $ua = ''
    $headers = Get-WinstBrowserHeaders
    if ($headers -and $headers['User-Agent']) { $ua = [string]$headers['User-Agent'] }

    $attempts = @(Get-WinstProxyAttempts -Context $Context)
    $lastError = ''
    foreach ($proxyUrl in $attempts) {
        # 同一代理最多两轮：第一轮用复用的 profile，失败后删掉它、第二轮自动换新目录
        for ($round = 1; $round -le 2; $round++) {
            try {
                $profileDir = Get-WinstBrowserProfileDir
                # 上一次抓取（或上一次刷新）残留的实例会占着这个 profile，先清掉（见上方说明）
                $null = Stop-WinstBrowserProfileProcesses -ProfileDir $profileDir

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
                    # 超时已经等了一整轮，换 profile 重试多半只是再等一轮：直接换下一个代理
                    $lastError = ('浏览器抓取超时（{0} 秒未完成）' -f $TimeoutSec)
                    Reset-WinstBrowserProfile
                    break
                }
                if (-not $run.Ok) {
                    $lastError = ('启动系统浏览器失败：{0}' -f [string]$run.Error)
                    Reset-WinstBrowserProfile
                    continue
                }

                $html = [string]$run.Text
                if (-not $html) {
                    # 浏览器什么都没输出：把它的 stderr 尾部带上（顶多两百字符），否则只剩一句没有线索的提示
                    $lastError = '浏览器没有返回页面内容'
                    $errText = ([string]$run.ErrText).Trim()
                    if ($errText) {
                        $errText = ($errText -replace '\s+', ' ')
                        if ($errText.Length -gt 200) { $errText = $errText.Substring($errText.Length - 200) }
                        $lastError += ('（浏览器输出：{0}）' -f $errText)
                    }
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
        if ($result.Ok) { break }
    }

    if ($result.Ok) { return $result }

    if (@($attempts).Count -gt 1) { $lastError = ('{0}（直连与代理均失败）' -f $lastError) }

    if ($isElevated) {
        # 提权进程只可能走到这里：CDP 先试过、--dump-dom 也没内容。两条原因都带上
        $result.Error = ('DevTools 抓取失败：{0}；--dump-dom 也没有输出：{1}' -f $devToolsError, $lastError)
        return $result
    }

    # 非提权进程先试过 --dump-dom 了，再给 CDP 一次机会（有的环境里 stdout 管道就是收不到东西）
    $viaDevTools = Get-WinstBrowserPageHtmlByDevTools -Context $Context -Url $Url -TimeoutSec $TimeoutSec
    if ($viaDevTools.Ok) {
        $result.Html = [string]$viaDevTools.Html
        $result.Ok = $true
        $result.Engine = [string]$viaDevTools.Engine
        return $result
    }
    $result.Error = ('{0}；改用 DevTools 协议抓取也失败：{1}' -f $lastError, [string]$viaDevTools.Error)
    return $result
}
