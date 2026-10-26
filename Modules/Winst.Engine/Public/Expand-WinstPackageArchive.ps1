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

        7-Zip 自解压包（`7z<版本>-x64.exe` 这类 PE + 内嵌 7z）：先按 Get-Winst7zSfxPayload 把内嵌
        载荷切出来当普通 .7z 解。系统自带的 bsdtar 在旧版 Windows（如 10 21H2）上是 libarchive 3.6，
        只在 0x27000～0x60000 之间扫 7z 签名，而新版 7-Zip 的载荷起点已经前移到这个窗口之下，
        于是「同样的包在新系统能解、老系统报无法识别格式」——这不是包坏，是系统工具太旧。
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

    # ⓪ 7-Zip 自解压包：先切出内嵌载荷（不依赖系统工具的扫描窗口版本）
    $carvedPath = ''
    try {
        $carved = Get-Winst7zSfxPayload -Path $ArchivePath -DestDir ([IO.Path]::GetTempPath())
        if ($carved.Ok -and $carved.Path) {
            $carvedPath = [string]$carved.Path
            $inner = Expand-WinstArchiveWithTool -Context $Context -ArchivePath $carvedPath -DestDir $DestDir -Errors $errors
            if ($inner.Ok) {
                $result.Ok = $true
                $result.Tool = $inner.Tool + '(sfx)'
                return $result
            }
        } elseif ($carved.Error) {
            $errors.Add([string]$carved.Error)
        }
    } finally {
        if ($carvedPath -and (Test-Path -LiteralPath $carvedPath -PathType Leaf)) {
            Remove-Item -LiteralPath $carvedPath -Force -ErrorAction SilentlyContinue
        }
    }

    $direct = Expand-WinstArchiveWithTool -Context $Context -ArchivePath $ArchivePath -DestDir $DestDir -Errors $errors
    if ($direct.Ok) {
        $result.Ok = $true
        $result.Tool = $direct.Tool
        return $result
    }

    $sevenZip = ''
    if ($Context) { $sevenZip = Get-WinstEngineExe -Context $Context -Id (Get-WinstExtractEngineId) }

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
