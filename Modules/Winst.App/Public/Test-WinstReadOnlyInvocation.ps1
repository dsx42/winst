#Requires -Version 5.1

function Test-WinstReadOnlyInvocation {
    <#
    .SYNOPSIS
        另一份 winst 运行时，仍可用 -v、--version、version 查版本，用 -h、--help、-?、help、? 查看帮助。
        判断只读取全局参数解析结果及命令名。命令自己的参数由分派时校验。
    #>
    param($Parsed)

    if ($parsed.Error) { return $false }
    return (Test-WinstReadOnlyCommand -Name ([string]$parsed.Command))
}
