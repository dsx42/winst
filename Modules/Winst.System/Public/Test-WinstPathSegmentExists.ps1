#Requires -Version 5.1

function Test-WinstPathSegmentExists {
    <#
    .SYNOPSIS
        PATH 里是否已有该项（按未展开的原始项逐字比较，不区分大小写）。
    #>
    param([string[]]$Segments, [string]$Value)

    foreach ($segment in @($Segments)) {
        if (([string]$segment).Trim().Trim('"') -ieq ([string]$Value).Trim()) { return $true }
    }
    return $false
}
