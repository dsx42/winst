#Requires -Version 5.1

function Invoke-ManifestRefreshAll {
    <#
    .SYNOPSIS
        刷新全部软件源，逐个输出结果与汇总。
    .DESCRIPTION
        供「管理软件源」的 a 键使用。离线模式下直接说明原因并返回，不做任何联网尝试。

    .OUTPUTS
        @{ Failed = <int>; Network = <bool> }
    #>
    param([Parameter(Mandatory = $true)][hashtable]$Context, [object[]]$Sources)

    $result = @{ Failed = 0; Network = $false }

    if ((Get-WinstState -Name WinstOptions) -and (Get-WinstState -Name WinstOptions).Offline) {
        Write-Host '  当前为离线模式（--offline），刷新软件源需要联网。' -ForegroundColor Yellow
        Write-Host '  离线安装需要已有的解析结果和安装包。本地清单也须先移除 --offline 并刷新一次。' -ForegroundColor DarkGray
        return $result
    }

    $title = '刷新软件源'
    if (-not $PSBoundParameters.ContainsKey('Sources')) {
        $title = '刷新全部软件源'
        $sources = @(Get-ManifestSourceList -Context $Context)
    }

    Write-Section $title

    $failed = 0
    foreach ($source in $sources) {
        $one = Invoke-ManifestRefreshSource -Context $Context -Source $source
        if (-not $one.Ok) { $failed++; if ($one.Network) { $result.Network = $true } }
    }

    $result.Failed = $failed
    Write-Host ''
    Write-Host ('  汇总: 成功 {0} / 失败 {1}' -f ($sources.Count - $failed), $failed) -ForegroundColor Gray
    return $result
}
