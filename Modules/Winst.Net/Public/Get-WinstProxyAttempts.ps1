#Requires -Version 5.1

function Get-WinstProxyAttempts {
    <#
    .SYNOPSIS
        按 proxy / proxyMode 生成代理尝试序列（'' 表示直连），供下载类调用共用。
    .DESCRIPTION
        与元数据请求（Invoke-WinstHttpRequest）同一规则：off = 仅直连；always = 仅代理；
        auto = 先直连、失败再代理。`--proxy` 临时覆盖 config 的地址。
    #>
    param([hashtable]$Context)

    $proxy = ''
    if ((Get-WinstState -Name WinstOptions) -and (Get-WinstState -Name WinstOptions).Proxy) {
        $proxy = ([string](Get-WinstState -Name WinstOptions).Proxy).Trim()
    } elseif ($Context) {
        $proxy = ([string](Get-ConfigValue -Config $Context.Config -Key 'proxy')).Trim()
    }

    $mode = 'auto'
    if ($Context) {
        $configured = [string](Get-ConfigValue -Config $Context.Config -Key 'proxyMode')
        if ($configured) { $mode = $configured.Trim().ToLowerInvariant() }
    }
    # 显式传了 --proxy：即使配置为 off 也按「始终走代理」处理（用户当次意图优先）
    if ($proxy -and (Get-WinstState -Name WinstOptions) -and (Get-WinstState -Name WinstOptions).Proxy -and $mode -eq 'off') { $mode = 'always' }

    $attempts = @()
    if ($mode -eq 'off' -or -not $proxy) {
        $attempts += ''
    } elseif ($mode -eq 'always') {
        $attempts += $proxy
    } else {
        $attempts += ''
        $attempts += $proxy
    }
    return $attempts
}
