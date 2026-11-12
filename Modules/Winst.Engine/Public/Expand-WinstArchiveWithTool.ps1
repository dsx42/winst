#Requires -Version 5.1

function Expand-WinstArchiveWithTool {
    <#
    .SYNOPSIS
        按引擎、系统 tar、系统 ZIP 的顺序解压到空暂存目录，重试前清除本次失败残留；指定 7-Zip 时只用该程序。
    .OUTPUTS
        @{ Ok; Tool }
    #>
    param([hashtable]$Context, [Parameter(Mandatory = $true)][string]$ArchivePath,
        [Parameter(Mandatory = $true)][string]$DestDir, [Parameter(Mandatory = $true)]$Errors, [string]$SevenZipPath = '')

    $result = @{ Ok = $false; Tool = '' }
    try {
        $DestDir = [IO.Path]::GetFullPath($DestDir)
        Assert-WinstSafeWritePath -Path $DestDir -Directory
        if (Test-Path -LiteralPath $DestDir) {
            if (-not (Test-Path -LiteralPath $DestDir -PathType Container)) { throw '解压暂存路径不是目录' }
            if (Get-ChildItem -LiteralPath $DestDir -Force -ErrorAction Stop | Select-Object -First 1) {
                throw '解压暂存目录必须为空，拒绝覆盖已有文件'
            }
        }
    } catch {
        $Errors.Add($_.Exception.Message)
        return $result
    }
    foreach ($value in @($ArchivePath, $DestDir)) {
        if (-not (Test-WinstArgumentSafe -Value $value)) {
            $Errors.Add('压缩包或目标路径含有不安全的命令行字符')
            return $result
        }
    }
    $tools = New-Object 'System.Collections.Generic.List[object]'
    $sevenZip = $SevenZipPath
    if (-not $sevenZip -and $Context) { $sevenZip = Get-WinstEngineExe -Context $Context -Id (Get-WinstExtractEngineId) }
    if ($sevenZip) { $tools.Add(@{ Name = '7z'; Path = $sevenZip }) }
    if (-not $SevenZipPath) {
        $tar = Get-Command tar.exe -ErrorAction SilentlyContinue
        if ($tar) { $tools.Add(@{ Name = 'tar'; Path = [string]$tar.Source }) }
        if ($ArchivePath -match '(?i)\.zip$') { $tools.Add(@{ Name = 'Expand-Archive'; Path = '' }) }
    }

    foreach ($tool in $tools) {
        try {
            $null = New-Item -ItemType Directory -Path $DestDir -Force -ErrorAction Stop
            if ($tool.Name -eq 'Expand-Archive') {
                Expand-Archive -LiteralPath $ArchivePath -DestinationPath $DestDir -Force -ErrorAction Stop
            } else {
                $arguments = ''
                if ($tool.Name -eq '7z') {
                    $arguments = 'x {0} {1} -y -bso0 -bse0 -bsp0' -f (Format-WinstCommandArgument $ArchivePath), (Format-WinstCommandArgument ('-o' + $DestDir))
                } else {
                    $arguments = '-xf {0} -C {1}' -f (Format-WinstCommandArgument $ArchivePath), (Format-WinstCommandArgument $DestDir)
                }
                $run = Invoke-WinstCapturedCommand -FilePath $tool.Path -Arguments $arguments -NoTimeout -TailOutput -MaxOutputChars 65536
                if (-not $run.Ok -or $null -eq $run.ExitCode -or $run.ExitCode -ne 0) {
                    throw ('退出码 {0}：{1} {2}' -f $run.ExitCode, $run.Error, $run.ErrText)
                }
            }
            Assert-WinstTreeWithoutReparsePoint -Path $DestDir
            $result.Ok = $true
            $result.Tool = $tool.Name
            return $result
        } catch {
            $Errors.Add(('{0} 解压失败：{1}' -f $tool.Name, $_.Exception.Message))
        }
        try {
            Clear-WinstInstallDir -Dir $DestDir -Strict
        } catch {
            $Errors.Add(('清理解压失败残留失败：{0}' -f $_.Exception.Message))
            return $result
        }
    }
    return $result
}
