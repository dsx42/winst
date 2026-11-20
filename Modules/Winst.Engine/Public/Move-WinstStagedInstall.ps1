#Requires -Version 5.1

function Move-WinstStagedInstall {
    <#
    .SYNOPSIS
        合并保留项后批量删旧和复制；有恢复标记时由调用方保留暂存。
    .OUTPUTS
        @{ Ok; Error; PreserveStage }
    #>
    param([string]$StageDir, [string]$InstallDir, [string]$SourceDir = '', [switch]$Clean, [string[]]$Keep = @(), [string]$Id = '')

    $marked = $false
    $pushedLocation = $false
    try {
        $target = (ConvertTo-WinstPlainDevicePath -Path (ConvertTo-WinstExtendedPath -Path $InstallDir)).TrimEnd('\', '/')
        $stage = (ConvertTo-WinstPlainDevicePath -Path (ConvertTo-WinstExtendedPath -Path $StageDir)).TrimEnd('\', '/')
        if (-not $SourceDir) { $SourceDir = $stage }
        $sourceIo = ConvertTo-WinstExtendedPath -Path $SourceDir
        $source = (ConvertTo-WinstPlainDevicePath -Path $sourceIo).TrimEnd('\', '/')
        $targetIo = ConvertTo-WinstExtendedPath -Path $target
        Assert-WinstSafeWritePath -Path $target -Directory
        if ((Test-WinstPathUnderRoot -Path $stage -Root $target -AllowEqual) -or
                (Test-WinstPathUnderRoot -Path $target -Root $stage)) {
            throw '解压暂存目录与安装目录必须互不重叠'
        }
        if (-not (Test-WinstPathUnderRoot -Path $source -Root $stage -AllowEqual)) {
            throw '安装内容必须位于本次解压暂存目录内'
        }
        $existing = Get-WinstFileSystemItem -Path $target -AllowMissing
        if ($existing -and -not $existing.PSIsContainer) { throw ('安装目标不是目录：' + $target) }

        Assert-WinstSafeWritePath -Path $source
        if (-not (Test-WinstFileSystemPath -Path $source -PathType Container)) { throw ('交付目录不存在：' + $source) }
        $preserveRoot = $false
        if ($Clean -and $existing) {
            $workingDirs = @([Environment]::CurrentDirectory)
            if ($PWD.Provider.Name -eq 'FileSystem') { $workingDirs += $PWD.ProviderPath }
            foreach ($workingDir in $workingDirs) {
                if (Test-WinstPathUnderRoot -Path $workingDir -Root $target) {
                    throw ('工作目录位于安装目录的子目录中：{0}。请切换到安装目录 {1} 或其外部后重试。' -f $workingDir, $target)
                }
                if (Test-WinstPathUnderRoot -Path $workingDir -Root $target -AllowEqual) { $preserveRoot = $true }
            }
        }

        # 非文件系统位置下，PowerShell 会将扩展路径的通配符交给当前提供程序。
        if ($PWD.Provider.Name -ne 'FileSystem') {
            Push-Location -LiteralPath ('FileSystem::' + $stage) -ErrorAction Stop
            $pushedLocation = $true
        }
        $kept = $false
        if ($Clean -and $existing -and $Keep.Count) {
            $kept = Invoke-WinstFileStep -Name '整理保留项' -Action {
                Copy-WinstKeptItems -InstallDir $target -SourceDir $source -Keep $Keep
            }
            if (-not $kept) { Write-Host '    未命中保留规则' }
        } else {
            $reason = '没有保留规则'
            if (-not $Clean) { $reason = '覆盖模式' }
            elseif (-not $existing) { $reason = '首次安装' }
            Invoke-WinstFileStep -Name '整理保留项' -Skip $reason
        }
        if ($kept) {
            $marker = Join-WinstPath ([IO.Path]::GetDirectoryName($stage)) '.winst-stage.recovery.json'
            $record = @{ id = $Id; sourceDir = $source; installDir = $target }
            Invoke-WinstFileStep -Name '写恢复标记' -Action {
                Write-FileAtomic -Path $marker -Content ($record | ConvertTo-Json -Compress)
            }
            $marked = $true
        }
        if (-not $existing) {
            Invoke-WinstFileStep -Name '删旧' -Skip '首次安装'
        } elseif (-not $Clean) {
            Invoke-WinstFileStep -Name '删旧' -Skip '覆盖模式'
        } elseif ($preserveRoot) {
            Invoke-WinstFileStep -Name '删旧' -Action {
                Assert-WinstSafeWritePath -Path $target -Directory
                $targetContents = [Management.Automation.WildcardPattern]::Escape($targetIo) + '\*'
                Remove-Item -Path $targetContents -Recurse -Force -ErrorAction Stop
            }
        } else {
            Invoke-WinstFileStep -Name '删旧' -Action { Remove-WinstDirectoryTree -Path $target }
        }
        Invoke-WinstFileStep -Name '复制' -Action {
            if (($existing -and -not $Clean) -or $preserveRoot) {
                $contents = [Management.Automation.WildcardPattern]::Escape($sourceIo) + '\*'
                Copy-Item -Path $contents -Destination $targetIo -Recurse -Force -ErrorAction Stop
            } else {
                Assert-WinstSafeWritePath -Path $target -Directory
                Copy-Item -LiteralPath $sourceIo -Destination $targetIo -Recurse -Force -ErrorAction Stop
            }
        }
        if ($marked) {
            try {
                Invoke-WinstFileStep -Name '撤销恢复标记' -Action {
                    Remove-Item -LiteralPath (ConvertTo-WinstExtendedPath -Path $marker) -Force -ErrorAction Stop
                }
            }
            catch { throw ('文件已落位，撤销恢复标记失败：' + $_.Exception.Message) }
            $marked = $false
        }
        return @{ Ok = $true; Error = ''; PreserveStage = $false }
    } catch {
        $message = $_.Exception.Message
        if ($marked) { $message += ('；保留内容位于 {0}，恢复标记：{1}' -f $source, $marker) }
        return @{ Ok = $false; Error = $message; PreserveStage = $marked }
    } finally {
        if ($pushedLocation) { Pop-Location }
    }
}
