#Requires -Version 5.1

function Expand-WinstEnginePackage {
    <#
    .SYNOPSIS
        在暂存中解开引擎包、复制改名并检查主程序，然后交付到引擎目录。
    .OUTPUTS
        @{ Ok; Error }
    #>
    param([hashtable]$Context, [string]$Id, $Plan, [string]$InstallDir, [string]$ArchivePath, [switch]$Quiet,
        [bool]$Clean = $true, [string[]]$Keep = @())

    $install = Get-EntryValue -Entry $Plan -Key 'install' -Default $null
    $method = Get-EntryString -Entry $install -Key 'method'
    if ($method -ne 'portable') {
        return @{ Ok = $false; Error = ('{0} 的类型不是绿色版（{1}），无法自动安装' -f $Id, $method) }
    }

    try {
        Invoke-WinstFileStep -Name '文件阶段' -Action {
            $stage = ''
            try {
                $target = [IO.Path]::GetFullPath($InstallDir).TrimEnd('\', '/')
                if (-not (Test-WinstPathUnderRoot -Path $target -Root $Context.InstallRoot)) {
                    throw '引擎目录必须位于软件安装根目录之下'
                }
                $stripTopDir = Get-EntryValue -Entry $install -Key 'stripTopDir' -Default $true
                $extractFiles = @(Get-EntryArray -Entry $install -Key 'extractFiles')
                $existing = ''
                $isExtractEngine = ($Id -ceq (Get-WinstExtractEngineId))
                if ($isExtractEngine) { $existing = Get-WinstEngineExe -Context $Context -Id $Id }
                $layout = Expand-WinstArchiveLayout -Context $Context -ArchivePath $ArchivePath -DestDir $target `
                    -StripTopDir $stripTopDir -ExtractFiles $extractFiles -SevenZipPath $existing
                if (-not $layout.Ok -and $isExtractEngine -and -not $existing -and (Get-EntryBool -Entry $layout -Key 'ExtractFailed')) {
                    $directError = [string]$layout.Error
                    $layout = Initialize-WinstSevenZipFromSystem -Context $Context -Plan $Plan -ArchivePath $ArchivePath -InstallDir $target -Quiet:$Quiet
                    if (-not $layout.Ok) { $layout.Error = $directError + '；' + $layout.Error }
                }
                if (-not $layout.Ok) { throw $layout.Error }
                $stage = $layout.TempRoot
                Invoke-WinstFileStep -Name '准备引擎' -Action {
                    Initialize-WinstEngineStage -Id $Id -Plan $Plan -SourceDir $layout.SourceDir
                }
                $delivery = Move-WinstStagedInstall -StageDir $stage -SourceDir $layout.SourceDir -InstallDir $target -Id $Id -Clean:$Clean -Keep $Keep
            } catch {
                $delivery = @{ Ok = $false; Error = $_.Exception.Message }
            }
            if ($stage) { $delivery = Complete-WinstFileStage -StageDir $stage -Delivery $delivery }
            if (-not $delivery.Ok) { throw $delivery.Error }
        }
        return @{ Ok = $true; Error = '' }
    } catch {
        return @{ Ok = $false; Error = ('安装引擎失败：' + $_.Exception.Message) }
    }
}
