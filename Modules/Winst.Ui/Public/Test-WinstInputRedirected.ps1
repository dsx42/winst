#Requires -Version 5.1

function Test-WinstInputRedirected {
    <#
    .SYNOPSIS
        判断当前宿主的标准输入是否被重定向（非交互，如管道 / 计划任务 / 无控制台宿主）。
    #>
    try {
        return [Console]::IsInputRedirected
    } catch {
        return $false
    }
}
