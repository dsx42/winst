#Requires -Version 5.1

function Invoke-ManifestRefreshSource {
    <#
    .SYNOPSIS
        刷新一个软件源并渲染它的软件清单解析结果。
    .DESCRIPTION
        供「管理软件源」的详情页、刷新全部、「检查更新」之外的刷新入口共用，
        保证同一个动作在哪儿都输出同样的内容与口径。
    .OUTPUTS
        @{ Ok = <bool>; Network = <bool> }
    #>
    param(
        [Parameter(Mandatory = $true)][hashtable]$Context,
        [Parameter(Mandatory = $true)]$Source
    )

    $name = [string]$Source['name']
    Write-Host ('  正在刷新 {0} …' -f $name) -ForegroundColor Gray

    $r = Update-ManifestSource -Context $Context -Source $Source
    $result = @{ Ok = [bool]$r.Success; Network = [bool]$r.Network }

    if (-not $r.Success) {
        Write-Host ('    {0}: {1}' -f $name, $r.Message) -ForegroundColor Red
        return $result
    }

    Write-Host ('    {0}: {1}' -f $name, $r.Message) -ForegroundColor Green
    if ($r.Total -gt 0) {
        Show-ManifestResolution -Context $Context -Name $name -Apps $r.Apps `
            -Preview:([bool]((Get-WinstState -Name WinstOptions) -and (Get-WinstState -Name WinstOptions).DryRun))
    }
    return $result
}
