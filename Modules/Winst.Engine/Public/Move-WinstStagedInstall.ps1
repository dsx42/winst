#Requires -Version 5.1

function Move-WinstStagedInstall {
    <#
    .SYNOPSIS
        完整暂存后复制落位；clean 模式先按 keep 原地清理，不备份、不回滚、不计算文件摘要。
    .OUTPUTS
        @{ Ok; Error }
    #>
    param([string]$StageDir, [string]$InstallDir, [string]$SourceDir = '', [switch]$Clean, [string[]]$Keep = @())

    try {
        $target = (ConvertTo-WinstPlainDevicePath -Path (ConvertTo-WinstExtendedPath -Path $InstallDir)).TrimEnd('\', '/')
        $stage = (ConvertTo-WinstPlainDevicePath -Path (ConvertTo-WinstExtendedPath -Path $StageDir)).TrimEnd('\', '/')
        Assert-WinstSafeWritePath -Path $target -Directory
        Assert-WinstSafeWritePath -Path $stage -Directory
        if ($stage -ieq $target -or (Test-WinstPathUnderRoot -Path $stage -Root $target) -or
                (Test-WinstPathUnderRoot -Path $target -Root $stage)) {
            throw '解压暂存目录与安装目录必须互不重叠'
        }
        if (-not $SourceDir) { $SourceDir = $stage }
        $source = (ConvertTo-WinstPlainDevicePath -Path (ConvertTo-WinstExtendedPath -Path $SourceDir)).TrimEnd('\', '/')
        if ($source -ine $stage -and -not (Test-WinstPathUnderRoot -Path $source -Root $stage)) {
            throw '安装内容必须位于本次解压暂存目录内'
        }
        Assert-WinstTreeWithoutReparsePoint -Path $source -RequireFile
        return (Move-WinstArchiveSelection -Path $source -DestDir $target -Copy -Clean:$Clean -Keep $Keep)
    } catch {
        return @{ Ok = $false; Error = ('安装文件落位失败：' + $_.Exception.Message) }
    }
}
