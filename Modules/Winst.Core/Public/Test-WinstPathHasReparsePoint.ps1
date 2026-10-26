#Requires -Version 5.1

function Test-WinstPathHasReparsePoint {
    <#
    .SYNOPSIS
        判断 Root 到 Path 的现有路径链中是否含 junction / 符号链接；越界或无法解析时按不安全处理。
    #>
    param(
        [Parameter(Mandatory = $true)][string]$Path,
        [Parameter(Mandatory = $true)][string]$Root
    )

    $fullPath = ''
    $fullRoot = ''
    try {
        $fullPath = [IO.Path]::GetFullPath($Path)
        $fullRoot = [IO.Path]::GetFullPath($Root)
        # 盘根必须保留尾反斜杠：`D:` 表示当前驱动器工作目录，不等于 `D:\`。
        $rootOfRoot = [IO.Path]::GetPathRoot($fullRoot)
        if ($fullRoot -ine $rootOfRoot) { $fullRoot = $fullRoot.TrimEnd('\', '/') }
    } catch {
        return $true
    }
    if (-not (Test-WinstPathUnderRoot -Path $fullPath -Root $fullRoot -AllowEqual)) { return $true }
    if (Test-WinstReparsePoint -Path $fullRoot) { return $true }
    if ($fullPath.TrimEnd('\', '/') -ieq $fullRoot.TrimEnd('\', '/')) { return $false }

    $relative = $fullPath.Substring($fullRoot.Length).TrimStart('\', '/')
    $current = $fullRoot
    foreach ($segment in ($relative -split '[\\/]')) {
        if (-not $segment) { continue }
        $current = Join-WinstPath $current $segment
        if (-not (Test-Path -LiteralPath $current)) { break }
        if (Test-WinstReparsePoint -Path $current) { return $true }
    }
    return $false
}
