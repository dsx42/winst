#Requires -Version 5.1

function Remove-WinstOldPackages {
    <#
    .SYNOPSIS
        下载新版本成功后清理该 id 目录下的旧版本包文件。
    .OUTPUTS
        @{ Removed = @(被删除文件名); Failed = @(失败原因); PreviewCount = 预览时的候选数 }
    #>
    param(
        [Parameter(Mandatory = $true)][hashtable]$Context,
        [Parameter(Mandatory = $true)][string]$Id,
        [string[]]$KeepFiles,
        [switch]$Preview
    )

    $removed = New-Object 'System.Collections.Generic.List[string]'
    $failed = @()
    $previewCount = 0
    # 删除入口再兜一层：id 不是单层目录名时（如 clean 传了 .. / 绝对路径）不猜、不越界删
    if (-not (Test-WinstSafePathSegment -Name $Id) -or (Test-WinstReservedPackageId -Id $Id)) { throw ('软件 id 不合法或使用了保留目录名：{0}' -f $Id) }
    $pkgRoot = Get-EntryString -Entry $Context -Key 'PkgDir'
    if (-not $pkgRoot -or $pkgRoot -notmatch '^(?:[A-Za-z]:[\\/]|\\\\[^\\]+\\[^\\]+)') { throw '安装包位置必须为非空绝对路径' }
    $pkgRoot = [IO.Path]::GetFullPath($pkgRoot)
    $dir = Join-WinstPath $pkgRoot $Id
    if (-not (Test-WinstPathUnderRoot -Path $dir -Root $pkgRoot)) { throw ('拒绝清理不安全的安装包目录：' + $dir) }
    Assert-WinstSafeWritePath -Path $dir -Directory
    $directory = Get-WinstFileSystemItem -Path $dir -AllowMissing
    if ($null -eq $directory) { return @{ Removed = @(); Failed = @(); PreviewCount = 0 } }
    if (-not $directory.PSIsContainer) { throw ('安装包路径不是目录：' + $dir) }

    foreach ($file in @(Get-ChildItem -LiteralPath $dir -File -ErrorAction Stop)) {
        if ($KeepFiles -contains $file.Name) { continue }
        if ($Preview) { $previewCount++; continue }
        try {
            if (-not (Test-WinstPathUnderRoot -Path $file.FullName -Root $dir)) { throw '候选文件超出软件包目录' }
            Assert-WinstSafeWritePath -Path $file.FullName
            $file.Refresh()
            if (-not $file.Exists -or ($file.Attributes -band [IO.FileAttributes]'Directory,ReparsePoint,Hidden')) {
                throw '候选文件已消失或属性已改变'
            }
            if ($file.IsReadOnly) { $file.IsReadOnly = $false }
            $file.Delete()
            $removed.Add([string]$file.Name)
        } catch {
            $failed += ('{0}: {1}' -f $file.Name, $_.Exception.Message)
            Write-Warning ('旧包未能清理：{0}（{1}）' -f $file.FullName, $_.Exception.Message)
        }
    }
    return @{ Removed = @($removed.ToArray()); Failed = @($failed); PreviewCount = $previewCount }
}
