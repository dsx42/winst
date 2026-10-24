#Requires -Version 5.1

function Get-WinstUpdateModeName {
    <#
    .SYNOPSIS
        「设置 → 更新方式」当前的默认更新方式文本（已装软件详情的 u) 更新 与自定义更新里展示）。
    #>
    param([Parameter(Mandatory = $true)][hashtable]$Context)

    if ([bool](Get-ConfigValue -Config $Context.Config -Key 'updateFilesOnly' -Default $true)) {
        return (Get-WinstUpdateModeText -Mode 'keep')
    }
    return (Get-WinstUpdateModeText -Mode 'full')
}
