#Requires -Version 5.1

function Test-WinstKeepMatch {
    <#
    .SYNOPSIS
        keep 规则是否命中某个安装目录内的条目（相对路径或文件名任一命中即保留）。
    .DESCRIPTION
        `**` = 跨目录任意多字符；`*` = 单个目录层级内任意多字符；`?` = 单字符；其余为字面量。
        未写目录分隔符时对「文件名」匹配（含义是「在哪一层都保留」）。
    #>
    param([string]$RelativePath, [string]$Name, [string[]]$Keep)

    $path = ''
    if ($null -ne $RelativePath) { $path = ([string]$RelativePath).Replace('/', '\').Trim('\') }
    $leaf = ''
    if ($null -ne $Name) { $leaf = [string]$Name }
    if (-not $leaf -and $path) {
        $index = $path.LastIndexOf('\')
        if ($index -ge 0) { $leaf = $path.Substring($index + 1) } else { $leaf = $path }
    }
    if (-not $path -and -not $leaf) { return $false }

    foreach ($item in @($Keep)) {
        $pattern = ([string]$item).Trim().Replace('/', '\').Trim('\')
        if (-not $pattern) { continue }

        $regexText = ''
        $i = 0
        while ($i -lt $pattern.Length) {
            $ch = $pattern[$i]
            if ($ch -eq '*') {
                if (($i + 1) -lt $pattern.Length -and $pattern[$i + 1] -eq '*') {
                    $regexText += '.*'
                    $i += 2
                    continue
                }
                $regexText += '[^\\]*'
            } elseif ($ch -eq '?') {
                $regexText += '[^\\]'
            } else {
                $regexText += [regex]::Escape([string]$ch)
            }
            $i++
        }

        $hasSeparator = $pattern.Contains('\')
        try {
            if ($path -and [regex]::IsMatch($path, '^' + $regexText + '$', [Text.RegularExpressions.RegexOptions]::IgnoreCase)) { return $true }
            if (-not $hasSeparator -and $leaf -and [regex]::IsMatch($leaf, '^' + $regexText + '$', [Text.RegularExpressions.RegexOptions]::IgnoreCase)) { return $true }
        } catch {
            continue
        }
    }
    return $false
}
