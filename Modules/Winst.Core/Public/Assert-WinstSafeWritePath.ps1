#Requires -Version 5.1

function Assert-WinstSafeWritePath {
    <#
    .SYNOPSIS
        写入前校验目标路径的完整现有路径链，拒绝经过重解析点；目录同时拒绝受保护位置。
    #>
    param([Parameter(Mandatory = $true)][string]$Path, [switch]$Directory)

    $full = [IO.Path]::GetFullPath($Path)
    if (($Directory -and (Test-WinstProtectedDirectory -Path $full)) -or
        (Test-WinstPathHasReparsePoint -Path $full -Root ([IO.Path]::GetPathRoot($full)))) {
        throw ('拒绝写入受保护位置或经过重解析点的路径：{0}' -f $Path)
    }
}
