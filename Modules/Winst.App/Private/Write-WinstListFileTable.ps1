#Requires -Version 5.1

function Write-WinstListFileTable {
    <#
    .SYNOPSIS
        CLI 用：列出 lists 目录下的全部清单文件（无参数时 `bundle list` 的输出）。
    #>
    param([Parameter(Mandatory = $true)][hashtable]$Context)

    $kindText = (Get-WinstListKindText)

    $files = @(Get-WinstListFiles -Context $Context)
    Write-Host ''
    if ($files.Count -eq 0) {
        Write-Host ('  lists 目录里还没有{0}。' -f $kindText) -ForegroundColor Yellow
        Write-Host ('  清单目录: {0}' -f (Get-WinstListsDir -Context $Context)) -ForegroundColor DarkGray
        Write-Host '  可用 winst bundle edit 新建。' -ForegroundColor DarkGray
        return 0
    }

    Write-WinstListFileRows -Files $files -Indent '  ' -Color 'Gray'
    Write-Host ''
    Write-Host '  查看某一份: winst bundle list <文件名>' -ForegroundColor DarkGray
    return 0
}
