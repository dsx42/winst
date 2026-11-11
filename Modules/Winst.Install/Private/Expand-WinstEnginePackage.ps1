#Requires -Version 5.1

function Expand-WinstEnginePackage {
    <#
    .SYNOPSIS
        在暂存目录完成引擎解压、复制与主程序校验，成功后清理旧目录并移入新文件。
    .OUTPUTS
        @{ Ok; Error }
    #>
    param([hashtable]$Context, [string]$Id, $Plan, [string]$InstallDir, [string]$ArchivePath, [switch]$Quiet)

    $install = Get-EntryValue -Entry $Plan -Key 'install' -Default $null
    $method = Get-EntryString -Entry $install -Key 'method'
    if ($method -ne 'portable') {
        return @{ Ok = $false; Error = ('{0} 的类型不是绿色版（{1}），无法自动安装' -f $Id, $method) }
    }

    $stage = ''
    $parent = ''
    try {
        $InstallDir = [IO.Path]::GetFullPath($InstallDir).TrimEnd('\', '/')
        Assert-WinstSafeWritePath -Path $InstallDir -Directory
        if (-not (Test-WinstPathUnderRoot -Path $InstallDir -Root $Context.InstallRoot)) {
            throw '引擎目录必须位于软件安装根目录之下'
        }
        $parent = Split-Path -Parent $InstallDir

        $stripTopDir = Get-EntryValue -Entry $install -Key 'stripTopDir' -Default $true
        $extractFiles = @(Get-EntryArray -Entry $install -Key 'extractFiles')

        $layout = Expand-WinstArchiveLayout -Context $Context -ArchivePath $ArchivePath -DestDir $InstallDir `
            -StripTopDir $stripTopDir -ExtractFiles $extractFiles
        if (-not $layout.Ok -and (Get-EntryBool -Entry $layout -Key 'ExtractFailed') -and $Id -ceq (Get-WinstExtractEngineId)) {
            $directError = [string]$layout.Error
            $layout = Initialize-WinstSevenZipFromSystem -Context $Context -Plan $Plan -ArchivePath $ArchivePath -InstallDir $InstallDir -Quiet:$Quiet
            if (-not $layout.Ok) { $layout.Error = $directError + '；' + $layout.Error }
        }
        if (-not $layout.Ok) {
            return @{ Ok = $false; Error = ('解压 {0} 失败：{1}' -f (Split-Path -Leaf $ArchivePath), $layout.Error) }
        }

        $stage = [string]$layout.TempRoot
        $sourceDir = [string]$layout.SourceDir
        Initialize-WinstEngineStage -Id $Id -Plan $Plan -SourceDir $sourceDir
        return (Move-WinstStagedInstall -StageDir $stage -SourceDir $sourceDir -InstallDir $InstallDir -Clean)
    } catch {
        return @{ Ok = $false; Error = ('安装引擎失败：{0}' -f $_.Exception.Message) }
    } finally {
        if ($stage -and (Test-Path -LiteralPath $stage)) {
            Clear-WinstInstallDir -Dir $stage -AllowedRoot $parent
        }
    }
}
