#Requires -Version 5.1

function Expand-WinstArchiveWithTool {
    <#
    .SYNOPSIS
        用「解压引擎 → 系统 tar → Expand-Archive」三档依次尝试解压，返回第一个成功的档位。

    .DESCRIPTION
        Expand-WinstPackageArchive 的逐档实现：调用方可能要先处理自解压包（切出内嵌载荷），
        再用同一套档位解那份载荷，因此把「依次尝试」抽出来复用，避免两处各写一遍。

        每一档失败都把原因追加进调用方传进来的 Errors 列表（不抛异常）：
        最终失败时由调用方统一拼报错文案，用户能看到「三档各自为什么不行」。

    .OUTPUTS
        @{ Ok; Tool }
    #>
    param(
        [hashtable]$Context,
        [Parameter(Mandatory = $true)][string]$ArchivePath,
        [Parameter(Mandatory = $true)][string]$DestDir,
        [Parameter(Mandatory = $true)]$Errors
    )

    $result = @{ Ok = $false; Tool = '' }

    # ① 解压引擎（7-Zip-CLI 的 7z.exe）：全格式，NSIS 安装包 / RAR / WIM 都走这一档
    $sevenZip = ''
    if ($Context) { $sevenZip = Get-WinstEngineExe -Context $Context -Id (Get-WinstExtractEngineId) }
    if ($sevenZip) {
        # 路径与解压目录逐项加引号（含空格时 `-oC:\Program Files\x` 会被拆成两个参数）；
        # 值里出现双引号直接拒绝，不靠手工拼接转义
        if (-not (Test-WinstArgumentSafe -Value $ArchivePath) -or -not (Test-WinstArgumentSafe -Value $DestDir)) {
            $Errors.Add('压缩包路径或解压目录含有无法安全传给 7z 的字符（双引号 / 控制字符）')
        } else {
            try {
                $argText = 'x {0} {1} -y -bso0 -bse0 -bsp0' -f (Format-WinstCommandArgument -Value $ArchivePath), (Format-WinstCommandArgument -Value ('-o' + $DestDir))
                $p = Start-Process -FilePath $sevenZip -ArgumentList $argText -Wait -PassThru -NoNewWindow
                if ($p.ExitCode -eq 0) { $result.Ok = $true; $result.Tool = '7z'; return $result }
                $Errors.Add(('7z 退出码 {0}' -f $p.ExitCode))
            } catch {
                $Errors.Add(('7z 调用失败：{0}' -f $_.Exception.Message))
            }
        }
    }

    # ② 系统内置 tar.exe（bsdtar）
    $tarPath = ''
    try {
        $tarCmd = Get-Command 'tar.exe' -ErrorAction SilentlyContinue
        if ($tarCmd) { $tarPath = [string]$tarCmd.Source }
    } catch {
        $tarPath = ''
    }
    if ($tarPath) {
        if (-not (Test-WinstArgumentSafe -Value $ArchivePath) -or -not (Test-WinstArgumentSafe -Value $DestDir)) {
            $Errors.Add('压缩包路径或解压目录含有无法安全传给 tar 的字符（双引号 / 控制字符）')
        } else {
            try {
                $argText = '-xf {0} -C {1}' -f (Format-WinstCommandArgument -Value $ArchivePath), (Format-WinstCommandArgument -Value $DestDir)
                $p = Start-Process -FilePath $tarPath -ArgumentList $argText -Wait -PassThru -NoNewWindow
                if ($p.ExitCode -eq 0) { $result.Ok = $true; $result.Tool = 'tar'; return $result }
                $Errors.Add(('tar 退出码 {0}' -f $p.ExitCode))
            } catch {
                $Errors.Add(('tar 调用失败：{0}' -f $_.Exception.Message))
            }
        }
    }

    # ③ Expand-Archive（仅 .zip）
    if ($ArchivePath -match '(?i)\.zip$') {
        try {
            Expand-Archive -LiteralPath $ArchivePath -DestinationPath $DestDir -Force -ErrorAction Stop
            $result.Ok = $true
            $result.Tool = 'Expand-Archive'
            return $result
        } catch {
            $Errors.Add(('Expand-Archive 失败：{0}' -f $_.Exception.Message))
        }
    }

    return $result
}
