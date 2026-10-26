#Requires -Version 5.1

function Test-WinstReadOnlyInvocation {
    <#
    .SYNOPSIS
        判断这次启动是不是「只读、不碰数据文件」的调用（版本 / 帮助）。
    .DESCRIPTION
        这些调用不写任何文件，因此不受单进程锁约束，也不需要提权。更重要的是：
        清单里 winst 自身的版本检测就是执行 `winst.cmd -v`，
        若把它也挡在锁外，已装软件列表 / 自更新会拿不到版本而互相卡住。

        判据是**命令位置**而不是「参数里出现过某个词」：
        先按 Read-WinstCommandLine 的口径摘掉全局开关与命令之前的其它开关，
        取第一个非开关 token 作为命令；只有当这个命令本身是只读命令时才算只读。

        这样 `winst repair help` / `winst uninstall app -v` / `winst install x --help`
        都**不再**被误判为只读：它们的命令分别是 repair / uninstall / install，
        后面那些 token 只是（可能写错的）命令参数，会被各子命令自己拒绝或忽略。
        反过来 `winst -v`、`winst --version`、`winst help`、`winst help install`、
        `winst --offline -v` 仍按只读处理。
    .OUTPUTS
        [bool]
    #>
    param([string[]]$Arguments = @())

    $tokens = @($Arguments)
    $waitingForValue = $false

    foreach ($one in $tokens) {
        $text = ([string]$one).Trim()
        if (-not $text) { continue }

        # 带值全局开关的取值不是命令（`--pkg-dir D:\pkg list`）
        if ($waitingForValue) { $waitingForValue = $false; continue }
        if ($text -ieq '--install-root' -or $text -ieq '--pkg-dir' -or $text -ieq '--proxy') {
            $waitingForValue = $true
            continue
        }
        # 其余全局开关（含 = 取值写法）也不是命令
        if ($text -like '--install-root=*' -or $text -like '--pkg-dir=*' -or $text -like '--proxy=*') { continue }
        if ($text -ieq '--offline' -or $text -ieq '--dry-run' -or $text -ieq '--yes' -or
            $text -ieq '-y' -or $text -ieq '--verbose') { continue }

        # 第一个非开关 token 就是命令位置：只由它决定是否为只读调用
        if (-not $text.StartsWith('-')) { return (Test-WinstReadOnlyCommand -Name $text) }

        # 命令之前的开关：`-v` / `--version` / `-h` / `--help` / `-?` 本身就是一次只读调用
        if ($text -ieq '-v' -or $text -ieq '--version' -or $text -ieq '-h' -or
            $text -ieq '--help' -or $text -ieq '-?') {
            return $true
        }
    }

    return $false
}
