#Requires -Version 5.1

function Get-WinstRegistryEntryInstallDir {
    <#
    .SYNOPSIS
        从系统安装记录（注册表卸载项）解析实际安装目录；记录里没有可用路径时返回空串。
    .DESCRIPTION
        依次尝试：① InstallLocation；② 卸载命令（UninstallString）里那个程序的所在目录；
        ③ 图标路径（DisplayIcon）的所在目录——很多安装器不写 InstallLocation，但卸载程序 / 图标就在安装目录里。
        推出来的目录必须真实存在，避免把卸载残留的死路径写进安装记录。
    #>
    param($Entry)

    if (-not $Entry) { return '' }

    $location = ConvertTo-WinstDirPath -Text (Get-EntryString -Entry $Entry -Key 'InstallLocation')
    if ($location) { return $location }

    foreach ($key in @('UninstallString', 'DisplayIcon')) {
        $text = (Get-EntryString -Entry $Entry -Key $key).Trim()
        if (-not $text) { continue }
        # DisplayIcon 常见写法是 "<程序路径>,0"：先把图标序号后缀去掉
        if ($text -match '^(.*?)\s*,\s*-?\d+\s*$') { $text = $Matches[1].Trim() }
        $value = ''
        if ($text.StartsWith('"')) {
            $end = $text.IndexOf('"', 1)
            if ($end -gt 1) { $value = $text.Substring(1, $end - 1) }
        } else {
            # 没加引号：取到第一个空格之前（后面跟的是命令行参数）
            $value = $text
            $spaceIndex = $value.IndexOf(' ')
            if ($spaceIndex -gt 0) { $value = $value.Substring(0, $spaceIndex) }
        }
        $path = ConvertTo-WinstDirPath -Text $value
        if (-not $path) { continue }
        $dir = ''
        if (Test-Path -LiteralPath $path -PathType Container) {
            $dir = $path                                      # 记录里直接写的就是目录
        } else {
            $parent = ConvertTo-WinstDirPath -Text (Split-Path -Parent $path)
            # MsiExec.exe /X{GUID} 这类命令取不到目录；目录已不存在（卸载残留）也不采用
            if ($parent -and $parent -ne $path -and (Test-Path -LiteralPath $parent -PathType Container)) { $dir = $parent }
        }
        if ($dir) { return $dir }
    }
    return ''
}
