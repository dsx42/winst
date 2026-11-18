#Requires -Version 5.1

function Test-WinstPreparedCompanions {
    <#
    .SYNOPSIS
        在同一安装调用中确认之前预览的计划仍对应当前文件及附件落位。
    #>
    param($Info, $Plan)

    if (-not $Info -or -not $Info.Checked -or $Info.Error -or -not $Info.ContainsKey('Stamps') -or -not [object]::ReferenceEquals($Plan, $Info.Plan)) { return $false }
    foreach ($path in $Info.Stamps.Keys) {
        if ((Get-WinstFileStamp -Path $path) -cne $Info.Stamps[$path]) { return $false }
    }
    foreach ($landing in $Info.Landings) {
        if ((Test-WinstPathHasReparsePoint -Path $landing.Path -Root $landing.Root) -or
            (Test-Path -LiteralPath $landing.Path -PathType $landing.Type) -ne $landing.Exists) { return $false }
    }
    return $true
}
