#Requires -Version 5.1

function Test-WinstPathLikeKeyword {
    <#
    .SYNOPSIS
        判断输入的关键字是不是「文件路径 / 命令行」而不是软件名称。
    .DESCRIPTION
        控制台里混进来的路径或命令行（典型来源：目标软件自己往控制台写的内容、用户顺手复制粘贴进来）
        拿去搜索必然零命中，只会得到一句莫名其妙的「没有找到和「…」有关的软件」；这里先认出来，
        由调用方给出明确提示后重新输入。判定只看「有没有路径形状」：
        盘符开头、路径分隔符开头（`\` / `/` / `.\` / `..\`）、含反斜杠、以可执行 / 快捷方式扩展名结尾。
    .OUTPUTS
        [bool]
    #>
    param([string]$Text)

    $value = ''
    if ($null -ne $Text) { $value = ([string]$Text).Trim() }
    if (-not $value) { return $false }

    if ($value -match '^[A-Za-z]:[\\/]') { return $true }        # C:\…  /  D:/…
    if ($value -match '^(\.{1,2})?[\\/]') { return $true }       # \…  /…  .\…  ../…
    if ($value.Contains('\')) { return $true }                   # 含反斜杠（软件名 / id 里不会出现）
    if ($value -match '(?i)\.(exe|cmd|bat|ps1|lnk|msi)$') { return $true }
    return $false
}
