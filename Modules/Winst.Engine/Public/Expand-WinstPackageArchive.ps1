#Requires -Version 5.1

function Expand-WinstPackageArchive {
    <#
    .SYNOPSIS
        解压压缩包到指定目录：7z.exe（7-Zip-CLI 引擎）→ 系统 tar.exe → Expand-Archive（仅 zip）。
    .DESCRIPTION
        解压引擎就是完整版 7-Zip 的命令行前端（7z.exe + 7z.dll），覆盖 7-Zip 的全部格式——7z / zip /
        tar / gzip / xz / cab / **NSIS 安装器** / RAR / WIM / iso 等，因此不需要"借系统已装的完整版
        7-Zip"这一档。后面两档只是引擎不可用（首次引导的鸡生蛋
        环节）或解压失败时的后备：tar.exe（bsdtar）能解 7z / zip / tar / gz / rar / iso，正好够用来解
        引擎自己的引导包；Expand-Archive 仅 .zip。
    .OUTPUTS
        @{ Ok; Tool; Error }
    #>
    param(
        [hashtable]$Context,
        [Parameter(Mandatory = $true)][string]$ArchivePath,
        [Parameter(Mandatory = $true)][string]$DestDir
    )

    $result = @{ Ok = $false; Tool = ''; Error = '' }
    if (-not (Test-Path -LiteralPath $ArchivePath -PathType Leaf)) {
        $result.Error = ('找不到压缩包：{0}' -f $ArchivePath)
        return $result
    }
    $null = New-Item -ItemType Directory -Path $DestDir -Force -ErrorAction SilentlyContinue

    $errors = New-Object 'System.Collections.Generic.List[string]'

    # ① 解压引擎（7-Zip-CLI 的 7z.exe）：全格式，NSIS 安装包 / RAR / WIM 都走这一档
    $sevenZip = ''
    if ($Context) { $sevenZip = Get-WinstEngineExe -Context $Context -Id (Get-WinstExtractEngineId) }
    if ($sevenZip) {
        # 路径与解压目录逐项加引号（含空格时 `-oC:\Program Files\x` 会被拆成两个参数）；
        # 值里出现双引号直接拒绝，不靠手工拼接转义
        if (-not (Test-WinstArgumentSafe -Value $ArchivePath) -or -not (Test-WinstArgumentSafe -Value $DestDir)) {
            $errors.Add('压缩包路径或解压目录含有无法安全传给 7z 的字符（双引号 / 控制字符）')
        } else {
            try {
                $argText = 'x {0} {1} -y -bso0 -bse0 -bsp0' -f (Format-WinstCommandArgument -Value $ArchivePath), (Format-WinstCommandArgument -Value ('-o' + $DestDir))
                $p = Start-Process -FilePath $sevenZip -ArgumentList $argText -Wait -PassThru -NoNewWindow
                if ($p.ExitCode -eq 0) { $result.Ok = $true; $result.Tool = '7z'; return $result }
                $errors.Add(('7z 退出码 {0}' -f $p.ExitCode))
            } catch {
                $errors.Add(('7z 调用失败：{0}' -f $_.Exception.Message))
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
            $errors.Add('压缩包路径或解压目录含有无法安全传给 tar 的字符（双引号 / 控制字符）')
        } else {
            try {
                $argText = '-xf {0} -C {1}' -f (Format-WinstCommandArgument -Value $ArchivePath), (Format-WinstCommandArgument -Value $DestDir)
                $p = Start-Process -FilePath $tarPath -ArgumentList $argText -Wait -PassThru -NoNewWindow
                if ($p.ExitCode -eq 0) { $result.Ok = $true; $result.Tool = 'tar'; return $result }
                $errors.Add(('tar 退出码 {0}' -f $p.ExitCode))
            } catch {
                $errors.Add(('tar 调用失败：{0}' -f $_.Exception.Message))
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
            $errors.Add(('Expand-Archive 失败：{0}' -f $_.Exception.Message))
        }
    }

    $detail = ''
    if ($errors.Count -gt 0) { $detail = '（已尝试：{0}）' -f ($errors -join '；') }
    if (-not $sevenZip) {
        # 引擎不在（首次引导时可能出现，或安装目录被挪走）：按"缺引擎"给指引
        $hint = ('解压引擎不可用；请执行 winst install {0} 安装（一键安装 / bundle install 会自动装）。' -f (Get-WinstExtractEngineId))
    } else {
        # 引擎在却打不开：多数是包损坏，或包不是 7-Zip 能识别的档案（如某些自解压封装）
        $hint = '这个包 7-Zip 打不开（格式不支持或文件损坏）；可用 --verbose 查看引擎原始输出，或用其它工具确认这个包能否解开。'
    }
    $result.Error = ('无法解压 {0}{1}。{2}' -f (Split-Path -Leaf $ArchivePath), $detail, $hint)
    return $result
}
