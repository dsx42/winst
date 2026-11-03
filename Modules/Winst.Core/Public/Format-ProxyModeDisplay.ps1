#Requires -Version 5.1

function Format-ProxyModeDisplay {
    <#
    .SYNOPSIS
        把「代理模式」的取值变成普通用户能看懂的说明。
    .DESCRIPTION
        取值只有 auto / always / off / download-direct 四种，这里与设置页的选项式样、
        菜单上的「当前」显示共用同一套说明，改口径时只改这一处。
    #>
    param($Value)

    $mode = ''
    if ($null -ne $Value) { $mode = ([string]$Value).Trim().ToLowerInvariant() }
    switch ($mode) {
        'always'          { return '始终用显式代理（每次都直接使用配置的代理）' }
        'off'             { return '禁用显式代理（仍遵循系统代理 / PAC）' }
        'download-direct' { return '下载优先默认连接（失败再用显式代理；其它请求直接用显式代理）' }
        'auto'            { return '自动（先按系统默认连接，失败后再用显式代理重试）' }
        default {
            if ($mode) { return $mode }
            return '自动（先按系统默认连接，失败后再用显式代理重试）'
        }
    }
}
