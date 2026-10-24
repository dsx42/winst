#Requires -Version 5.1

function Test-WinstReadOnlyInvocation {
    <#
    .SYNOPSIS
        判断这次启动是不是「只读、不碰数据文件」的调用（版本 / 帮助）。
    .DESCRIPTION
        这些调用不写任何文件，因此不受单进程锁约束。更重要的是：
        清单里 winst 自身的版本检测就是执行 `winst.cmd -v`，
        若把它也挡在锁外，已装软件列表 / 自更新会拿不到版本而互相卡住。

        判据只看命令行里是否出现这些 token（位置不限）：
        `-v` / `--version` / `version` / `-h` / `--help` / `-?` / `help`。
    .OUTPUTS
        [bool]
    #>
    param([string[]]$Arguments = @())

    foreach ($one in @($Arguments)) {
        $text = ([string]$one).Trim()
        if (-not $text) { continue }
        if ($text -ieq '-v' -or $text -ieq '--version' -or $text -ieq 'version') { return $true }
        if ($text -ieq '-h' -or $text -ieq '--help' -or $text -ieq '-?' -or $text -ieq 'help') { return $true }
    }
    return $false
}
