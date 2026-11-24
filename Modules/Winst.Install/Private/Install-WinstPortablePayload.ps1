#Requires -Version 5.1

function Install-WinstPortablePayload {
    <#
    .SYNOPSIS
        ② portable：确认引擎可用，完整解压成功后再按 portableMode / keep 清理旧目录并复制新文件。
    .OUTPUTS
        @{ Ok; Error; PostInstallCopyApplied }
    #>
    param([hashtable]$Context, $Install, [string]$InstallDir, [string]$PrimaryPath,
        [switch]$Overwrite, [string[]]$Keep, [switch]$Quiet, $Plan)

    try { Assert-WinstSafeWritePath -Path $InstallDir -Directory }
    catch { return @{ Ok = $false; Error = $_.Exception.Message } }

    $id = Get-EntryString -Entry $Plan -Key 'id'
    if ($id -cne (Get-WinstExtractEngineId)) {
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

    $clean = $portableMode -eq 'clean'
    if (Get-WinstEngineMainExe -Id $id) {
        $delivery = Expand-WinstEnginePackage -Context $Context -Id $id -Plan $Plan -InstallDir $InstallDir `
            -ArchivePath $PrimaryPath -Clean:$clean -Keep $keepList -Quiet:$Quiet
        $delivery['PostInstallCopyApplied'] = $delivery.Ok
        return $delivery
    }

    try {
        Invoke-WinstFileStep -Name '文件阶段' -Action {
            $target = [IO.Path]::GetFullPath($InstallDir).TrimEnd('\', '/')
            if (-not (Test-WinstPathUnderRoot -Path $target -Root $Context.InstallRoot)) {
                throw '绿色软件安装目录必须位于安装根目录之下'
            }

            $stripTopDir = Get-EntryValue -Entry $Install -Key 'stripTopDir' -Default $true
            $extractFiles = @(Get-EntryArray -Entry $Install -Key 'extractFiles')
            $layout = Expand-WinstArchiveLayout -Context $Context -ArchivePath $PrimaryPath -DestDir $target `
                -StripTopDir $stripTopDir -ExtractFiles $extractFiles
            if (-not $layout.Ok) { throw $layout.Error }

            $delivery = Move-WinstStagedInstall -StageDir $layout.TempRoot -SourceDir $layout.SourceDir `
                -InstallDir $target -Clean:$clean -Keep $keepList -Id $id
            $delivery = Complete-WinstFileStage -StageDir $layout.TempRoot -Delivery $delivery
            if (-not $delivery.Ok) { throw $delivery.Error }
        }
        return @{ Ok = $true; Error = ''; PostInstallCopyApplied = $false }
    } catch {
        return @{ Ok = $false; Error = $_.Exception.Message }
    }
}
