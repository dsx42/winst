#Requires -Version 5.1

function Get-WinstStatePath {
    <#
    .SYNOPSIS
        台账文件路径：<安装根目录>\state.json（与各软件安装目录同级）。
    #>
    param([Parameter(Mandatory = $true)][string]$InstallRoot)
    return (Join-WinstPath $InstallRoot 'state.json')
}
