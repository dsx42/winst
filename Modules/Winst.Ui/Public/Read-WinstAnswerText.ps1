#Requires -Version 5.1

function Read-WinstAnswerText {
    <#
    .SYNOPSIS
        读一行交互输入并归一化（null 安全、去首尾空格，可按需转小写）。
    .OUTPUTS
        [string] 空串表示用户直接回车
    #>
    param(
        [string]$Prompt,
        [switch]$Lower
    )

    $answer = Read-Host $Prompt
    if ($null -eq $answer) { return '' }
    $text = ([string]$answer).Trim()
    if ($Lower) { return $text.ToLowerInvariant() }
    return $text
}
