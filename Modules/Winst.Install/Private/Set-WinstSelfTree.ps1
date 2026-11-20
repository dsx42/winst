#Requires -Version 5.1

function Set-WinstSelfTree {
    <#
    .SYNOPSIS
        从 release 压缩包、已解压目录或当前运行树准备暂存，保留清单并替换 winst 安装目录。
    .OUTPUTS
        @{ Ok; Error }
    #>
    [CmdletBinding()]
    [OutputType([hashtable])]
    param(
        [Parameter(Mandatory = $true)][string]$InstallDir,
        [string]$ArchivePath = '',
        [string]$SourceDir = '',
        [string]$FallbackSourcePath = ''
    )

    try {
        Invoke-WinstFileStep -Name '文件阶段' -Action {
            $stage = ''
            try {
                if ($ArchivePath) {
                    $layout = Expand-WinstArchiveLayout -ArchivePath $ArchivePath -DestDir $InstallDir -StripTopDir $false
                    if (-not $layout.Ok) { throw $layout.Error }
                    $stage = $layout.TempRoot
                } else {
                    $inputDir = $SourceDir
                    if (-not $inputDir) {
                        if (-not $FallbackSourcePath) { throw '没有可用的 winst 安装包' }
                        $inputDir = Split-Path -Parent $FallbackSourcePath
                    }
                    $stage = Initialize-WinstArchiveStage -DestDir $InstallDir -InputPath $inputDir
                    Invoke-WinstFileStep -Name '准备暂存' -Action {
                        $stageIo = ConvertTo-WinstExtendedPath $stage
                        if ($SourceDir) {
                            Assert-WinstSafeWritePath -Path $SourceDir
                            $sourcePattern = [Management.Automation.WildcardPattern]::Escape((ConvertTo-WinstExtendedPath $SourceDir)) + '\*'
                            Copy-Item -Path $sourcePattern -Destination $stageIo -Recurse -Force -ErrorAction Stop
                        } else {
                            foreach ($required in @('winst.ps1', 'winst.cmd', 'LICENSE', 'Modules')) {
                                $item = Join-WinstPath $inputDir $required
                                Assert-WinstSafeWritePath -Path $item
                                Copy-Item -LiteralPath (ConvertTo-WinstExtendedPath $item) -Destination $stageIo -Recurse -Force -ErrorAction Stop
                            }
                        }
                    }
                }
                Invoke-WinstFileStep -Name '检查 winst 运行树' -Action { Assert-WinstSelfPackage -StageDir $stage }
                $delivery = Move-WinstStagedInstall -StageDir $stage -InstallDir $InstallDir -Id 'winst' -Clean -Keep @('lists/', '*.list')
            } catch {
                $delivery = @{ Ok = $false; Error = $_.Exception.Message }
            }
            if ($stage) { $delivery = Complete-WinstFileStage -StageDir $stage -Delivery $delivery }
            if (-not $delivery.Ok) { throw $delivery.Error }
        }
        return @{ Ok = $true; Error = '' }
    } catch {
        return @{ Ok = $false; Error = ('安装 winst 失败：' + $_.Exception.Message) }
    }
}
