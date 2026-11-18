#Requires -Version 5.1

function Test-WinstKeepMatch {
    <#
    .SYNOPSIS
        keep 规则是否命中某个安装目录内的条目（相对路径或文件名任一命中即保留）。
    .DESCRIPTION
        `**` = 跨目录任意多字符；`*` = 单个目录层级内任意多字符；`?` = 单字符；其余为字面量。
        未写目录分隔符时对「文件名」匹配（含义是「在哪一层都保留」）。
    #>
    param([string]$RelativePath, [string]$Name, $Rules)

    foreach ($rule in $Rules) {
        if ($rule.Regex.IsMatch($RelativePath) -or ($rule.MatchName -and $rule.Regex.IsMatch($Name))) { return $true }
    }
    return $false
}
