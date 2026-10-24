#Requires -Version 5.1

function Set-WinstQuit {
    <#
    .SYNOPSIS
        标记「用户要求退出程序」，由 Invoke-MenuLoop 逐层向上传播。
    .DESCRIPTION
        WinstQuitRequested 有 18 个写入点，统一走这里：改成别的传播方式时只需改这一处，
        不必逐点查找。
    #>
    $null = Set-WinstState -Name WinstQuitRequested -Value ($true)
}
