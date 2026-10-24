#Requires -Version 5.1

function Clear-WinstJsonCache {
    <#
    .SYNOPSIS
        失效进程内 JSON 解析缓存（不给 Path 时清空全部）。
    .DESCRIPTION
        写入侧唯一入口是 Write-FileAtomic，因此写文件后会自动失效；
        手工改文件（外部编辑器）由 (LastWriteTimeUtc, Length) 复核兜底，不需要调用方操心。
    #>
    param([string]$Path)

    if (-not (Get-WinstState -Name WinstJsonCache)) { return }
    if (-not $Path) { (Get-WinstState -Name WinstJsonCache).Clear(); return }
    try {
        (Get-WinstState -Name WinstJsonCache).Remove([string]$Path)
        # 缓存索引把「整个 Read-WinstCacheIndex 结果」挂在派生键下，写索引文件时一并失效
        (Get-WinstState -Name WinstJsonCache).Remove('cache-index|' + [string]$Path)
    } catch { }
}
