#Requires -Version 5.1

function Read-WinstPause {
    <#
    .SYNOPSIS
        等用户按回车（不换行打印提示后读一行）。
    .DESCRIPTION
        各页共用的「按回车继续」提示；
        文案由调用方传入，输出保持原样。
    #>
    param([string]$Text = '  按回车键继续 …')

    Write-Host $Text -NoNewline -ForegroundColor DarkGray
    [void](Read-Host)
}
