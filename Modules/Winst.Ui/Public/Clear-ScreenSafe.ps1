#Requires -Version 5.1

function Clear-ScreenSafe {
    <#
    .SYNOPSIS
        安全清屏：非交互宿主（重定向 / 部分 IDE 宿主）中清屏可能失败，失败即忽略。
    #>
    try {
        Clear-Host
    } catch {
        # 忽略清屏失败
    }
}
