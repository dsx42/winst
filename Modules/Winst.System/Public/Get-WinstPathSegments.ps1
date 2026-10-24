#Requires -Version 5.1

function Get-WinstPathSegments {
    <#
    .SYNOPSIS
        拆分 PATH 值（去掉空白与包裹引号，保持原样不做展开）。
    #>
    param([string]$Value)

    $segments = @()
    if ($null -eq $Value) { return $segments }
    foreach ($part in ([string]$Value -split ';')) {
        $text = $part.Trim().Trim('"')
        if ($text) { $segments += $text }
    }
    return $segments
}
