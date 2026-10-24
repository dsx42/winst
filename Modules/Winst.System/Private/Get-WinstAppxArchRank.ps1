#Requires -Version 5.1

function Get-WinstAppxArchRank {
    <#
    .SYNOPSIS
        应用包架构的优先级：x64 / 中性最高，其次 x86，其它最低（同版本时用它取舍）。
    #>
    param([string]$Architecture)

    $text = ''
    if ($null -ne $Architecture) { $text = ([string]$Architecture).Trim().ToUpperInvariant() }
    switch ($text) {
        'X64'     { return 3 }
        'NEUTRAL' { return 3 }
        'X86'     { return 2 }
        default   { return 1 }
    }
}
