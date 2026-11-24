#Requires -Version 5.1

function Write-WinstResultSummary {
    <#
    .SYNOPSIS
        打印「汇总: a / b / c」一行（失败时黄色）。
    .DESCRIPTION
        更新、下载更新包、一键下载共用同一份汇总输出，由 Fields 描述字段顺序。
    .PARAMETER Fields
        @( @{ Key = 'Updated'; Text = '已更新' }, @{ Key = 'Failed'; Text = '失败' } )；
        SkipZero = $true 时该字段为 0 不输出。
    #>
    param(
        [hashtable]$Result,
        [object[]]$Fields
    )

    $parts = @()
    foreach ($field in @($Fields)) {
        $value = [int]$Result[$field.Key]
        if ((Get-EntryBool -Entry $field -Key 'SkipZero') -and $value -le 0) { continue }
        $parts += ('{0} {1}' -f $field.Text, $value)
    }
    $color = 'Gray'
    if ([int]$Result['Failed'] -gt 0) { $color = 'Yellow' }
    Write-Host ('  汇总: {0}' -f ($parts -join ' / ')) -ForegroundColor $color
}
