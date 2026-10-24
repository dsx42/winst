#Requires -Version 5.1

function Get-WinstSelectionErrorText {
    <#
    .SYNOPSIS
        把编号解析失败的原因变成一句提示（各输入循环共用，只有「回车 / b」尾部说明不同）。
    #>
    param(
        [Parameter(Mandatory = $true)]$Resolved,
        [Parameter(Mandatory = $true)][int]$Count,
        [string]$RangeText = '',
        [string]$Suffix = '（回车 = 取消）'
    )

    $range = $RangeText
    if (-not $range) { $range = '1 - {0}' -f $Count }
    if ($Resolved.OutOfRange) {
        return ('  没有这个编号（可选 {0}），请重新输入。' -f $range)
    }
    return ('  「{0}」不是编号，请输入 {1} 之间的数字{2}。' -f $Resolved.Bad, $range, $Suffix)
}
