#Requires -Version 5.1

function Confirm-WinstExtractEngine {
    <#
    .SYNOPSIS
        确保解压引擎可用：不存在时先自动下载并安装 7-Zip-CLI；
        已存在且软件源里有新版本时自动更新；当前正在安装的同名目标不重复引导或更新。
    .DESCRIPTION
        失败时返回 Ok = $false；依赖解压引擎的普通软件安装必须中止，不继续解压或修改安装目录。
    .OUTPUTS
        @{ Ok; Exe; Error; Installed }
    #>
    param(
        [Parameter(Mandatory = $true)][hashtable]$Context,
        [switch]$Quiet
    )

    return (Confirm-WinstEngine -Context $Context -Id (Get-WinstExtractEngineId) -Quiet:$Quiet)
}
