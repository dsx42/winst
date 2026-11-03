#Requires -Version 5.1

function Get-WinstCompanionLayoutSignature {
    <#
    .SYNOPSIS
        将附加文件的落位声明整理成稳定文本，供更新判定与安装记账共用。
    #>
    param($File)

    $dest = (Get-EntryString -Entry $File -Key 'dest').Trim().Replace('/', '\')
    $strip = Get-EntryValue -Entry $File -Key 'stripTopDir' -Default $false
    if ($null -eq $strip) { $strip = $false }
    return (ConvertTo-WinstJson -InputObject ([ordered]@{
        dest = $dest
        extract = [bool](Get-EntryBool -Entry $File -Key 'extract')
        stripTopDir = $strip
    }))
}
