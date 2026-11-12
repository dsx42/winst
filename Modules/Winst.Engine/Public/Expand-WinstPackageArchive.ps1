#Requires -Version 5.1

function Expand-WinstPackageArchive {
    <#
    .SYNOPSIS
        解压压缩包到独立空暂存目录：7z.exe（7-Zip-CLI 引擎）→ 系统 tar.exe → Expand-Archive（仅 zip）。
    .DESCRIPTION
        目标必须是调用方拥有的独立空目录。工具失败后清理本次残留，再尝试下一工具；
        全部失败时返回各工具错误，成功后由调用方负责交付内容并清理暂存目录。指定 SevenZipPath 时只用该程序。
    .OUTPUTS
        @{ Ok; Tool; Error }
    #>
    param(
        [hashtable]$Context,
        [Parameter(Mandatory = $true)][string]$ArchivePath,
        [Parameter(Mandatory = $true)][string]$DestDir,
        [string]$SevenZipPath = ''
    )

    $result = @{ Ok = $false; Tool = ''; Error = '' }
    if (-not (Test-Path -LiteralPath $ArchivePath -PathType Leaf)) {
        $result.Error = ('找不到压缩包：{0}' -f $ArchivePath)
        return $result
    }
    try {
        Assert-WinstSafeWritePath -Path $DestDir -Directory
        if (Test-Path -LiteralPath $DestDir) {
            if (-not (Test-Path -LiteralPath $DestDir -PathType Container)) { throw '解压暂存路径不是目录' }
            if (Get-ChildItem -LiteralPath $DestDir -Force -ErrorAction Stop | Select-Object -First 1) {
                throw '解压暂存目录必须为空，拒绝覆盖已有文件'
            }
        }
    } catch {
        $result.Error = $_.Exception.Message
        return $result
    }

    $errors = New-Object 'System.Collections.Generic.List[string]'
    $expand = Expand-WinstArchiveWithTool -Context $Context -ArchivePath $ArchivePath -DestDir $DestDir -Errors $errors -SevenZipPath $SevenZipPath
    if ($expand.Ok) {
        $result.Ok = $true
        $result.Tool = $expand.Tool
        return $result
    }

    $detail = '没有可用的解压工具'
    if ($errors.Count -gt 0) { $detail = $errors -join '；' }
    $result.Error = ('无法解压 {0}：{1}' -f (Split-Path -Leaf $ArchivePath), $detail)
    return $result
}
