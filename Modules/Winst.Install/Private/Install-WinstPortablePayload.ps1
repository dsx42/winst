#Requires -Version 5.1

function Install-WinstPortablePayload {
    <#
    .SYNOPSIS
        ② portable：按 portableMode 清理 / 覆盖安装目录，再按 stripTopDir / extractFiles 解压。
    .OUTPUTS
        @{ Ok; Error }
    #>
    param([hashtable]$Context, $Install, [string]$InstallDir, [string]$PrimaryPath,
        [switch]$Overwrite, [string[]]$Keep = @(), [switch]$Quiet)

    try { Assert-WinstSafeWritePath -Path $InstallDir -Directory }
    catch { return @{ Ok = $false; Error = $_.Exception.Message } }

    $engine = Confirm-WinstExtractEngine -Context $Context -Quiet:$Quiet
    if (-not $engine.Ok -and -not $Quiet) {
        Write-Host ('    解压引擎不可用（{0}），改用系统自带解压方式' -f $engine.Error) -ForegroundColor DarkYellow
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

    if ($portableMode -eq 'clean') {
        Clear-WinstInstallDir -Dir $InstallDir -Keep $keepList
    }
    if (-not (Test-Path -LiteralPath $InstallDir -PathType Container)) {
        $null = New-Item -ItemType Directory -Path $InstallDir -Force -ErrorAction SilentlyContinue
    }

    $stripTopDir = Get-EntryValue -Entry $Install -Key 'stripTopDir' -Default $true
    $extractFiles = @(Get-EntryArray -Entry $Install -Key 'extractFiles')
    $layout = Expand-WinstArchiveLayout -Context $Context -ArchivePath $PrimaryPath -DestDir $InstallDir -StripTopDir $stripTopDir -ExtractFiles $extractFiles
    if (-not $layout.Ok) {
        return @{ Ok = $false; Error = ('解压 {0} 失败：{1}' -f (Split-Path -Leaf $PrimaryPath), $layout.Error) }
    }
    return @{ Ok = $true; Error = '' }
}
