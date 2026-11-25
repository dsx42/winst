#Requires -Version 5.1

function Format-WinstDownloadSizeText {
    <#
    .SYNOPSIS
        显示文件下载总大小，未知长度与零字节分别显示。
    #>
    param($Size)

    $bytes = 0L
    if (([string]$Size).Trim() -match '\A[0-9]+\z' -and [long]::TryParse([string]$Size, [ref]$bytes)) {
        return Format-WinstSizeText -Bytes $bytes
    }
    return '大小未知'
}
