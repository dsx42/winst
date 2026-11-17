#Requires -Version 5.1

function Get-WinstInstanceLockPath {
    <#
    .SYNOPSIS
        数据目录锁的文件路径：<数据目录>\winst.lock。
    .DESCRIPTION
        同一份数据目录只允许一个 winst 在跑。入口还会取得 Temp 下的共享暂存锁；
        并行实验必须同时隔离 WINST_HOME 与 Temp。
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param()

    return (Join-WinstPath (Get-DataRoot) 'winst.lock')
}
