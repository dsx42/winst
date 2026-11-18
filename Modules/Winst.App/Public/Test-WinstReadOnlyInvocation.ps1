#Requires -Version 5.1

function Test-WinstReadOnlyInvocation {
    <#
    .SYNOPSIS
        根据正式命令行解析结果判断版本或帮助调用；无效参数不绕过实例锁。
    #>
    param([string[]]$Arguments = @(), $Parsed = $null)

    if ($null -eq $Parsed) { $Parsed = Read-WinstCommandLine -Tokens $Arguments }
    if ($parsed.Error) { return $false }
    return (Test-WinstReadOnlyCommand -Name ([string]$parsed.Command))
}
