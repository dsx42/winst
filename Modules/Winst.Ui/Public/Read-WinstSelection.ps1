#Requires -Version 5.1

function Read-WinstSelection {
    <#
    .SYNOPSIS
        读取用户选择的编号（空格 / 逗号分隔，可多选）；直接回车返回空数组（= 取消）。
    .DESCRIPTION
        越界 / 非数字都说清原因并重新提示，不把非法输入当成取消：
        只有显式回车才算取消，用户可以改一个编号接着选。
    #>
    param(
        [Parameter(Mandatory = $true)][int]$Count,
        [switch]$Single
    )

    while ($true) {
        $answer = Read-Host '  请输入编号（直接回车取消）'
        if ($null -eq $answer -or -not ([string]$answer).Trim()) { return @() }

        $resolved = Resolve-WinstSelectionText -Text ([string]$answer) -Count $Count
        if (-not $resolved.Ok) {
            Write-Host (Get-WinstSelectionErrorText -Resolved $resolved -Count $Count) -ForegroundColor Yellow
            continue
        }
        $pick = @($resolved.Numbers)
        if ($Single -and $pick.Count -gt 1) {
            Write-Host '  这里只能选一个编号，请重新输入。' -ForegroundColor Yellow
            continue
        }
        return @($pick)
    }
}
