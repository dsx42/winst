#Requires -Version 5.1

function Get-WinstMainProgram {
    <#
    .SYNOPSIS
        从 portable 或 file 类型的安装计划读取主程序相对路径 install.mainExe。
    #>
    param($Plan)

    $install = Get-EntryValue -Entry $Plan -Key 'install' -Default $null
    $method = ConvertTo-WinstEntryType -Type (Get-EntryString -Entry $install -Key 'method')
    if ($method -eq 'portable' -or $method -eq 'file') {
        return (Get-EntryString -Entry $install -Key 'mainExe')
    }
    return ''
}
