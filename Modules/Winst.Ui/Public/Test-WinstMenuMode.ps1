#Requires -Version 5.1

function Test-WinstMenuMode {
    <#
    .SYNOPSIS
        当前是否运行在交互式菜单里（不带命令运行 winst 时的菜单层）。
    .DESCRIPTION
        菜单与命令行共用同一批业务函数（安装 / 更新 / 卸载都是），但提示文案不能共用：
        菜单里没有命令行的开关，「请加 --force」这类文案对菜单用户没有意义——菜单里紧接着就会问
        「是否强制重装」（见 Invoke-WinstInstallTarget）。凡是要区分的文案都走这里。
    .OUTPUTS
        [bool]
    #>
    return [bool](Get-WinstState -Name WinstMenuMode)
}
