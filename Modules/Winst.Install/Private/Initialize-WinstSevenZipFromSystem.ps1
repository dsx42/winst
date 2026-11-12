#Requires -Version 5.1

function Initialize-WinstSevenZipFromSystem {
    <#
    .SYNOPSIS
        用系统 7-Zip 解压引导包；没有可用安装时静默运行已下载的安装器，完成后再解压。
    .OUTPUTS
        @{ Ok; Error; TempRoot; SourceDir }；成功后由调用方交付并清理临时目录。
    #>
    param([hashtable]$Context, $Plan, [string]$ArchivePath, [string]$InstallDir, [switch]$Quiet)

    $result = @{ Ok = $false; Error = ''; TempRoot = ''; SourceDir = '' }
    try {
        $target = [IO.Path]::GetFullPath($InstallDir).TrimEnd('\', '/')
        Assert-WinstSafeWritePath -Path $target -Directory
        if (-not (Test-WinstPathUnderRoot -Path $target -Root $Context.InstallRoot)) { throw '引擎目录必须位于软件安装根目录之下' }
        $found = Find-WinstSystemSevenZip
        if (-not $found.Ok) { throw $found.Error }
        if (-not $found.Dir) {
            if ([IO.Path]::GetExtension($ArchivePath) -ine '.exe' -or -not (Test-Path -LiteralPath $ArchivePath -PathType Leaf)) {
                throw '没有可用的系统 7-Zip，且引导包不是可运行的 EXE 安装包'
            }
            Assert-WinstSafeWritePath -Path $ArchivePath
            if (-not (Test-WinstArgumentSafe -Value $ArchivePath)) { throw '7-Zip 安装包路径含有不安全的命令行字符' }
            if (-not $Quiet) { Write-Host '    正在静默安装系统 7-Zip …' -ForegroundColor Gray }
            $process = $null
            try {
                $process = Start-Process -FilePath $ArchivePath -ArgumentList (Format-WinstCommandArgument -Value '/S') -WindowStyle Hidden -PassThru -ErrorAction Stop
                if ($null -eq $process) { throw '没有取得 7-Zip 安装器进程，无法确认安装结果' }
                # 等待前保留句柄，确保 Windows PowerShell 5.1 能读取已退出进程的退出码。
                $null = $process.Handle
                $process.WaitForExit()
                $exitCode = $process.ExitCode
                if ($null -eq $exitCode) { throw '读不到 7-Zip 安装器退出码，无法确认安装结果' }
                if ($exitCode -ne 0) { throw ('系统 7-Zip 静默安装失败（退出码 {0}）' -f $exitCode) }
            } finally {
                if ($null -ne $process) { $process.Dispose() }
                Reset-WinstSystemCache
            }
            $found = Find-WinstSystemSevenZip
            if (-not $found.Ok) { throw $found.Error }
            if (-not $found.Dir) { throw '静默安装器已结束，但没有找到包含 7z.exe / 7z.dll 的系统 7-Zip，请检查安装结果' }
        }

        if ((Test-WinstPathUnderRoot -Path $found.Dir -Root $target -AllowEqual) -or
                (Test-WinstPathUnderRoot -Path $target -Root $found.Dir -AllowEqual)) {
            throw '系统 7-Zip 目录与引擎目录重叠，拒绝清理系统安装'
        }
        if (-not $Quiet) { Write-Host ('    正在借助系统 7-Zip 解压引导包：{0}' -f $found.Dir) -ForegroundColor Gray }
        $install = Get-EntryValue -Entry $Plan -Key 'install' -Default $null
        return (Expand-WinstArchiveLayout -Context $Context -ArchivePath $ArchivePath -DestDir $target `
            -StripTopDir (Get-EntryValue -Entry $install -Key 'stripTopDir' -Default $true) `
            -ExtractFiles @(Get-EntryArray -Entry $install -Key 'extractFiles') `
            -SevenZipPath (Join-WinstPath $found.Dir '7z.exe'))
    } catch {
        $result.Error = ('借助系统 7-Zip 解压引擎包失败：' + $_.Exception.Message)
        return $result
    }
}
