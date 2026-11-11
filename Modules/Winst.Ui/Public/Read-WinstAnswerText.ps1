#Requires -Version 5.1

function Read-WinstAnswerText {
    <#
    .SYNOPSIS
        读一行交互输入并归一化；重定向、EOF 或读取异常返回 $null。
    .OUTPUTS
        [string] 空串表示交互回车；$null 表示未取得输入。
    #>
    param(
        [string]$Prompt,
        [switch]$Lower
    )

    if (Test-WinstInputRedirected) { return $null }
    try { $answer = Read-Host $Prompt } catch { return $null }
    if ($null -eq $answer) { return $null }
    $text = ([string]$answer).Trim()
    if ($Lower) { return $text.ToLowerInvariant() }
    return $text
}
