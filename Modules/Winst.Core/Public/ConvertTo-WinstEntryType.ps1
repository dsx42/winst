#Requires -Version 5.1

function ConvertTo-WinstEntryType {
    <#
    .SYNOPSIS
        条目类型名归一：把类型名统一为小写规范写法。
    .DESCRIPTION
        `exe` 与 `file` 同义，都表示「安装动作 = 复制一个文件」，与文件格式无关
        （.ps1 / .jar / .exe 都适用）。清单、解析锁、安装记录里出现 `exe` 时一律按 `file` 处理。
    #>
    param([string]$Type)

    $text = ([string]$Type).Trim().ToLowerInvariant()
    if ($text -eq 'exe') { return 'file' }
    return $text
}
