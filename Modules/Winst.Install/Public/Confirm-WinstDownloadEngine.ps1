#Requires -Version 5.1

function Confirm-WinstDownloadEngine {
    <#
    .SYNOPSIS
        确保下载引擎可用：不存在时先自动下载并安装 FluxDown-CLI；
        已存在且软件源里有新版本时自动更新。
    .OUTPUTS
        @{ Ok; Exe; Error; Installed }
    #>
    param(
        [Parameter(Mandatory = $true)][hashtable]$Context,
        [switch]$Quiet
    )

    return (Confirm-WinstEngine -Context $Context -Id (Get-WinstDownloadEngineId) -Quiet:$Quiet)
}
