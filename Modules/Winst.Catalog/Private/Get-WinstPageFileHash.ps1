#Requires -Version 5.1

function Get-WinstPageFileHash {
    <#
    .SYNOPSIS
        从文件名所在页面条目提取摘要，归属不明确时由调用方报错。
    #>
    param([string]$Html, [string]$Url, [string]$Name = '')

    $fileName = ([string]$Name).Trim()
    if (-not $fileName) { $fileName = Get-FileNameFromUrl -Url $Url }
    $found = Get-WinstAdjacentFileHash -Text $Html -FileName $fileName
    if ($found.Ok) { return [string]$found.Hash }
    return ''
}
