#Requires -Version 5.1

function New-ResolvedFileItem {
    <#
    .SYNOPSIS
        构造解析锁中的下载文件条目（文件名缺省从 URL 推导；size 仅 magnet 源按 xl 提供）。
    #>
    param(
        [string]$Url,
        [string]$Name = '',
        [string]$Dest = '',
        [string]$Hash = '',
        [string]$HashFile = '',
        [string]$HashFrom = '',
        $Size = $null,
        [switch]$Extract,
        $StripTopDir = $null
    )

    $fileName = $Name
    if (-not $fileName) { $fileName = Get-FileNameFromUrl -Url $Url }

    $item = [ordered]@{
        url      = [string]$Url
        name     = $fileName
        dest     = [string]$Dest
        hash     = [string]$Hash
        hashFile = [string]$HashFile
        hashFrom = [string]$HashFrom
    }
    if ($null -ne $Size) { $item['size'] = $Size }
    if ($Extract) {
        # 附加文件是压缩包：安装时解压到 dest 指定的目录
        $item['extract'] = $true
        if ($null -ne $StripTopDir) { $item['stripTopDir'] = $StripTopDir }
    }
    return $item
}
