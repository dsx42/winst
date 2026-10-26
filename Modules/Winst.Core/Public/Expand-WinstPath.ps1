#Requires -Version 5.1

function Expand-WinstPath {
    <#
    .SYNOPSIS
        展开 %VAR% 形式的环境变量；相对路径以数据根目录为基准解析，结果统一做 GetFullPath 归一化。
    .DESCRIPTION
        installRoot / pkgDir 允许手工写进 config.json（共享 U 盘 / NAS 上也可能被改），
        `..\..\Windows` 这类相对路径必须在这里就被折叠成绝对路径：调用方拿到的路径要么是绝对路径、
        要么是空串，避免「拼进 Join-WinstPath 后才发现越界」。
    #>
    param(
        [string]$Path,
        [string]$Base
    )

    if (-not $Path -or -not $Path.Trim()) { return '' }

    $expanded = [Environment]::ExpandEnvironmentVariables($Path.Trim())
    if ($Base -and -not [IO.Path]::IsPathRooted($expanded)) {
        $expanded = Join-WinstPath $Base $expanded
    }
    # 归一化：折叠 . / .. 与重复分隔符。GetFullPath 对非法形态会抛异常，此时原样返回，
    # 由下游的路径校验（Test-WinstSafePathSegment / Test-WinstPathUnderRoot）拒绝，绝不静默拼用。
    try { return [IO.Path]::GetFullPath($expanded) } catch { return $expanded }
}
