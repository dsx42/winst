#Requires -Version 5.1

function Test-WinstReadOnlyCommand {
    <#
    .SYNOPSIS
        判断一个命令名（命令位置上的那个 token）是否属于「只读、不碰数据文件」的命令。
    .DESCRIPTION
        只读命令：`-v` / `--version` / `version` / `-h` / `--help` / `-?` / `help` / `?`。
        这些命令只打印版本号或帮助文本，不读也不写台账 / 清单 / 缓存，
        因此单进程锁与管理员提权都可以跳过。

        **只判断命令名本身**：`repair` / `uninstall` / `install` 等写入类命令即使后面跟着
        `help` / `-v` 也一律不算只读——那只是命令参数，不能作为跳过锁的依据。
    .OUTPUTS
        [bool]
    #>
    param([string]$Name = '')

    $text = ([string]$Name).Trim()
    if (-not $text) { return $false }

    if ($text -ieq '-v' -or $text -ieq '--version' -or $text -ieq 'version') { return $true }
    if ($text -ieq '-h' -or $text -ieq '--help' -or $text -ieq '-?' -or $text -ieq 'help' -or $text -ieq '?') { return $true }
    return $false
}
