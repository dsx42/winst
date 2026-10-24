#Requires -Version 5.1

function Get-WinstForceHint {
    <#
    .SYNOPSIS
        「这一步需要 --force 才能继续」的提示后缀（只在命令行侧给出）。
    .DESCRIPTION
        交互式菜单里返回空串：跳过原因后面紧跟着菜单的「是否强制重装（忽略上面的检查，覆盖安装）？」
        询问（见 Invoke-WinstInstallTarget），用户不需要知道命令行开关。
    .OUTPUTS
        [string]
    #>
    param([ValidateSet('downgrade', 'continue')][string]$Kind = 'downgrade')

    if (Test-WinstMenuMode) { return '' }
    if ($Kind -eq 'downgrade') { return '；如需降级请加 --force' }
    return '；如需继续请加 --force'
}
