#Requires -Version 5.1

function Expand-WinstEnginePackage {
    <#
    .SYNOPSIS
        ② 解压引擎包 ③ 复制 / 改名（引擎均为 portable，无系统项）。
    .OUTPUTS
        @{ Ok; Error }
    #>
    param([hashtable]$Context, [string]$Id, $Plan, [string]$InstallDir, [string]$ArchivePath)

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
    # 7-Zip-CLI 的引导包是官方自解压安装包：引擎还没装上时只能靠系统 tar，老系统的 tar 打不开它，
    # 因此只给这一条允许「切出内嵌载荷」的兜底档。
    $allowSfxPayload = ($Id -eq (Get-WinstExtractEngineId))
    $layout = Expand-WinstArchiveLayout -Context $Context -ArchivePath $ArchivePath -DestDir $InstallDir `
        -StripTopDir $stripTopDir -ExtractFiles $extractFiles -AllowSfxPayload:$allowSfxPayload
    if (-not $layout.Ok) {
        return @{ Ok = $false; Error = ('解压 {0} 失败：{1}' -f (Split-Path -Leaf $ArchivePath), $layout.Error) }
    }

    return (Invoke-WinstPostInstallCopy -Plan $Plan -InstallDir $InstallDir)
}
