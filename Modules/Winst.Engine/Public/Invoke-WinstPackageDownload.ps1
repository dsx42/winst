#Requires -Version 5.1

function Invoke-WinstPackageDownload {
    <#
    .SYNOPSIS
        经下载引擎下载单个安装包（按代理解析结果自动重试；不设 IWR 兜底）。
    .OUTPUTS
        @{ Ok; ExitCode; Error; Segments; Retried }
    #>
    param(
        [Parameter(Mandatory = $true)][hashtable]$Context,
        [Parameter(Mandatory = $true)][string]$Url,
        [Parameter(Mandatory = $true)][string]$DestDir,
        [string]$FileName = ''
    )

    $attempts = @(Get-WinstProxyAttempts -Context $Context -Download)
    # 每条返回路径都必须带 Retried。调用方会无条件读 $dl.Retried，
    # 而 Set-StrictMode -Version 2 下缺少该键会直接报错
    # （「找不到属性 Retried」），把一次成功的下载变成失败。
    $last = @{ Ok = $false; ExitCode = -1; Error = ''; Segments = 0; Retried = $false }

    foreach ($proxyUrl in $attempts) {
        $last = Invoke-WinstFluxDownDownload -Context $Context -Url $Url -DestDir $DestDir -FileName $FileName -ProxyUrl ([string]$proxyUrl)
        $last['Retried'] = $false
        if ($last.Ok) { return $last }
    }
    if ($attempts.Count -gt 1) {
        $last.Error = ('{0}（直连与代理均失败）' -f $last.Error)
    }

    # 多段并发被限速 stall 的补救：
    # 只对「可重试」的失败再试一档，且**只再试一次**（用主来源、单连接），不与代理链相乘。
    $retryableCodes = @(1, 2, 5, 7)   # 1 未知错误 / 2 超时 / 5 网络错误 / 7 中断未完成
    if ($retryableCodes -contains [int]$last.ExitCode) {
        $retry = Invoke-WinstFluxDownDownload -Context $Context -Url $Url -DestDir $DestDir -FileName $FileName `
            -ProxyUrl ([string]$attempts[0]) -Segments 1
        $retry['Retried'] = $true
        if ($retry.Ok) { return $retry }
        $retry.Error = ('{0}（已按单连接重试一次）' -f $retry.Error)
        return $retry
    }
    return $last
}
