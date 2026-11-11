#Requires -Version 5.1

function Read-WinstCommandState {
    <#
    .SYNOPSIS
        命令边界读取台账：无法安全读取时停止，安全重置时先提示。
    #>
    param([hashtable]$Context)

    $read = Read-WinstState -InstallRoot $Context.InstallRoot
    if ($read.Error -and -not $read.Reset) { throw ([string]$read.Error) }
    if ($read.Error) { Write-Host ('  提示: {0}' -f $read.Error) -ForegroundColor DarkYellow }
    return $read.State
}
