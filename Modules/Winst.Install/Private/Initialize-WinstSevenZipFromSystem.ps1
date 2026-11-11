#Requires -Version 5.1

function Initialize-WinstSevenZipFromSystem {
    <#
    .SYNOPSIS
        引导包无法直接解压时，复用目标版本的系统 7-Zip，缺失则静默安装，再复制两个引擎文件。
    .OUTPUTS
        @{ Ok; Error; TempRoot; SourceDir }；成功后由调用方交付并清理临时目录。
    #>
    param([hashtable]$Context, $Plan, [string]$ArchivePath, [string]$InstallDir, [switch]$Quiet)

    $result = @{ Ok = $false; Error = ''; TempRoot = ''; SourceDir = '' }
    $stage = ''
    try {
        $version = Get-NormalizedVersionString -Value (Get-EntryString -Entry $Plan -Key 'version')
        if (-not $version -or $version -ieq 'unknown') { throw '无法确定所需的 7-Zip 版本，不能安装或复制系统引擎' }
        $target = [IO.Path]::GetFullPath($InstallDir).TrimEnd('\', '/')
        Assert-WinstSafeWritePath -Path $target -Directory
        if (-not (Test-WinstPathUnderRoot -Path $target -Root $Context.InstallRoot)) { throw '引擎目录必须位于软件安装根目录之下' }
        $parent = [IO.Path]::GetDirectoryName($target)
        $found = Find-WinstSystemSevenZip -Version $version
        if (-not $found.Ok) { throw $found.Error }
        if (-not $found.Dir) {
            if ([IO.Path]::GetExtension($ArchivePath) -ine '.exe' -or -not (Test-Path -LiteralPath $ArchivePath -PathType Leaf)) {
                throw '没有目标版本的系统 7-Zip，且引导包不是可运行的 EXE 安装包'
            }
            Assert-WinstSafeWritePath -Path $ArchivePath
            if (-not (Test-WinstArgumentSafe -Value $ArchivePath)) { throw '7-Zip 安装包路径含有不安全的命令行字符' }
            $systemDir = [string]$found.InstallDir
            if (-not $systemDir) {
                $programDir = [Environment]::GetEnvironmentVariable('ProgramW6432')
                if (-not $programDir) { $programDir = [Environment]::GetFolderPath('ProgramFiles') }
                if (-not $programDir) { throw '无法确定系统 7-Zip 的安装位置' }
                $systemDir = Join-WinstPath $programDir '7-Zip'
            }
            $systemDir = [IO.Path]::GetFullPath($systemDir).TrimEnd('\', '/')
            Assert-WinstSafeWritePath -Path $systemDir -Directory
            if (-not (Test-WinstArgumentSafe -Value $systemDir)) { throw '系统 7-Zip 安装路径含有不安全的命令行字符' }
            if ((Test-WinstPathUnderRoot -Path $systemDir -Root $target -AllowEqual) -or
                    (Test-WinstPathUnderRoot -Path $target -Root $systemDir -AllowEqual)) {
                throw '系统 7-Zip 安装位置与引擎目录重叠，拒绝运行安装器'
            }
            if (-not (Test-WinstIsAdministrator)) { throw '静默安装系统 7-Zip 需要管理员权限，请以管理员身份重新运行 winst' }
            if (-not $Quiet) { Write-Host ('    引导包无法直接解压，正在静默安装系统 7-Zip {0} …' -f $version) -ForegroundColor Gray }
            try {
                $arguments = @((Format-WinstCommandArgument -Value '/S'), (Format-WinstCommandArgument -Value ('/D=' + $systemDir))) -join ' '
                $run = Invoke-WinstCapturedCommand -FilePath $ArchivePath -Arguments $arguments -NoTimeout
            } finally {
                Reset-WinstSystemCache
            }
            if (-not $run.Ok -or $null -eq $run.ExitCode -or $run.ExitCode -ne 0) {
                throw ('系统 7-Zip 静默安装失败（退出码 {0}）：{1} {2}' -f $run.ExitCode, $run.Error, $run.ErrText)
            }
            $found = Find-WinstSystemSevenZip -Version $version
            if (-not $found.Ok) { throw $found.Error }
            if (-not $found.Dir) {
                throw ('安装器已结束，但没有找到版本为 {0} 的完整 7z.exe / 7z.dll；文件被占用时需重启后重试' -f $version)
            }
        } elseif (-not $Quiet) {
            Write-Host ('    引导包无法直接解压，复用系统 7-Zip {0}：{1}' -f $version, $found.Dir) -ForegroundColor Gray
        }

        if ((Test-WinstPathUnderRoot -Path $found.Dir -Root $target -AllowEqual) -or
                (Test-WinstPathUnderRoot -Path $target -Root $found.Dir -AllowEqual)) {
            throw '系统 7-Zip 目录与引擎目录重叠，拒绝清理系统安装'
        }
        $stage = Join-WinstPath $parent ('.winst-stage-' + [guid]::NewGuid().ToString('N'))
        Assert-WinstSafeWritePath -Path $stage -Directory
        $null = New-Item -ItemType Directory -Path $stage -ErrorAction Stop
        foreach ($name in @('7z.exe', '7z.dll')) {
            $source = Join-WinstPath $found.Dir $name
            Assert-WinstSafeWritePath -Path $source
            Copy-Item -LiteralPath $source -Destination (Join-WinstPath $stage $name) -ErrorAction Stop
            $copied = Get-WinstPackageDerivedVersion -Plan @{} -PkgDir $stage -FileName $name
            if (-not $copied.Ok -or (Compare-WinstVersion -A $copied.Version -B $version) -ne 0) {
                throw ('复制后的 {0} 不符合所需版本 {1}，保留原引擎目录' -f $name, $version)
            }
        }
        $result.TempRoot = $stage
        $result.SourceDir = $stage
        $result.Ok = $true
        return $result
    } catch {
        $result.Error = ('从系统 7-Zip 准备引擎失败：' + $_.Exception.Message)
        return $result
    } finally {
        if (-not $result.Ok -and $stage -and (Test-Path -LiteralPath $stage)) {
            Clear-WinstInstallDir -Dir $stage -AllowedRoot $parent
        }
    }
}
