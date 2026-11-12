#Requires -Version 5.1

function Install-WinstPortablePayload {
    <#
    .SYNOPSIS
        ② portable：确认引擎可用，完整解压成功后再按 portableMode / keep 清理旧目录并复制新文件。
    .OUTPUTS
        @{ Ok; Error; PostInstallCopyApplied }
    #>
    param([hashtable]$Context, $Install, [string]$InstallDir, [string]$PrimaryPath,
        [switch]$Overwrite, [string[]]$Keep = @(), [switch]$Quiet, $Plan = $null)

    try { Assert-WinstSafeWritePath -Path $InstallDir -Directory }
    catch { return @{ Ok = $false; Error = $_.Exception.Message } }

    $isExtractEngine = ((Get-EntryString -Entry $Plan -Key 'id') -ceq (Get-WinstExtractEngineId))
    if (-not $isExtractEngine) {
        $engine = Confirm-WinstExtractEngine -Context $Context -Quiet:$Quiet
        if (-not $engine.Ok) {
            return @{ Ok = $false; Error = ('解压引擎不可用：{0}' -f $engine.Error) }
        }
    }

    $portableMode = Get-EntryString -Entry $Install -Key 'portableMode'
    if ($Overwrite) { $portableMode = 'overwrite' }
    if ($portableMode -ne 'overwrite') { $portableMode = 'clean' }

    $keepList = @(Get-EntryArray -Entry $Install -Key 'keep')
    if (@($Keep).Count -gt 0) {
        if ($portableMode -eq 'overwrite') {
            if (-not $Quiet) { Write-Host '    提示: 覆盖模式下 --keep 不生效（保留规则只在清理模式使用）' -ForegroundColor DarkYellow }
        } else {
            $keepList = @($Keep)
        }
    }

    $stage = ''
    $tempPath = [IO.Path]::GetTempPath()
    try {
        $target = [IO.Path]::GetFullPath($InstallDir).TrimEnd('\', '/')
        if (-not (Test-WinstPathUnderRoot -Path $target -Root $Context.InstallRoot)) {
            throw '绿色软件安装目录必须位于安装根目录之下'
        }

        $stripTopDir = Get-EntryValue -Entry $Install -Key 'stripTopDir' -Default $true
        $extractFiles = @(Get-EntryArray -Entry $Install -Key 'extractFiles')
        $existing = ''
        if ($isExtractEngine) { $existing = Get-WinstEngineExe -Context $Context -Id (Get-WinstExtractEngineId) }
        $layout = Expand-WinstArchiveLayout -Context $Context -ArchivePath $PrimaryPath -DestDir $target -StripTopDir $stripTopDir -ExtractFiles $extractFiles -SevenZipPath $existing
        if (-not $layout.Ok -and $isExtractEngine -and -not $existing -and (Get-EntryBool -Entry $layout -Key 'ExtractFailed')) {
            $directError = [string]$layout.Error
            $layout = Initialize-WinstSevenZipFromSystem -Context $Context -Plan $Plan -ArchivePath $PrimaryPath -InstallDir $target -Quiet:$Quiet
            if (-not $layout.Ok) { $layout.Error = $directError + '；' + $layout.Error }
        }
        if (-not $layout.Ok) {
            return @{ Ok = $false; Error = ('解压 {0} 失败：{1}' -f (Split-Path -Leaf $PrimaryPath), $layout.Error) }
        }
        $stage = [string]$layout.TempRoot
        $id = Get-EntryString -Entry $Plan -Key 'id'
        $isEngine = [bool](Get-WinstEngineMainExe -Id $id)
        if ($isEngine) { Initialize-WinstEngineStage -Id $id -Plan $Plan -SourceDir ([string]$layout.SourceDir) }
        $move = Move-WinstStagedInstall -StageDir $stage -SourceDir ([string]$layout.SourceDir) -InstallDir $target -Clean:($portableMode -eq 'clean') -Keep $keepList
        $move['PostInstallCopyApplied'] = $isEngine
        return $move
    } catch {
        return @{ Ok = $false; Error = ('准备安装目录失败：' + $_.Exception.Message) }
    } finally {
        if ($stage -and (Test-WinstPathUnderRoot -Path $stage -Root $tempPath) -and (Test-Path -LiteralPath $stage -PathType Container)) {
            Clear-WinstInstallDir -Dir $stage -AllowedRoot $tempPath
        }
    }
}
