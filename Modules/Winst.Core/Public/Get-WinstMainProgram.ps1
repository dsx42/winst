#Requires -Version 5.1

function Get-WinstMainProgram {
    <#
    .SYNOPSIS
        条目的主程序相对路径（portable = mainExe；exe = 主包落位文件 / 改名结果）。
    #>
    param($Plan, [string]$InstallDir = '')

    $install = Get-EntryValue -Entry $Plan -Key 'install' -Default $null
    $method = ConvertTo-WinstEntryType -Type (Get-EntryString -Entry $install -Key 'method')
    if ($method -eq 'portable' -or $method -eq 'file') {
        return (Get-EntryString -Entry $install -Key 'mainExe')
    }
    return ''
}
