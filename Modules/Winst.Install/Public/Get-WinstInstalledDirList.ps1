#Requires -Version 5.1

function Get-WinstInstalledDirList {
    <#
    .SYNOPSIS
        列出安装根目录下的软件目录名（只读，供「切换安装位置」时的提示使用）。

    .DESCRIPTION
        切换软件安装位置后，已装的软件仍留在旧位置。用户需要知道「旧位置里有哪些东西」，
        否则容易以为软件丢了。

        只读：只枚举目录名，不写任何文件、不改系统项、不写台账。

        口径：
        - 只取旧位置下的一级子目录（软件按 id 建目录，见 Initialize-WinstInstallContext）；
        - `winst` 自己也列出来（它确实在旧位置，用户需要知道）；
        - 旧位置不存在 / 读不出来时返回空数组，由调用方决定是否提示。

    .OUTPUTS
        [string[]] 目录名，按名称排序
    #>
    param(
        [Parameter(Mandatory = $true)][string]$InstallRoot
    )

    if (-not $InstallRoot) { return @() }
    if (-not (Test-Path -LiteralPath $InstallRoot -PathType Container)) { return @() }

    $names = @()
    try {
        foreach ($dir in @(Get-ChildItem -LiteralPath $InstallRoot -Directory -Force -ErrorAction Stop | Sort-Object -Property Name)) {
            $name = [string]$dir.Name
            if ($name) { $names += $name }
        }
    } catch {
        return @()
    }

    return @($names)
}
