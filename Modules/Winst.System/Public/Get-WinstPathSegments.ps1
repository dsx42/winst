#Requires -Version 5.1

function Get-WinstPathSegments {
    <#
    .SYNOPSIS
        按引号外的分号拆分 PATH，保留原始引号、空白与空段。
    #>
    param([string]$Value)

    if (-not $Value) { return @() }
    $segments = New-Object 'System.Collections.Generic.List[string]'
    $quoted = $false
    $start = 0
    for ($i = 0; $i -lt $Value.Length; $i++) {
        if ($Value[$i] -eq '"') { $quoted = -not $quoted }
        if ($Value[$i] -eq ';' -and -not $quoted) {
            $segments.Add($Value.Substring($start, $i - $start))
            $start = $i + 1
        }
    }
    if ($quoted) { throw 'PATH 中的引号未闭合，已拒绝重新写入' }
    $segments.Add($Value.Substring($start))
    return $segments.ToArray()
}
