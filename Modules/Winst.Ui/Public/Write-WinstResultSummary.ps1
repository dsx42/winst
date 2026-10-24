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
        [object[]]$Fields,
        [switch]$Quiet,
        [string]$Label = '汇总'
    )

    $parts = @()
    foreach ($field in @($Fields)) {
        $value = [int]$Result[$field.Key]
        # StrictMode 2 下直接读 $field.SkipZero，对没写该键的字段是终止性异常
        # （「检查更新 → 输入编号确认」走到汇总那一行就抛 PropertyNotFoundStrict，
        #  菜单窗口随即关闭）；可选键一律走安全读取。
        $skipZero = $false
        if ($field -is [System.Collections.IDictionary]) {
            if ($field.Contains('SkipZero')) { $skipZero = [bool]$field['SkipZero'] }
        } else {
            $skipProp = $field.PSObject.Properties['SkipZero']
            if ($skipProp) { $skipZero = [bool]$skipProp.Value }
        }
        if ($skipZero -and $value -le 0) { continue }
        $parts += ('{0} {1}' -f $field.Text, $value)
    }
    $color = 'Gray'
    if ([int]$Result['Failed'] -gt 0) { $color = 'Yellow' }
    if (-not $Quiet) { Write-Host ('  {0}: {1}' -f $Label, ($parts -join ' / ')) -ForegroundColor $color }
}
