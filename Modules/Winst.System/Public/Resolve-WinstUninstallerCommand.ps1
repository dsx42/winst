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
        MSI 的 /I 产品代码或 .msi 路径转换为 /X，避免卸载时进入安装维护；其它动作保持原样。
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

    # 注册表里的 UninstallString 常用 %ProgramData% / %ProgramFiles% 写法：先展开再判断
    # 「带盘符的绝对路径」还是「裸名」，否则这类记录会被当成裸名去 System32 下找、必然找不到。
    # 只展开程序路径本身：参数里的 %VAR% 由卸载器按自己的口径处理。
    $exeText = [Environment]::ExpandEnvironmentVariables(([string]$split.Exe).Trim('"'))
    if (-not (Test-WinstArgumentSafe -Value $exeText)) {
        $result.Error = ('卸载命令里的程序路径含引号或控制字符，已拒绝执行: {0}' -f $CommandLine)
        return $result
    }

    # 裸名（msiexec 之类）必须在系统目录里定位
    if ($exeText -notmatch '^[A-Za-z]:[\\/]' -and -not $exeText.StartsWith('\\')) {
        if ($exeText -match '[\\/:]' -or -not (Test-WinstSafePathSegment -Name $exeText -MaxLength 255)) {
            $result.Error = ('卸载命令必须使用绝对路径或纯程序文件名，已拒绝执行: {0}' -f $exeText)
            return $result
        }
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
            $candidate = [IO.Path]::GetFullPath((Join-WinstPath $systemDir $exeFileName))
            if (-not (Test-WinstPathUnderRoot -Path $candidate -Root $systemDir)) { continue }
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

    if ([IO.Path]::GetFileName($exeText) -ieq 'msiexec.exe') {
        # 只识别独立动作参数（允许参数自身带外层引号）；属性值中的 /I 不是安装动作。
        # Windows 命令行中，引号前连续反斜杠为奇数时该引号是字面量。
        $tokens = New-Object 'System.Collections.Generic.List[object]'
        $quoted = $false
        $start = -1
        $slashes = 0
        for ($i = 0; $i -le $argumentList.Length; $i++) {
            if ($i -eq $argumentList.Length -or (-not $quoted -and [char]::IsWhiteSpace($argumentList[$i]))) {
                if ($start -ge 0) {
                    $tokens.Add(@{ Start = $start; Text = $argumentList.Substring($start, $i - $start) })
                    $start = -1
                }
                $slashes = 0
                continue
            }
            if ($start -lt 0) { $start = $i }
            $character = $argumentList[$i]
            if ($character -eq '"' -and $slashes % 2 -eq 0) { $quoted = -not $quoted }
            if ($character -eq '\') { $slashes++ } else { $slashes = 0 }
        }
        if ($quoted) {
            $result.Error = 'MSI 卸载参数的引号未闭合，已拒绝执行'
            return $result
        }
        for ($i = $tokens.Count - 1; $i -ge 0; $i--) {
            $token = [string]$tokens[$i].Text
            $actionOffset = 0
            if ($token.Length -ge 2 -and $token.StartsWith('"') -and $token.EndsWith('"')) {
                $token = $token.Substring(1, $token.Length - 2)
                $actionOffset = 1
            }
            if ($token -notmatch '(?i)^/i(?:$|["{]|.*\.msi"?$)') { continue }
            $target = $token.Substring(2)
            if (-not $target -and $i + 1 -lt $tokens.Count) { $target = [string]$tokens[$i + 1].Text }
            if ($target.StartsWith('"') -and $target.EndsWith('"') -and $target.Length -ge 2) {
                $target = $target.Substring(1, $target.Length - 2)
            }
            if ($target -notmatch '^\{[0-9a-fA-F]{8}-(?:[0-9a-fA-F]{4}-){3}[0-9a-fA-F]{12}\}$' -and
                ($target -notmatch '(?i)\.msi$' -or $target -match '["<>|]' -or $target.StartsWith('/'))) {
                $result.Error = 'MSI /I 参数必须指向产品代码或 .msi 文件，已拒绝执行'
                return $result
            }
            $position = [int]$tokens[$i].Start + $actionOffset + 1
            $argumentList = $argumentList.Remove($position, 1).Insert($position, 'X')
        }
    }

    $result.Ok = $true
    $result.Exe = $exeText
    $result.Args = $argumentList
    $result.Command = ('{0} {1}' -f (Format-WinstCommandArgument -Value $exeText), $argumentList).Trim()
    return $result
}
