#Requires -Version 5.1

function Read-WinstCommandLine {
    <#
    .SYNOPSIS
        解析命令行：抽出全局参数，剩下的按「命令 + 命令参数」返回。
    .DESCRIPTION
        全局参数**写在命令之前或之后都支持**（`winst --pkg-dir D:\pkg list` 与
        `winst list --pkg-dir D:\pkg` 等价）：两种位置都会从命令参数里摘掉，交给全局选项；
        开关支持 `--pkg-dir <路径>` 与 `--pkg-dir=<路径>` 两种写法。
        命令自己认识的开关（如 `--force` / `--keep` / `--check`）原样保留，不会误吃。
    .OUTPUTS
        @{ Options; Command; Arguments; Error }
    #>
    param([string[]]$Tokens)

    $options = New-WinstCliOptions
    $command = ''
    $rest = @()
    $waitingFor = ''
    $error = ''

    foreach ($one in @($Tokens)) {
        $text = [string]$one

        if ($waitingFor) {
            if (-not $text -or $text.StartsWith('-')) {
                # 非开关 token 仍按「值优先」解释（`--pkg-dir list` 的 list 仍是路径）。
                $name = @{ installRoot = 'install-root'; pkgDir = 'pkg-dir'; proxy = 'proxy' }[$waitingFor]
                $error = ('--{0} 缺少取值，请写成 --{0} <值> 或 --{0}=<值>。' -f $name)
                break
            } else {
                if ($waitingFor -eq 'installRoot') { $options.InstallRoot = $text }
                elseif ($waitingFor -eq 'pkgDir') { $options.PkgDir = $text }
                elseif ($waitingFor -eq 'proxy') { $options.Proxy = $text }
                $waitingFor = ''
                continue
            }
        }

        # —— 全局参数：写在命令之前或之后都识别（`winst --pkg-dir x list` = `winst list --pkg-dir x`）——
        if ($text -ieq '--install-root') { $waitingFor = 'installRoot'; continue }
        if ($text -ieq '--pkg-dir') { $waitingFor = 'pkgDir'; continue }
        if ($text -ieq '--proxy') { $waitingFor = 'proxy'; continue }
        # -like 不区分大小写，与上面 -ieq 的口径一致（StartsWith 默认区分大小写，--PKG-DIR=x 会被漏掉）
        if ($text -like '--install-root=*') {
            $options.InstallRoot = ($text.Substring(15)).Trim()
            if (-not $options.InstallRoot) { $error = '--install-root 缺少取值，请写成 --install-root <值> 或 --install-root=<值>。'; break }
            continue
        }
        if ($text -like '--pkg-dir=*') {
            $options.PkgDir = ($text.Substring(10)).Trim()
            if (-not $options.PkgDir) { $error = '--pkg-dir 缺少取值，请写成 --pkg-dir <值> 或 --pkg-dir=<值>。'; break }
            continue
        }
        if ($text -like '--proxy=*') {
            $options.Proxy = ($text.Substring(8)).Trim()
            if (-not $options.Proxy) { $error = '--proxy 缺少取值，请写成 --proxy <值> 或 --proxy=<值>。'; break }
            continue
        }
        if ($text -ieq '--offline') { $options.Offline = $true; continue }
        if ($text -ieq '--dry-run') { $options.DryRun = $true; continue }
        if ($text -ieq '--yes' -or $text -ieq '-y') { $options.Yes = $true; continue }
        if ($text -ieq '--verbose') { $options.Verbose = $true; continue }

        # 还没有命令名：遇到 -v / -h 这类「本身就是完整命令」的开关时它就是命令，
        # 后面的 token 只是它的参数（`winst -v repair` 仍然是「查看版本」，不展开成 repair）。
        # 其它开关先记着继续往后找命令名；遇到非开关即命令名。
        if (-not $command) {
            if ($text.StartsWith('-')) {
                if (Test-WinstReadOnlyCommand -Name $text) {
                    $command = $text
                    continue
                }
                $rest += $text
                continue
            }
            $command = $text
            continue
        }

        # 命令之后的开关：全局参数已在上方摘走，其余原样交给该命令自己解析（如 update --check、list --cached）
        $rest += $text
    }

    if ($waitingFor -and -not $error) {
        $name = @{ installRoot = 'install-root'; pkgDir = 'pkg-dir'; proxy = 'proxy' }[$waitingFor]
        $error = ('--{0} 缺少取值，请写成 --{0} <值> 或 --{0}=<值>。' -f $name)
    }

    return @{ Options = $options; Command = $command; Arguments = @($rest); Error = $error }
}
