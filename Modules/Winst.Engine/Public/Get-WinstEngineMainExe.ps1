#Requires -Version 5.1

function Get-WinstEngineMainExe {
    <#
    .SYNOPSIS
        引擎条目的主程序（相对安装目录）；非引擎 id 返回空串。
    #>
    param([string]$Id)
    # 引擎 id 来自软件源 / 台账，大小写不一定与常量一致（如清单写 7-zip-cli）→ 必须忽略大小写比较
    if ($Id -eq (Get-WinstExtractEngineId)) { return (Get-WinstExtractEngineExe) }
    if ($Id -eq (Get-WinstDownloadEngineId)) { return (Get-WinstDownloadEngineExe) }
    return ''
}
