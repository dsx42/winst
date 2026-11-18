#Requires -Version 5.1

function Invoke-ManifestRefreshAll {
    <#
    .SYNOPSIS
        刷新全部软件源，逐个输出结果与汇总。
    .DESCRIPTION
        供「管理软件源」的 a 键使用。离线模式下直接说明原因并返回，不做任何联网尝试。

    .OUTPUTS
        @{ Aborted = <bool>; Failed = <int>; Total = <int> }
    #>
    param([Parameter(Mandatory = $true)][hashtable]$Context, [object[]]$Sources)

    $result = @{ Aborted = $false; Failed = 0; Total = 0; Network = $false }

    if ((Get-WinstState -Name WinstOptions) -and (Get-WinstState -Name WinstOptions).Offline) {
        Write-Host '  当前为离线模式（--offline），刷新软件源需要联网。' -ForegroundColor Yellow
        Write-Host '  请移除 --offline 后重试（本地清单的读取不受影响，安装时仍可直接使用）。' -ForegroundColor DarkGray
        $result.Aborted = $true
        return $result
    }

    $title = '刷新软件源'
    if (-not $PSBoundParameters.ContainsKey('Sources')) {
        $title = '刷新全部软件源'
        $sources = @(Get-ManifestSourceList -Context $Context)
    }
    if ($sources.Count -eq 0) {
        Write-Host '  当前没有软件源。' -ForegroundColor Yellow
        $result.Aborted = $true
        return $result
    }

    Write-Section $title

    $failed = 0
    foreach ($source in $sources) {
        $one = Invoke-ManifestRefreshSource -Context $Context -Source $source
        if (-not $one.Ok) { $failed++; if ($one.Network) { $result.Network = $true } }
    }

    $result.Total = $sources.Count
    $result.Failed = $failed
    Write-Host ''
    Write-Host ('  汇总: 成功 {0} / 失败 {1}' -f ($sources.Count - $failed), $failed) -ForegroundColor Gray
    return $result
}
