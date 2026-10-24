#Requires -Version 5.1

function Format-ProxyModeDisplay {
    <#
    .SYNOPSIS
        把「代理模式」配置显示成普通用户能看懂的说明。
    .DESCRIPTION
        取值只有 auto / always / off 三档（设置页用选项式交互挑选），
        菜单里的「当前」与设置页的选项说明共用这里，三处说法始终一致。
    #>
    param($Value)

    $mode = ''
    if ($null -ne $Value) { $mode = ([string]$Value).Trim().ToLowerInvariant() }
    switch ($mode) {
        'always' { return '始终走代理（每次都直接走代理）' }
        'off'    { return '不使用代理（只直连）' }
        'auto'   { return '自动（先直连，失败再用代理重试）' }
        default {
            if ($mode) { return $mode }
            return '自动（先直连，失败再用代理重试）'
        }
    }
}
