#Requires -Version 5.1

function Get-WinstCommandLineQuoteState {
    <#
    .SYNOPSIS
        按 Windows 命令行反斜杠 / 双引号规则判断文本末尾是否仍位于引号内。
    #>
    param([string]$Text)

    $inside = $false
    $slashes = 0
    foreach ($ch in ([string]$Text).ToCharArray()) {
        if ($ch -eq '\') { $slashes++; continue }
        if ($ch -eq '"' -and (($slashes % 2) -eq 0)) { $inside = -not $inside }
        $slashes = 0
    }
    return $inside
}
