#Requires -Version 5.1

function Expand-WinstArchiveLayout {
    <#
    .SYNOPSIS
        在目标同盘的临时目录完整解压并整理布局，不修改目标目录。
    .DESCRIPTION
        extractFiles 优先于 stripTopDir；目录取内容，文件取自身。
        stripTopDir 指定内层压缩包时先展开内层；其余目录选择只切换路径。
        成功后调用方从 SourceDir 直接交付，并负责清理 TempRoot；失败时自行清理。
    .PARAMETER DestDir
        最终交付目录，用于选择同盘临时位置；本函数不向该目录写入。
    .OUTPUTS
        @{ Ok; Error; TempRoot; SourceDir; ExtractFailed }
    #>
    param(
        [hashtable]$Context,
        [Parameter(Mandatory = $true)][string]$ArchivePath,
        [Parameter(Mandatory = $true)][string]$DestDir,
        $StripTopDir = $true,
        [string[]]$ExtractFiles = @()
    )

    $result = @{ Ok = $false; Error = ''; TempRoot = ''; SourceDir = ''; ExtractFailed = $false }
    $tempRoot = ''
    try {
        $target = [IO.Path]::GetFullPath($DestDir).TrimEnd('\', '/')
        Assert-WinstSafeWritePath -Path $target -Directory
        $parent = [IO.Path]::GetDirectoryName($target)
        Assert-WinstSafeWritePath -Path $parent
        $tempRoot = Join-WinstPath $parent ('.winst-stage-' + [Guid]::NewGuid().ToString('N'))
        Assert-WinstSafeWritePath -Path $tempRoot -Directory
        $null = New-Item -ItemType Directory -Path $tempRoot -ErrorAction Stop
        $expand = Expand-WinstPackageArchive -Context $Context -ArchivePath $ArchivePath -DestDir $tempRoot
        if (-not $expand.Ok) { $result.ExtractFailed = $true; $result.Error = $expand.Error; return $result }
        Assert-WinstTreeWithoutReparsePoint -Path $tempRoot

        $selected = New-Object 'System.Collections.Generic.List[string]'
        foreach ($one in @($ExtractFiles)) {
            $text = ([string]$one).Trim()
            if (-not $text) { continue }
            $safe = Resolve-WinstSafeChildPath -Root $tempRoot -Child $text -Label '软件源里的解压路径'
            if (-not $safe.Ok) { $result.Error = $safe.Error; return $result }
            if (-not (Test-Path -LiteralPath $safe.Path)) { throw ('压缩包缺少所需路径：' + $text) }
            if (-not $selected.Contains([string]$safe.Path)) { $selected.Add([string]$safe.Path) }
        }
        if ($selected.Count -eq 0) {
            $source = $tempRoot
            if ($StripTopDir -is [string]) {
                $safe = Resolve-WinstSafeChildPath -Root $tempRoot -Child $StripTopDir -Label '软件源里的解压路径'
                if (-not $safe.Ok) { $result.Error = $safe.Error; return $result }
                $source = [string]$safe.Path
                if (-not (Test-Path -LiteralPath $source)) { throw ('压缩包里没有所需路径：' + $StripTopDir) }
                if ((Test-Path -LiteralPath $source -PathType Leaf) -and (Test-WinstArchiveFileByExtension -Path $source)) {
                    $inner = Join-WinstPath $tempRoot ('.winst-inner-' + [Guid]::NewGuid().ToString('N'))
                    $expand = Expand-WinstPackageArchive -Context $Context -ArchivePath $source -DestDir $inner
                    if (-not $expand.Ok) { $result.Error = $expand.Error; return $result }
                    Assert-WinstTreeWithoutReparsePoint -Path $inner
                    $source = $inner
                }
            } elseif ($StripTopDir -eq $true) {
                $top = @(Get-ChildItem -LiteralPath $tempRoot -Force -ErrorAction Stop)
                if ($top.Count -eq 1 -and $top[0].PSIsContainer) { $source = $top[0].FullName }
            }
            $selected.Add($source)
        }

        if ($selected.Count -eq 1 -and (Test-Path -LiteralPath $selected[0] -PathType Container)) {
            $sourceDir = $selected[0]
        } else {
            $fileParent = [IO.Path]::GetDirectoryName($selected[0])
            $sameParentFiles = $true
            foreach ($path in $selected) {
                if (-not (Test-Path -LiteralPath $path -PathType Leaf) -or [IO.Path]::GetDirectoryName($path) -ine $fileParent) {
                    $sameParentFiles = $false
                    break
                }
            }
            if ($sameParentFiles) {
                $sourceDir = $fileParent
                foreach ($item in @(Get-ChildItem -LiteralPath $sourceDir -Force -ErrorAction Stop)) {
                    if (@($selected) -contains $item.FullName) { continue }
                    if ($item.PSIsContainer) { Clear-WinstInstallDir -Dir $item.FullName -Strict }
                    else { Remove-Item -LiteralPath $item.FullName -Force -ErrorAction Stop }
                }
            } else {
                # 多个目录取内容时必须合并布局；只在本次临时树内移动，不复制整树。
                $sourceDir = Join-WinstPath $tempRoot ('.winst-layout-' + [Guid]::NewGuid().ToString('N'))
                $null = New-Item -ItemType Directory -Path $sourceDir -ErrorAction Stop
                foreach ($path in $selected) {
                    if ($path -ieq $tempRoot) { throw '解压选择不能同时包含整个临时目录和其中的条目' }
                    $moved = Move-WinstArchiveSelection -Path $path -DestDir $sourceDir
                    if (-not $moved.Ok) { $result.Error = $moved.Error; return $result }
                }
            }
        }
        Assert-WinstTreeWithoutReparsePoint -Path $sourceDir
        if (-not (Get-ChildItem -LiteralPath $sourceDir -File -Recurse -Force -ErrorAction Stop | Select-Object -First 1)) {
            throw '解压结果没有文件，拒绝清理安装目录'
        }
        $result.TempRoot = $tempRoot
        $result.SourceDir = $sourceDir
        $result.Ok = $true
        return $result
    } catch {
        $result.Error = ('解压失败：' + $_.Exception.Message)
        return $result
    } finally {
        if (-not $result.Ok -and $tempRoot -and (Test-Path -LiteralPath $tempRoot)) {
            Clear-WinstInstallDir -Dir $tempRoot -AllowedRoot $parent
        }
    }
}
