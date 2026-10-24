#Requires -Version 5.1

function New-WinstScriptLauncher {
    <#
    .SYNOPSIS
        为主程序是 PowerShell 脚本（.ps1）的条目生成同名 .cmd 启动器，返回 .cmd 的完整路径。
    .DESCRIPTION
        .lnk 不能直接指向 .ps1：双击时由 shell 按文件关联「打开」脚本（记事本打开 / 被执行策略拦下），不会执行。
        因此在脚本旁边写一个同名 .cmd（winst.ps1 → winst.cmd），内容为
        powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0<脚本名>" %* ，
        快捷方式指向 .cmd；%~dp0 按实际安装位置解析脚本目录，%* 透传快捷方式 / 命令行参数。
        `-ExecutionPolicy` 只作用于这一个 powershell 进程、不写注册表；这里用 Bypass 与「离线套件」生成的
        winst.cmd（见 Invoke-WinstPack）以及 Scoop / Chocolatey 的 shim 保持一致：从浏览器下载 zip 解压出来的副本带
        网络来源标记（MOTW），RemoteSigned 会拒绝执行、双击仍然打不开。
        内容一致时不重写（幂等）；内容不同才覆盖。
    #>
    param([Parameter(Mandatory = $true)][string]$ScriptPath)

    $scriptFull = $ScriptPath
    try { $scriptFull = [IO.Path]::GetFullPath($ScriptPath) } catch { $scriptFull = $ScriptPath }
    $scriptName = [IO.Path]::GetFileName($scriptFull)
    $launcherPath = [IO.Path]::ChangeExtension($scriptFull, '.cmd')
    $content = ('powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0{0}" %*' -f $scriptName)

    if (Test-Path -LiteralPath $launcherPath -PathType Leaf) {
        $existing = ''
        try { $existing = [IO.File]::ReadAllText($launcherPath) } catch { $existing = '' }
        if ($existing.Trim() -eq $content.Trim()) { return $launcherPath }
    }

    $parent = Split-Path -Parent $launcherPath
    if ($parent -and -not (Test-Path -LiteralPath $parent -PathType Container)) {
        $null = New-Item -ItemType Directory -Path $parent -Force -ErrorAction SilentlyContinue
    }
    # .cmd 由 cmd.exe 按控制台代码页（OEM）读取，带非 ASCII 文件名时用 OEM 代码页落盘才不会乱码
    $encoding = $null
    try { $encoding = [Text.Encoding]::GetEncoding([Globalization.CultureInfo]::CurrentCulture.TextInfo.OEMCodePage) } catch { $encoding = [Text.Encoding]::Default }
    [IO.File]::WriteAllText($launcherPath, ($content + "`r`n"), $encoding)
    return $launcherPath
}
