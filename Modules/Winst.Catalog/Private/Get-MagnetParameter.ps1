#Requires -Version 5.1

function Get-MagnetParameter {
    <#
    .SYNOPSIS
        从 magnet URI 的查询串中读取参数值（如 dn / xl）。
    #>
    param(
        [string]$Uri,
        [Parameter(Mandatory = $true)]
        [string]$Name
    )

    if (-not $Uri) { return '' }
    $query = [string]$Uri
    $q = $query.IndexOf('?')
    if ($q -ge 0) { $query = $query.Substring($q + 1) }

    foreach ($pair in ($query -split '&')) {
        if (-not $pair) { continue }
        $eq = $pair.IndexOf('=')
        if ($eq -lt 0) { continue }
        if ($pair.Substring(0, $eq) -ieq $Name) { return $pair.Substring($eq + 1) }
    }
    return ''
}
