#Requires -Version 5.1

function Invoke-WinstSoftwareSourceRefresh {
    <#
    .SYNOPSIS
        从软件详情强制刷新当前软件在各软件源中的条目。
    .OUTPUTS
        [bool] 是否尝试刷新（离线或预览模式不执行）。
    #>
    param(
        [Parameter(Mandatory = $true)][hashtable]$Context,
        [Parameter(Mandatory = $true)][ValidateNotNullOrEmpty()][string]$Id
    )

    $options = Get-WinstState -Name WinstOptions
    if ($options -and $options.Offline) {
        Write-Host '  当前为离线模式（--offline），无法刷新软件源。' -ForegroundColor Yellow
        return $false
    }
    if ($options -and $options.DryRun) {
        Write-Host '  当前为预览模式（--dry-run），未刷新软件源；请退出预览模式后重试。' -ForegroundColor Yellow
        return $false
    }

    Write-Host ('  正在刷新「{0}」的软件源条目 …' -f $Id) -ForegroundColor Gray
    $refresh = Update-WinstStaleSources -Context $Context -Force -OnlyIds @($Id)
    Write-WinstRefreshErrors -Errors $refresh.Errors
    return (-not $refresh.Skipped)
}
