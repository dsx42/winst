#Requires -Version 5.1

function Resolve-WinstUninstallerCommand {
    <#
    .SYNOPSIS
        解析一条卸载命令行：拆出程序与参数，把裸名程序定位成系统目录里的绝对路径，并做安全检查。
    .DESCRIPTION
        注册表 / 清单里的 UninstallString 可能是：
          - 带引号或带空格的绝对路径（`"C:\ProgramData\Package Cache\{...}\x.exe" /uninstall`）
          - 裸名（`MsiExec.exe /X{GUID}`）——必须在系统目录里定位成绝对路径再执行：
            直接交给 CreateProcess 会按「当前目录 → PATH」搜索，当前目录里的同名 exe 可以劫持整个卸载流程
        程序文件不存在时错误里说明「找不到程序」（调用方据此区分「记录成了孤儿」与「执行失败」）。
    .OUTPUTS
        @{ Ok; Exe; Args; Command; Missing; Error }
    #>
    param([string]$CommandLine, [string]$ExtraArgs = '')

    $result = @{ Ok = $false; Exe = ''; Args = ''; Command = ''; Missing = $false; Error = '' }

    $split = Split-WinstCommandLine -Text $CommandLine
    if (-not $split.Ok -or -not $split.Exe) {
        $result.Error = ('无法解析卸载命令: {0}' -f $CommandLine)
        return $result
    }

    $exeText = ([string]$split.Exe).Trim('"')
    if (-not (Test-WinstArgumentSafe -Value $exeText)) {
        $result.Error = ('卸载命令里的程序路径含引号或控制字符，已拒绝执行: {0}' -f $CommandLine)
        return $result
    }

    # 裸名（msiexec 之类）必须在系统目录里定位
    if ($exeText -notmatch '^[A-Za-z]:[\\/]' -and -not $exeText.StartsWith('\\')) {
        $resolvedExe = ''
        $exeFileName = $exeText
        if (-not [IO.Path]::GetExtension($exeFileName)) { $exeFileName += '.exe' }
        $systemDirs = New-Object 'System.Collections.Generic.List[string]'
        if ($env:SystemRoot) {
            $systemDirs.Add((Join-WinstPath $env:SystemRoot 'System32'))
            $systemDirs.Add($env:SystemRoot)
            $systemDirs.Add((Join-WinstPath $env:SystemRoot 'SysWOW64'))
        }
        foreach ($systemDir in $systemDirs.ToArray()) {
            if (-not $systemDir) { continue }
            $candidate = Join-WinstPath $systemDir $exeFileName
            if (Test-Path -LiteralPath $candidate -PathType Leaf) { $resolvedExe = $candidate; break }
        }
        if (-not $resolvedExe) {
            $result.Error = ('卸载命令里的程序不在系统目录里，已拒绝执行（避免当前目录劫持）: {0}' -f $exeText)
            return $result
        }
        $exeText = $resolvedExe
    }

    if ($exeText -match '[\\/]' -and -not (Test-Path -LiteralPath $exeText -PathType Leaf)) {
        $result.Missing = $true
        $result.Exe = $exeText
        $result.Error = ('卸载器文件不存在: {0}' -f $exeText)
        return $result
    }

    $argumentList = [string]$split.Args
    if ($ExtraArgs) {
        if ($argumentList) { $argumentList = $argumentList + ' ' + $ExtraArgs } else { $argumentList = $ExtraArgs }
    }
    # 注册表 / 清单里的命令行不会带换行等控制字符：出现即视为异常记录，不执行
    if ($argumentList -match '[\x00-\x1F]') {
        $result.Error = ('卸载参数含有控制字符，已拒绝执行: {0}' -f $CommandLine)
        return $result
    }

    $result.Ok = $true
    $result.Exe = $exeText
    $result.Args = $argumentList
    $result.Command = ('{0} {1}' -f (Format-WinstCommandArgument -Value $exeText), $argumentList).Trim()
    return $result
}
