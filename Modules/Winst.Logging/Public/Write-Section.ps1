#Requires -Version 5.1

function Write-Section {
    <#
    .SYNOPSIS
        输出统一风格的小节标题。
    #>
    param(
        [Parameter(Mandatory = $true)]
        [string]$Title
    )

    Write-Host ''
    Write-Host ('  ' + $Title) -ForegroundColor Cyan
    Write-Host ('  ' + ('-' * 40)) -ForegroundColor DarkGray
}
