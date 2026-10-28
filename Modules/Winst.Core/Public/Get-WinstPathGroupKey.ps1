#Requires -Version 5.1

function Get-WinstPathGroupKey {
    <#
    .SYNOPSIS
        把「命中文件的路径」归一成「同一个产品」的比较键（抹掉路径里的版本目录）。
    .DESCRIPTION
        文件类检测靠路径区分版本：同一个产品的两个版本装在按版本命名的子目录里，
        `C:\Program Files\dotnet\shared\Microsoft.WindowsDesktop.App\10.0.13` 与
        `...\10.0.14` 只差版本目录。抹掉版本目录后两者相等，说明是同一产品的新旧两版；
        而 `Microsoft.NETCore.App\10.0.14` 抹完是另一个键——它确实是另一个产品。

        只抹「整段就是版本号」的路径段（`10.0.13` / `1.8.0_504`），不动 `Microsoft.WindowsDesktop.App`
        这类含点的产品目录名。短横线与下划线连接的单段版本（`v1.2.3`）同样识别。
    .OUTPUTS
        [string] 小写归一后的产品键
    #>
    param([string]$Path)

    $text = ([string]$Path).Trim()
    if (-not $text) { return '' }

    $segments = @($text -split '[\\/]')
    $kept = @()
    foreach ($segment in $segments) {
        if (-not $segment) { continue }
        # 整段是「可选 v + 纯数字段」（`10.0.13`、`v1.2.3`、`1.8.0.504`）：版本目录，抹掉。
        # 段里出现字母的（`1.8.0_504-b01`）不匹配，按普通目录保留。
        if ($segment -match '^[vV]?\d+(?:[._-]\d+)+$') { continue }
        $kept += $segment
    }

    # 最后一段可能是文件名（`coreclr.dll`）：保留，否则「同一目录下的两个文件」会被并成一组
    return ($kept -join '\').ToLowerInvariant()
}
