#Requires -Version 5.1

function Move-WinstStagedInstall {
    <#
    .SYNOPSIS
        完整暂存后落位；clean 模式备份旧树，验证新文件成功后删除备份，失败恢复。
    .OUTPUTS
        @{ Ok; Error }
    #>
    param([string]$StageDir, [string]$InstallDir, [string]$SourceDir = '', [switch]$Clean, [string[]]$Keep = @())

    $backup = ''
    $switching = $false
    try {
        $target = [IO.Path]::GetFullPath($InstallDir).TrimEnd('\', '/')
        $stage = [IO.Path]::GetFullPath($StageDir).TrimEnd('\', '/')
        Assert-WinstSafeWritePath -Path $target -Directory
        Assert-WinstSafeWritePath -Path $stage -Directory
        if ($stage -ieq $target -or [IO.Path]::GetDirectoryName($stage) -ine [IO.Path]::GetDirectoryName($target)) {
            throw '解压暂存目录必须与安装目录同级且互不重叠'
        }
        if (-not $SourceDir) { $SourceDir = $stage }
        $source = [IO.Path]::GetFullPath($SourceDir).TrimEnd('\', '/')
        if ($source -ine $stage -and -not (Test-WinstPathUnderRoot -Path $source -Root $stage)) {
            throw '安装内容必须位于本次解压暂存目录内'
        }
        Assert-WinstTreeWithoutReparsePoint -Path $source
        $sourceItem = Get-Item -LiteralPath $source -Force -ErrorAction Stop
        $files = @($sourceItem)
        if ($sourceItem.PSIsContainer) {
            $files = @(Get-ChildItem -LiteralPath $source -File -Recurse -Force -ErrorAction Stop)
        }
        if ($files.Count -eq 0) { throw '解压结果没有文件，拒绝清理安装目录' }
        if ((Test-Path -LiteralPath $target) -and -not (Test-Path -LiteralPath $target -PathType Container)) {
            throw ('安装目标不是目录：' + $target)
        }
        if (-not $Clean) { return (Move-WinstArchiveSelection -Path $source -DestDir $target) }

        $expected = @{}
        foreach ($file in $files) {
            $relative = $file.Name
            if ($sourceItem.PSIsContainer) { $relative = $file.FullName.Substring($source.Length).TrimStart('\', '/') }
            $hash = Get-WinstFileHash -Path $file.FullName
            if (-not $hash) { throw ('无法校验暂存文件：' + $file.FullName) }
            $expected[$relative] = $hash
        }

        if (Test-Path -LiteralPath $target -PathType Container) {
            $backup = $target + '.backup-' + [Guid]::NewGuid().ToString('N')
            Assert-WinstSafeWritePath -Path $backup -Directory
            Move-Item -LiteralPath $target -Destination $backup -ErrorAction Stop
        }
        $switching = $true
        if ($backup -and @($Keep).Count -gt 0) {
            Assert-WinstTreeWithoutReparsePoint -Path $backup
            Copy-Item -LiteralPath $backup -Destination $target -Recurse -Force -ErrorAction Stop
            Clear-WinstInstallDir -Dir $target -Keep $Keep -Strict
        }
        $move = Move-WinstArchiveSelection -Path $source -DestDir $target
        if (-not $move.Ok) { throw $move.Error }
        foreach ($relative in $expected.Keys) {
            $installed = Join-WinstPath $target $relative
            Assert-WinstSafeWritePath -Path $installed
            if ($expected[$relative] -cne (Get-WinstFileHash -Path $installed)) {
                throw ('安装后的文件与暂存内容不一致：' + $installed)
            }
        }
        $switching = $false
        if ($backup) {
            try { Clear-WinstInstallDir -Dir $backup -Strict }
            catch { Write-Warning ('新程序已就位，旧树备份未能完全清理，请手动处理 {0}：{1}' -f $backup, $_.Exception.Message) }
        }
        return @{ Ok = $true; Error = '' }
    } catch {
        $errorText = '安装文件落位失败：' + $_.Exception.Message
        if ($switching) {
            try {
                if (Test-Path -LiteralPath $target) { Clear-WinstInstallDir -Dir $target -Strict }
                if ($backup) {
                    Assert-WinstSafeWritePath -Path $target -Directory
                    Move-Item -LiteralPath $backup -Destination $target -ErrorAction Stop
                }
            } catch {
                $errorText += ('；恢复失败，旧树保留在 {0}，请移开失败目录 {1} 后将备份改回原名：{2}' -f $backup, $target, $_.Exception.Message)
            }
        }
        return @{ Ok = $false; Error = $errorText }
    }
}
