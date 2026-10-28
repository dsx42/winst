#Requires -Version 5.1

function Get-WinstProxyAttempts {
    <#
    .SYNOPSIS
        按 proxy / proxyMode 生成代理尝试序列（'' 表示直连），供下载类调用共用。

    .DESCRIPTION
        模式（`proxyMode`，大小写不敏感）：

        | 取值 | 下载类请求（软件包 / 引擎包） | 其它请求（元数据 GET / HEAD） |
        |---|---|---|
        | `auto`（默认） | 先直连、失败再代理 | 先直连、失败再代理 |
        | `always` | 只走代理 | 只走代理 |
        | `off` | 只直连 | 只直连 |
        | `download-direct` | 先直连、失败再代理 | **只走代理** |

        `download-direct` 用于「网页 / API 必须借代理才打得开，但大文件本身直连很快」的环境：
        元数据一律走代理，包下载优先进直连，直连不通再退回代理。

        「下载类」由调用方传 `-Download` 声明：
        包下载与引擎引导下载传它；清单刷新、校验器 HEAD 探测、版本页抓取不传。
        `--proxy` 临时覆盖 config 的地址；显式传了 `--proxy` 而配置是 off 时按 always 处理
        （用户当次意图优先）。

    .PARAMETER Context
        运行上下文（读 config 里的 proxy / proxyMode）。

    .PARAMETER Download
        本次是「下载软件包 / 引擎包」类请求，按 download-direct 模式口径生成序列。

    .OUTPUTS
        [string[]] 依次尝试的代理地址，'' = 直连
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

    # 没配代理地址时四种模式（auto / always / off / download-direct）都退化为「只直连」
    if (-not $proxy) { return @('') }

    $attempts = @()
    if ($mode -eq 'off') {
        $attempts += ''
    } elseif ($mode -eq 'always') {
        $attempts += $proxy
    } elseif ($mode -eq 'download-direct') {
        if ($Download) {
            # 下载：先直连，失败再代理
            $attempts += ''
            $attempts += $proxy
        } else {
            # 其它请求：直接用代理，不试直连
            $attempts += $proxy
        }
    } else {
        $attempts += ''
        $attempts += $proxy
    }
    return $attempts
}
