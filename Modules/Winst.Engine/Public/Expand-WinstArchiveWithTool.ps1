#Requires -Version 5.1

function Expand-WinstArchiveWithTool {
    <#
    .SYNOPSIS
        按引擎、系统 tar、系统 ZIP 的顺序解压到空暂存目录，重试前清除失败残留。
    #>
    param([hashtable]$Context, [Parameter(Mandatory = $true)][string]$ArchivePath,
        [Parameter(Mandatory = $true)][string]$DestDir, [Parameter(Mandatory = $true)]$Errors, [string]$SevenZipPath = '')

    $result = @{ Ok = $false; Tool = ''; ValidationFailed = $false }
    try {
        Assert-WinstSafeWritePath -Path $DestDir -Directory
        if ((Test-WinstFileSystemPath -Path $DestDir) -and
            (Get-WinstChildItem -Path $DestDir -ErrorAction Stop | Select-Object -First 1)) {
            throw '解压暂存目录必须为空，拒绝覆盖已有文件'
        }
        $archiveIo = ConvertTo-WinstExtendedPath -Path $ArchivePath
        $destIo = ConvertTo-WinstExtendedPath -Path $DestDir
        foreach ($value in @($archiveIo, $destIo)) {
            if (-not (Test-WinstArgumentSafe -Value $value)) { throw '压缩包或目标路径含有不安全的命令行字符' }
        }
    } catch {
        $result.ValidationFailed = $true
        $Errors.Add($_.Exception.Message)
        return $result
    }
    $tools = New-Object 'System.Collections.Generic.List[object]'
    $sevenZip = $SevenZipPath
    if (-not $sevenZip -and $Context) { $sevenZip = Get-WinstEngineExe -Context $Context -Id (Get-WinstExtractEngineId) }
    if ($sevenZip) { $tools.Add(@{ Name = '7z'; Path = $sevenZip }) }
    if (-not $SevenZipPath) {
        $tar = Get-Command tar.exe -ErrorAction SilentlyContinue
        if ($tar) { $tools.Add(@{ Name = 'tar'; Path = [string]$tar.Source }) }
        if ($ArchivePath -match '(?i)\.zip$') { $tools.Add(@{ Name = 'ZIP'; Path = '' }) }
    }

    for ($i = 0; $i -lt $tools.Count; $i++) {
        $tool = $tools[$i]
        if ($i -gt 0) {
            try {
                Remove-WinstDirectoryTree -Path $DestDir
            } catch {
                $result.ValidationFailed = $true
                $Errors.Add(('清理解压失败残留失败：{0}' -f $_.Exception.Message))
                return $result
            }
        }
        try {
            $null = [IO.Directory]::CreateDirectory($destIo)
            if ($tool.Name -eq 'ZIP') {
                Add-Type -AssemblyName System.IO.Compression.FileSystem -ErrorAction Stop
                [IO.Compression.ZipFile]::ExtractToDirectory($archiveIo, $destIo)
            } else {
                if ($tool.Name -eq '7z') {
                    $arguments = 'x {0} {1} -y -bso0 -bse0 -bsp0' -f (Format-WinstCommandArgument $archiveIo), (Format-WinstCommandArgument ('-o' + $destIo))
                } else {
                    $arguments = '-xf {0} -C {1}' -f (Format-WinstCommandArgument $archiveIo), (Format-WinstCommandArgument $destIo)
                }
                $run = Invoke-WinstCapturedCommand -FilePath $tool.Path -Arguments $arguments -NoTimeout -TailOutput -MaxOutputChars 65536
                if (-not $run.Ok -or $null -eq $run.ExitCode -or $run.ExitCode -ne 0) {
                    throw ('退出码 {0}：{1} {2}' -f $run.ExitCode, $run.Error, $run.ErrText)
                }
            }
            $result.Ok = $true
            $result.Tool = $tool.Name
            return $result
        } catch {
            $Errors.Add(('{0} 解压失败：{1}' -f $tool.Name, $_.Exception.Message))
        }
    }
    return $result
}
