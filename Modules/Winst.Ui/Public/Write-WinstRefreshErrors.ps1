#Requires -Version 5.1

function Write-WinstRefreshErrors {
    <#
    .SYNOPSIS
        统一打印软件源刷新过程中的提示。
    #>
    param($Errors)

    foreach ($errorText in @($Errors)) {
        Write-Host ('  提示: {0}' -f $errorText) -ForegroundColor DarkYellow
    }
}
