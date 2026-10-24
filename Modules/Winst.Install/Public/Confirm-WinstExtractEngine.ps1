#Requires -Version 5.1

function Confirm-WinstExtractEngine {
    <#
    .SYNOPSIS
        确保解压引擎可用：不存在时先自动下载并安装 7-Zip-CLI；
        已存在且软件源里有新版本时自动更新。
    .DESCRIPTION
        失败时也返回 Ok = $false（调用方仍可尝试系统 tar.exe / Expand-Archive 兜底）。
    .OUTPUTS
        @{ Ok; Exe; Error; Installed }
    #>
    param(
        [Parameter(Mandatory = $true)][hashtable]$Context,
        [switch]$Quiet
    )

    return (Confirm-WinstEngine -Context $Context -Id (Get-WinstExtractEngineId) -Quiet:$Quiet)
}
