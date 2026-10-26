#Requires -Version 5.1

function Get-WinstInstanceLockPath {
    <#
    .SYNOPSIS
        单进程锁的文件路径：<数据目录>\winst.lock。
    .DESCRIPTION
        锁跟着**数据目录**走：同一份配置（config.json）只允许一个 winst 在跑。
        用 WINST_HOME 隔离数据目录的实验（测试脚本）因此可以并行，
        而日常使用（默认 %USERPROFILE%\.winst）天然只有一个锁。
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param()

    return (Join-WinstPath (Get-DataRoot) 'winst.lock')
}
