#Requires -Version 5.1

function Read-WinstRemoveRecordOnlyChoice {
    <#
    .SYNOPSIS
        交互式菜单：卸载程序用不了时，问一句「是否只移除安装记录」。
    .DESCRIPTION
        菜单里不能出现「请加 --force」这类命令行文案，因此就地询问。同意 → 只移除安装记录、不动电脑上的程序；
        不同意 → 返回假，由调用方按失败收尾。
    .OUTPUTS
        [bool]
    #>
    param(
        [Parameter(Mandatory = $true)][string]$Name,
        [string]$Reason = ''
    )

    Write-Host ''
    if ($Reason) {
        Write-Host ('  没能自动卸载 {0}（{1}）。' -f $Name, $Reason) -ForegroundColor DarkYellow
    } else {
        Write-Host ('  没能自动卸载 {0}。' -f $Name) -ForegroundColor DarkYellow
    }
    Write-Host '  如果这个软件已经手动卸载（或卸载程序本身缺失），可以只移除 winst 里的安装记录，不动电脑上的程序。' -ForegroundColor Gray
    return (Read-WinstConfirm -Prompt '  是否只移除安装记录？(y/N)' -Default 'n')
}
