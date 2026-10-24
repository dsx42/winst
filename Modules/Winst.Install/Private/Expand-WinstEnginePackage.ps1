#Requires -Version 5.1

function Expand-WinstEnginePackage {
    <#
    .SYNOPSIS
        ② 解压引擎包 ③ 复制 / 改名（引擎均为 portable，无系统项）。
    .OUTPUTS
        @{ Ok; Error }
    #>
    param([hashtable]$Context, [string]$Id, $Plan, [string]$InstallDir, [string]$ArchivePath, [switch]$Quiet)

    $install = Get-EntryValue -Entry $Plan -Key 'install' -Default $null
    $method = Get-EntryString -Entry $install -Key 'method'
    if ($method -ne 'portable') {
        return @{ Ok = $false; Error = ('{0} 的类型不是绿色版（{1}），无法自动安装' -f $Id, $method) }
    }

    if (Test-Path -LiteralPath $InstallDir -PathType Container) {
        Clear-WinstInstallDir -Dir $InstallDir
    }
    $null = New-Item -ItemType Directory -Path $InstallDir -Force -ErrorAction SilentlyContinue

    $stripTopDir = Get-EntryValue -Entry $install -Key 'stripTopDir' -Default $true
    $extractFiles = @(Get-EntryArray -Entry $install -Key 'extractFiles')
    $layout = Expand-WinstArchiveLayout -Context $Context -ArchivePath $ArchivePath -DestDir $InstallDir -StripTopDir $stripTopDir -ExtractFiles $extractFiles
    if (-not $layout.Ok) {
        return @{ Ok = $false; Error = ('解压 {0} 失败：{1}' -f (Split-Path -Leaf $ArchivePath), $layout.Error) }
    }

    return (Invoke-WinstPostInstallCopy -Plan $Plan -InstallDir $InstallDir)
}
