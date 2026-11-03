#Requires -Version 5.1

function Test-WinstProxyModeValue {
    <#
    .SYNOPSIS
        校验代理模式取值，返回归一化后的小写取值（不合法时为空串）。

    .DESCRIPTION
        合法取值只有四个：

        | 取值 | 含义 |
        |---|---|
        | `auto` | 先按系统默认连接，失败再用显式代理（默认） |
        | `always` | 始终使用配置的显式代理 |
        | `off` | 禁用显式代理，仍遵循系统代理 / PAC |
        | `download-direct` | 下载先按系统默认连接、失败再用显式代理；其它请求直接用显式代理 |

        没有配置代理地址时，各模式均使用系统默认连接。

        写错时**直接拒绝**而不是落一个无效值：无效值会让 Get-WinstProxyAttempts 悄悄退回 auto，
        用户以为设好了其实没生效。`config set proxyMode` 与设置菜单都走这里。

    .OUTPUTS
        [string] 归一化后的小写取值；不合法时为空串
    #>
    param([string]$Value)

    $mode = ([string]$Value).Trim().ToLowerInvariant()
    if (@('auto', 'always', 'off', 'download-direct') -contains $mode) { return $mode }
    return ''
}
