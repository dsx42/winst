#Requires -Version 5.1

function Expand-WinstArchiveLayout {
    <#
    .SYNOPSIS
        解开外层包和清单指定的内层包，再按 extractFiles 或 stripTopDir 选出交付目录。
    .OUTPUTS
        @{ Ok; Error; TempRoot; SourceDir; ExtractFailed }。成功后由调用方负责清理 TempRoot。
    #>
    param(
        [hashtable]$Context,
        [Parameter(Mandatory = $true)][string]$ArchivePath,
        [Parameter(Mandatory = $true)][string]$DestDir,
        $StripTopDir,
        [string[]]$ExtractFiles = @(),
        [string]$SevenZipPath = ''
    )

    $result = @{ Ok = $false; Error = ''; TempRoot = ''; SourceDir = ''; ExtractFailed = $false }
    $paths = @($ExtractFiles | Where-Object { -not [string]::IsNullOrWhiteSpace($_) })
    $phase = '解压'
    try {
        Invoke-WinstFileStep -Name $phase -Action {
            $result.TempRoot = Initialize-WinstArchiveStage -DestDir $DestDir -InputPath $ArchivePath
            Invoke-WinstFileStep -Name '解开外层包' -Action {
                $expand = Expand-WinstPackageArchive -Context $Context -ArchivePath $ArchivePath -DestDir $result.TempRoot -SevenZipPath $SevenZipPath
                if (-not $expand.Ok) { $result.ExtractFailed = -not $expand.ValidationFailed; throw $expand.Error }
            }
            if ($paths.Count -eq 0 -and $StripTopDir -is [string]) {
                $safe = Resolve-WinstSafeChildPath -Root $result.TempRoot -Child $StripTopDir -Label '软件源里的解压路径'
                if ($safe.Ok -and (Test-WinstFileSystemPath -Path $safe.Path -PathType Leaf) -and
                    (Test-WinstArchiveFileByExtension -Path $safe.Path)) {
                    Invoke-WinstFileStep -Name '解开内层包' -Action {
                        Assert-WinstSafeWritePath -Path $safe.Path
                        $inner = Join-WinstPath $result.TempRoot '.winst-inner'
                        if (Test-WinstFileSystemPath -Path $inner) {
                            throw '压缩包包含内层解压保留名称 .winst-inner，无法创建工作目录'
                        }
                        $expand = Expand-WinstPackageArchive -Context $Context -ArchivePath $safe.Path -DestDir $inner -SevenZipPath $SevenZipPath
                        if (-not $expand.Ok) { throw $expand.Error }
                        $result.SourceDir = $inner
                    }
                }
            }
        }
        $phase = '整理'
        $result.SourceDir = Invoke-WinstFileStep -Name $phase -Action {
            if ($result.SourceDir) { return $result.SourceDir }
            Resolve-WinstArchiveLayout -TempRoot $result.TempRoot -StripTopDir $StripTopDir -ExtractFiles $paths
        }
        $result.Ok = $true
    } catch {
        $result.Error = ('{0}失败：{1}' -f $phase, $_.Exception.Message)
        if ($result.TempRoot) {
            try {
                Invoke-WinstFileStep -Name '删暂存' -Action { Remove-WinstDirectoryTree -Path $result.TempRoot }
            } catch {
                $result.Error += ('；暂存清理失败（{0}）：{1}' -f $result.TempRoot, $_.Exception.Message)
                $result.ExtractFailed = $false
            }
        }
    }
    return $result
}
