#Requires -Version 5.1

function Get-WinstFileStamp {
    <#
    .SYNOPSIS
        返回文件的「最后写入时间 + 长度」戳，用于判断缓存是否仍然有效；文件不存在返回空串。
    #>
    param([Parameter(Mandatory = $true)][string]$Path)

    try {
        $info = New-Object System.IO.FileInfo($Path)
        if (-not $info.Exists) { return '' }
        return ('{0}:{1}' -f $info.LastWriteTimeUtc.Ticks, $info.Length)
    } catch {
        return ''
    }
}
