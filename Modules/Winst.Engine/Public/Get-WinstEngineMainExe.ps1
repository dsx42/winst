#Requires -Version 5.1

function Get-WinstEngineMainExe {
    <#
    .SYNOPSIS
        引擎条目的主程序（相对安装目录）；非引擎 id 返回空串。
    #>
    param([string]$Id)
    if ($Id -ceq (Get-WinstExtractEngineId)) { return (Get-WinstExtractEngineExe) }
    if ($Id -ceq (Get-WinstDownloadEngineId)) { return (Get-WinstDownloadEngineExe) }
    return ''
}
