#Requires -Version 5.1

function Test-WinstPathUnderAnyDir {
    <#
    .SYNOPSIS
        判断路径是否等于、或位于给定目录之一之下（区分目录边界，末尾分隔符两种写法等价）。
    .DESCRIPTION
        进程路径匹配专用：字符串 StartsWith 会把 `C:\App\7-Zip-beta\x.exe` 当成 `C:\App\7-Zip` 的子路径，
        从而误杀同族但不同目录的进程；这里先按目录边界补齐分隔符再比较。
    .OUTPUTS
        [bool]
    #>
    param(
        [string]$Path,
        [string[]]$Dirs = @()
    )

    $text = ([string]$Path).Trim().Trim('"')
    if (-not $text) { return $false }
    $textTrim = $text.TrimEnd('\', '/')
    foreach ($dir in @($Dirs)) {
        $one = ([string]$dir).Trim().Trim('"')
        if (-not $one) { continue }
        $oneTrim = $one.TrimEnd('\', '/')
        if (-not $oneTrim) { continue }
        if ($textTrim -ieq $oneTrim) { return $true }
        # 盘符根（C: / C:\）补回分隔符，否则前缀会退化成 "C:" 匹配整个盘
        if ($text.StartsWith($oneTrim + '\', [StringComparison]::OrdinalIgnoreCase)) { return $true }
    }
    return $false
}
