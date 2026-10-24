#Requires -Version 5.1

function Get-WinstBrowserClickedLink {
    <#
    .SYNOPSIS
        用系统自带的 Microsoft Edge（无头 + DevTools 协议）点开页面上的下载按钮，取回浏览器真正发起的下载地址。
    .DESCRIPTION
        给「下载地址不写在页面里、点了按钮才生成」的站点用（如 Google Chrome 的下载页：地址在点击时由页面脚本
        拼出来、直接触发下载）。流程：打开 pageUrl → 依次执行 click 的每一步（定位元素 + 派发真实鼠标点击）→
        监听浏览器上报的下载事件拿到地址；地址到手后**不执行后续点击**，下载照旧交给 FluxDown。
        每步可以带一点容错：这一步没找到可点的元素就跳过并在 --verbose / 备注里说明——真正判定成败的是
        「最后有没有拿到下载地址」，拿不到就报明原因，并列出点击期间观察到的「像安装包」的请求地址便于排查。
    .OUTPUTS
        @{ Ok; DownloadUrls; Html; Error; Engine; Notes }
    #>
    param(
        [hashtable]$Context,
        [Parameter(Mandatory = $true)][string]$Url,
        [Parameter(Mandatory = $true)]$ClickSpecs,
        [switch]$WantHtml,
        [int]$TimeoutSec = 90
    )

    $result = @{ Ok = $false; DownloadUrls = @(); Html = ''; Error = ''; Engine = ''; Notes = @() }
    $steps = @($ClickSpecs)
    $attempts = @(Get-WinstProxyAttempts -Context $Context)
    $lastError = ''

    $userAgent = ''
    $headers = Get-WinstBrowserHeaders
    if ($headers -and $headers['User-Agent']) { $userAgent = [string]$headers['User-Agent'] }

    foreach ($proxyUrl in $attempts) {
        $session = $null
        try {
            $overallDeadline = [DateTime]::Now.AddSeconds($TimeoutSec)
            if ((Get-WinstState -Name WinstOptions) -and (Get-WinstState -Name WinstOptions).Verbose) {
                $note = ''
                if ($proxyUrl) { $note = ('（代理 {0}）' -f $proxyUrl) }
                Write-Host ('  [verbose] 用系统浏览器点击下载按钮取地址 {0}{1}' -f $Url, $note) -ForegroundColor DarkGray
            }

            $session = New-WinstDevToolsSession -ProxyUrl $proxyUrl -UserAgent $userAgent
            if (-not $session.Ok) { $lastError = [string]$session.Error; continue }
            $result.Engine = [string]$session.Engine

            $null = Invoke-WinstDevToolsCommand -Session $session -Method 'Page.navigate' -Params @{ url = $Url }

            # 等页面加载完（Page.loadEventFired）+ 一小段脚本挂载时间：按钮的点击处理器是随后才挂上的，
            # 不等就点会点空。超时也继续往下走（有的页面长轮询，永远不给 loadEventFired）。
            $readyDeadline = $overallDeadline
            $readyCap = [DateTime]::Now.AddSeconds(25)
            if ($readyCap -lt $readyDeadline) { $readyDeadline = $readyCap }
            while (-not $session.LoadEventFired -and [DateTime]::Now -lt $readyDeadline) {
                Wait-WinstDevToolsMessages -Session $session -Milliseconds 100
            }
            if (-not $session.LoadEventFired) {
                $result.Notes += ('页面在 25 秒内没有报告加载完成，仍继续尝试点击 {0}' -f $Url)
            }
            Wait-WinstDevToolsMessages -Session $session -Milliseconds 2500

            foreach ($step in $steps) {
                if ($session.Downloads.Count -gt 0) { break }
                $stepLabel = Format-LinkSpec -Spec $step
                $stepResult = $null
                for ($attempt = 1; $attempt -le 3; $attempt++) {
                    $stepResult = Invoke-WinstBrowserClickStep -Session $session -Spec $step
                    if ($stepResult.Clicked) { break }
                    # 目标可能还在渲染（点开条款弹层有动画）：等一下再找一次
                    Wait-WinstDevToolsMessages -Session $session -Milliseconds 1500
                }
                if ($stepResult.Clicked) {
                    if ((Get-WinstState -Name WinstOptions) -and (Get-WinstState -Name WinstOptions).Verbose) {
                        Write-Host ('  [verbose] 已点击「{0}」' -f $stepLabel) -ForegroundColor DarkGray
                    }
                    Wait-WinstDevToolsMessages -Session $session -Milliseconds 2500
                } else {
                    $reason = ''
                    if ($stepResult.Error) { $reason = ('：{0}' -f $stepResult.Error) }
                    $result.Notes += ('点击步骤「{0}」没有点到（{1}）{2}' -f $stepLabel, '可能页面结构变了', $reason)
                }
            }

            # 等浏览器把下载地址交出来（受整体超时约束）
            $downloadDeadline = [DateTime]::Now.AddSeconds(20)
            if ($overallDeadline -lt $downloadDeadline) { $downloadDeadline = $overallDeadline }
            while ($session.Downloads.Count -eq 0 -and [DateTime]::Now -lt $downloadDeadline) {
                Wait-WinstDevToolsMessages -Session $session -Milliseconds 500
            }

            if ($WantHtml) {
                $html = Get-WinstDevToolsValue -Session $session -Expression 'document.documentElement.outerHTML'
                if ($html) { $result.Html = [string]$html }
            }

            if ($session.Downloads.Count -eq 0) {
                $lastError = ('点击下载页 {0} 上的按钮后，浏览器没有发起任何下载（页面结构或交互流程可能变了）' -f $Url)
                $candidates = @(Get-DistinctValues -Values @($session.Requests))
                if ($candidates.Count -gt 0) {
                    $shown = @($candidates | Select-Object -First 5)
                    $lastError += ('；点击期间观察到的候选地址：{0}' -f ($shown -join '、'))
                }
                continue
            }

            $result.DownloadUrls = @(Get-DistinctValues -Values @($session.Downloads))
            $result.Notes += ('下载地址由系统浏览器（{0}）点击页面按钮取得。' -f [string]$session.Engine)
            $result.Ok = $true
            $lastError = ''
            break
        } catch {
            $lastError = $_.Exception.Message
        } finally {
            Close-WinstDevToolsSession -Session $session
        }
    }

    if (-not $result.Ok) {
        $result.Error = $lastError
        if (@($attempts).Count -gt 1) { $result.Error = ('{0}（直连与代理均失败）' -f $lastError) }
    }
    return $result
}
