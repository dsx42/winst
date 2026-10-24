#Requires -Version 5.1

function Get-WinstStripTopDirText {
    <#
    .SYNOPSIS
        把 stripTopDir 的三种写法（$true / $false / 字符串）转成一句可读说明。
    .DESCRIPTION
        portable 与 installer（installerExe 解压）共用这段判断。
    #>
    param($Install)

    $stripText = '去掉压缩包里最外层的文件夹'
    $stripRaw = Get-EntryValue -Entry $Install -Key 'stripTopDir' -Default $null
    if ($stripRaw -is [bool]) {
        if (-not $stripRaw) { $stripText = '原样解压，不做删减' }
    } elseif ($null -ne $stripRaw) {
        $stripText = ('只解压压缩包里的 "{0}"' -f ([string]$stripRaw))
    }
    return $stripText
}
