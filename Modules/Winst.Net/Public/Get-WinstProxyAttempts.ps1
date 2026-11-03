#Requires -Version 5.1

function Get-WinstProxyAttempts {
    <#
    .SYNOPSIS
        按 proxy / proxyMode 生成代理尝试序列（'' 表示系统默认连接），供下载类调用共用。

    .DESCRIPTION
        模式（`proxyMode`，大小写不敏感）：

        | 取值 | 下载类请求（软件包 / 引擎包） | 其它请求（元数据 GET / HEAD） |
        |---|---|---|
        | `auto`（默认） | 先按系统默认连接、失败再用显式代理 | 先按系统默认连接、失败再用显式代理 |
        | `always` | 只用显式代理 | 只用显式代理 |
        | `off` | 系统默认连接 | 系统默认连接 |
        | `download-direct` | 先按系统默认连接、失败再用显式代理 | **只用显式代理** |

        `download-direct` 用于「网页 / API 需要显式代理，但大文件按系统默认连接就很快」的环境：
        元数据使用显式代理，包下载先按系统默认连接，失败再用显式代理。
        系统默认连接仍可能使用系统代理 / PAC；off 不保证绕过它们。

        「下载类」由调用方传 `-Download` 声明：
        包下载与引擎引导下载传它；清单刷新、校验器 HEAD 探测、版本页抓取不传。
        `--proxy` 临时覆盖 config 的地址；显式传了 `--proxy` 而配置是 off 时按 always 处理
        （用户当次意图优先）。

    .PARAMETER Context
        运行上下文（读 config 里的 proxy / proxyMode）。

    .PARAMETER Download
        本次是「下载软件包 / 引擎包」类请求，按 download-direct 模式口径生成序列。

    .OUTPUTS
        [string[]] 依次尝试的代理地址，'' = 系统默认连接
    #>
    param([hashtable]$Context, [switch]$Download)

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

    # 没配显式代理地址时四种模式都使用系统默认连接。
    if (-not $proxy) { return @('') }

    $attempts = @()
    if ($mode -eq 'off') {
        $attempts += ''
    } elseif ($mode -eq 'always') {
        $attempts += $proxy
    } elseif ($mode -eq 'download-direct') {
        if ($Download) {
            # 下载：先按系统默认连接，失败再用显式代理。
            $attempts += ''
            $attempts += $proxy
        } else {
            # 其它请求直接使用显式代理。
            $attempts += $proxy
        }
    } else {
        $attempts += ''
        $attempts += $proxy
    }
    return $attempts
}
