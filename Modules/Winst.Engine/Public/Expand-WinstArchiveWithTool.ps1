#Requires -Version 5.1

function Expand-WinstArchiveWithTool {
    <#
    .SYNOPSIS
        按引擎、系统 tar、系统 ZIP 的顺序在独立暂存树解压，只交付成功档的内容。
    .OUTPUTS
        @{ Ok; Tool }
    #>
    param([hashtable]$Context, [Parameter(Mandatory = $true)][string]$ArchivePath,
        [Parameter(Mandatory = $true)][string]$DestDir, [Parameter(Mandatory = $true)]$Errors)

    $result = @{ Ok = $false; Tool = '' }
    Assert-WinstSafeWritePath -Path $DestDir -Directory
    foreach ($value in @($ArchivePath, $DestDir)) {
        if (-not (Test-WinstArgumentSafe -Value $value)) {
            $Errors.Add('压缩包或目标路径含有不安全的命令行字符')
            return $result
        }
    }
    $tools = New-Object 'System.Collections.Generic.List[object]'
    $sevenZip = ''
    if ($Context) { $sevenZip = Get-WinstEngineExe -Context $Context -Id (Get-WinstExtractEngineId) }
    if ($sevenZip) { $tools.Add(@{ Name = '7z'; Path = $sevenZip }) }
    $tar = Get-Command tar.exe -ErrorAction SilentlyContinue
    if ($tar) { $tools.Add(@{ Name = 'tar'; Path = [string]$tar.Source }) }
    if ($ArchivePath -match '(?i)\.zip$') { $tools.Add(@{ Name = 'Expand-Archive'; Path = '' }) }

    foreach ($tool in $tools) {
        $stage = Join-WinstPath ([IO.Path]::GetTempPath()) ('winst-unpack-' + [guid]::NewGuid().ToString('N'))
        try {
            Assert-WinstSafeWritePath -Path $stage -Directory
            $null = New-Item -ItemType Directory -Path $stage -ErrorAction Stop
            try {
                if ($tool.Name -eq 'Expand-Archive') {
                    Expand-Archive -LiteralPath $ArchivePath -DestinationPath $stage -Force -ErrorAction Stop
                } else {
                    $arguments = ''
                    if ($tool.Name -eq '7z') {
                        $arguments = 'x {0} {1} -y -bso0 -bse0 -bsp0' -f (Format-WinstCommandArgument $ArchivePath), (Format-WinstCommandArgument ('-o' + $stage))
                    } else {
                        $arguments = '-xf {0} -C {1}' -f (Format-WinstCommandArgument $ArchivePath), (Format-WinstCommandArgument $stage)
                    }
                    $run = Invoke-WinstCapturedCommand -FilePath $tool.Path -Arguments $arguments -NoTimeout -TailOutput -MaxOutputChars 65536
                    if (-not $run.Ok -or $run.ExitCode -ne 0) {
                        $Errors.Add(('{0} 解压失败（退出码 {1}）：{2} {3}' -f $tool.Name, $run.ExitCode, $run.Error, $run.ErrText))
                        continue
                    }
                }
            } catch {
                $Errors.Add(('{0} 解压失败：{1}' -f $tool.Name, $_.Exception.Message))
                continue
            }
            # 交付阶段失败必须直接返回，不能把部分交付的目录交给下一档继续合并。
            try {
                Assert-WinstTreeWithoutReparsePoint -Path $stage
                if (-not (Test-Path -LiteralPath $DestDir -PathType Container)) {
                    $null = New-Item -ItemType Directory -Path $DestDir -Force -ErrorAction Stop
                }
                foreach ($item in @(Get-ChildItem -LiteralPath $stage -Force -ErrorAction Stop)) {
                    Move-WinstItemInto -Source $item -DestDir $DestDir
                }
            } catch {
                $Errors.Add(('交付解压结果失败：{0}' -f $_.Exception.Message))
                return $result
            }
            $result.Ok = $true
            $result.Tool = $tool.Name
            return $result
        } finally {
            if (Test-Path -LiteralPath $stage) { Clear-WinstInstallDir -Dir $stage }
        }
    }
    return $result
}
