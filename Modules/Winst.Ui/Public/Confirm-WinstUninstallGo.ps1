#Requires -Version 5.1

function Confirm-WinstUninstallGo {
    <#
    .SYNOPSIS
        卸载前的门槛：预览模式直接返回；否则显示 y 确认提示并要求输入。
    .OUTPUTS
        @{ Proceed; Preview }
    #>
    param([switch]$DryRun, [switch]$Yes, [switch]$SkipConfirm)

    if ($DryRun) {
        Write-Host ''
        Write-Host '  预览模式：未做任何修改。' -ForegroundColor DarkYellow
        return @{ Proceed = $false; Preview = $true }
    }

    if (-not $Yes -and -not $SkipConfirm) {
        Write-Host ''
        Write-Host '  y) 确认卸载' -ForegroundColor White
        Write-Host '  回车 / 其它任意输入 = 取消' -ForegroundColor DarkGray
        $text = Read-WinstAnswerText -Prompt '  请输入（y = 继续）'

        if ($text -notmatch '^(?i)y(es)?$') {
            Write-Host '  已取消。' -ForegroundColor DarkGray
            return @{ Proceed = $false; Preview = $false }
        }
    }

    return @{ Proceed = $true; Preview = $false }
}
