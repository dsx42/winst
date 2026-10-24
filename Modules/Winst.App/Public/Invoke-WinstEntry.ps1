#Requires -Version 5.1

function Invoke-WinstEntry {
    <#
    .SYNOPSIS
        脚本主入口：不带命令时进入交互式菜单，带命令时按命令行执行。
    .OUTPUTS
        [int] 退出码（菜单正常返回 0）
    #>
    param([string[]]$Arguments = @())

    $parsed = Read-WinstCommandLine -Tokens $Arguments
    if ($parsed.Error) {
        Write-Host ('  {0}' -f $parsed.Error) -ForegroundColor Yellow
        return 1
    }

    # $null = ：Set-WinstState 会返回存入的值。不接住的话该值会漏进函数输出流，
    # 调用方拿到的就是数组而不是退出码。
    $null = Set-WinstState -Name WinstOptions -Value ($parsed.Options)

    # 不带命令 → 交互式菜单；带命令 / 带 -h、--version 等 → 走命令行分发
    if (-not $parsed.Command -and @($parsed.Arguments).Count -eq 0) {
        Invoke-MainMenu
        return 0
    }
    return (Invoke-WinstCommand -Command $parsed.Command -Arguments $parsed.Arguments)
}
