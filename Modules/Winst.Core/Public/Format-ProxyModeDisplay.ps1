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
        'always'          { return '始终走代理（每次都直接走代理，不做直连尝试）' }
        'off'             { return '不使用代理（只直连）' }
        'download-direct' { return '下载直连优先（下载先直连、失败再用代理；其它请求直接走代理）' }
        'auto'            { return '自动（先直连，失败后再用代理重试）' }
        default {
            if ($mode) { return $mode }
            return '自动（先直连，失败后再用代理重试）'
        }
    }
}
