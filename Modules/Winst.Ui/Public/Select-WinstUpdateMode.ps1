#Requires -Version 5.1

function Select-WinstUpdateMode {
    <#
    .SYNOPSIS
        单独选择本次的更新方式（「单独选更新方式与软件源」的第一步）。
    .DESCRIPTION
        回车 / `b` = 不改本次方式，按「设置 → 更新方式」里的默认方式继续更新（调用方据此回退），
        所以提示行写的是「回车 / b = 不改，按默认方式更新」——不能让用户以为「取消 = 不更新了」。
        `q` 是退出整个程序（Set-WinstQuit），同样返回 Cancelled 由调用方停止后续动作。
        非法输入重新提示，不当作取消。
    .OUTPUTS
        @{ Ok; Cancelled; Mode }  Mode = 'keep' | 'full'
    #>
    param()

    Write-Host ''
    Write-Host '  本次用哪种更新方式？' -ForegroundColor Gray
    Write-Host '    1) 只更新文件    ' -NoNewline -ForegroundColor White
    Write-Host '只替换文件；环境变量 / PATH 保持原样，快捷方式只修正不新建  ← 默认' -ForegroundColor DarkGray
    Write-Host '    2) 完整更新      ' -NoNewline -ForegroundColor White
    Write-Host '按软件源里的定义覆盖已存在的环境变量 / 快捷方式' -ForegroundColor DarkGray
    Write-Host ''
    while ($true) {
        $text = Read-WinstAnswerText -Prompt '  请输入编号（回车 / b = 不改，按默认方式更新）'

        if (-not $text -or $text -ieq 'b') { return @{ Ok = $false; Cancelled = $true; Mode = '' } }
        if ((Test-WinstQuitKey -Text $text)) { Set-WinstQuit; return @{ Ok = $false; Cancelled = $true; Mode = '' } }
        if ($text -eq '1') { return @{ Ok = $true; Cancelled = $false; Mode = 'keep' } }
        if ($text -eq '2') { return @{ Ok = $true; Cancelled = $false; Mode = 'full' } }
        Write-Host '  请输入 1 或 2（回车 / b = 不改，按默认方式更新）。' -ForegroundColor Yellow
    }
}
