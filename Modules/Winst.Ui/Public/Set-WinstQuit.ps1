#Requires -Version 5.1

function Set-WinstQuit {
    <#
    .SYNOPSIS
        标记「用户要求退出程序」，由 Invoke-MenuLoop 逐层向上传播。
    .DESCRIPTION
        退出请求统一走此入口，调用方通过状态查询决定结束当前流程，
        不必逐点查找。
    #>
    $null = Set-WinstState -Name WinstQuitRequested -Value ($true)
}
