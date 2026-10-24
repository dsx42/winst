#Requires -Version 5.1

function ConvertTo-WinstTrimmedInput {
    <#
    .SYNOPSIS
        规范化用户输入（含粘贴内容）：去首尾空白、BOM、零宽字符与首尾成对引号。
    .DESCRIPTION
        从网页 / 文档复制地址时常带入引号或不可见字符，直接校验会误判为非法地址。
    #>
    param([string]$Value)

    if ($null -eq $Value) { return '' }
    $text = ([string]$Value).Trim()
    $text = $text.Trim([char]0xFEFF).Trim([char]0x200B).Trim()
    $text = $text -replace "[\u200B-\u200D\uFEFF]", ''
    $text = $text.Trim()

    while ($text.Length -ge 2) {
        $first = $text[0]
        $last = $text[$text.Length - 1]
        $paired = (($first -eq '"' -and $last -eq '"') -or ($first -eq "'" -and $last -eq "'") -or ($first -eq [char]0x201C -and $last -eq [char]0x201D))
        if (-not $paired) { break }
        $text = $text.Substring(1, $text.Length - 2).Trim()
    }
    return $text
}
