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
    if (@($Errors).Count -gt 0) {
        Write-Host '  本次软件源刷新未全部成功；展示结果可能包含缓存，不能据此确认远端已是最新。' -ForegroundColor DarkYellow
    }
}
