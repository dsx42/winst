#Requires -Version 5.1

function Get-WinstChildItem {
    <#
    .SYNOPSIS
        枚举长路径目录中的全部条目，可只输出文件或递归枚举；不跟随重解析目录。
    .DESCRIPTION
        包含隐藏和系统条目。递归时遇到重解析点立即报错，非递归时返回链接本身。
        返回与 Get-WinstFileSystemItem 相同的普通路径元数据对象。
    #>
    [CmdletBinding()]
    param([Parameter(Mandatory = $true)][string]$Path, [switch]$File, [switch]$Recurse)

    $pending = New-Object 'System.Collections.Generic.Stack[string]'
    $pending.Push($Path)
    while ($pending.Count -gt 0) {
        $directory = Get-WinstFileSystemItem -Path $pending.Pop()
        if (-not $directory.PSIsContainer) { throw ('枚举路径不是目录：{0}' -f $directory.FullName) }
        if (($directory.Attributes -band [IO.FileAttributes]::ReparsePoint) -ne 0) {
            throw ('拒绝枚举重解析目录：{0}' -f $directory.FullName)
        }
        $extended = $directory.ExtendedPath
        foreach ($childPath in [IO.Directory]::EnumerateFileSystemEntries($extended)) {
            $child = Get-WinstFileSystemItem -Path $childPath
            if ($Recurse -and ($child.Attributes -band [IO.FileAttributes]::ReparsePoint) -ne 0) {
                throw ('目录树含有重解析点，已拒绝处理：{0}' -f $child.FullName)
            }
            if (-not $File -or -not $child.PSIsContainer) { $child }
            if ($Recurse -and $child.PSIsContainer) { $pending.Push($child.FullName) }
        }
    }
}
