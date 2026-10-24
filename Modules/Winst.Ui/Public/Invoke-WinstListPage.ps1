#Requires -Version 5.1

function Invoke-WinstListPage {
    <#
    .SYNOPSIS
        三个列表页共用的过滤、分组、编号映射、页脚输入与返回动作循环。
    #>
    param(
        $Items,
        [Parameter(Mandatory = $true)][string]$SummaryText,
        [string]$SummaryColor = 'DarkGray',
        [Parameter(Mandatory = $true)][string]$EmptyText,
        [Parameter(Mandatory = $true)][string]$SelectHint,
        [string]$Prompt = '请选择',
        [string]$Filter = '',
        [Parameter(Mandatory = $true)][scriptblock]$RenderRow,
        [scriptblock]$RenderFooter = $null,
        [hashtable]$ExtraKeys = @{},
        [switch]$AllowMultiple
    )

    $all = @($Items)
    if ($all.Count -eq 0) { return @{ Action = 'empty'; Index = -1 } }
    $filterText = ''
    if ($null -ne $Filter) { $filterText = ([string]$Filter).Trim() }

    while ($true) {
        $visibleResult = Get-WinstVisibleListItems -Items $all -Filter $filterText
        $visible = @($visibleResult.Visible)
        $visibleIndexes = @($visibleResult.Indexes)

        Write-Host ''
        Write-Host ('  {0}' -f $SummaryText) -ForegroundColor $SummaryColor
        if ($filterText) {
            Write-Host ('  已按「{0}」过滤：命中 {1} / {2} 个（输入 f 清除过滤）' -f $filterText, $visible.Count, $all.Count) -ForegroundColor DarkYellow
        }
        if ($visible.Count -eq 0) { Write-Host ('  {0}' -f $EmptyText) -ForegroundColor DarkYellow }

        $hasGrouped = [bool](@($visible | Where-Object { [string]$_['Group'] }).Count)
        $lastGroup = ''
        for ($i = 0; $i -lt $visible.Count; $i++) {
            $item = $visible[$i]
            $lastGroup = Write-WinstGroupHeading -Group ([string]$item['Group']) -LastGroup $lastGroup -ShowUngrouped:$hasGrouped
            & $RenderRow $item ($i + 1)
        }

        Write-Host ('  {0}' -f $SummaryText) -ForegroundColor $SummaryColor
        if ($RenderFooter) { & $RenderFooter }
        Write-Host ('  {0}' -f $SelectHint) -ForegroundColor DarkGray
        if ($AllowMultiple) { Write-Host '  可一次输入多个编号（如 1 3 5）' -ForegroundColor DarkGray }
        if ($filterText) { Write-Host '  输入 f 清除过滤' -ForegroundColor DarkGray }
        Write-Host '  回车 / b = 返回，q = 退出程序' -ForegroundColor DarkGray

        $page = Read-WinstListPageInput -Prompt $Prompt -Count $visible.Count -Filter $filterText `
            -ExtraKeys $ExtraKeys -AllowMultiple:$AllowMultiple
        if ($page.Action -eq 'filter') { $filterText = $page.Filter; continue }
        if ($page.Action -ne 'select') { return @{ Action = $page.Action; Index = -1; Filter = $filterText } }

        $picked = @()
        foreach ($index in @($page.Indexes)) { $picked += [int]$visibleIndexes[$index] }
        if ($picked.Count -eq 1) {
            return @{ Action = 'select'; Index = $picked[0]; Filter = $page.Filter }
        }
        return @{ Action = 'select-multi'; Index = -1; Indexes = @($picked); Filter = $page.Filter }
    }
}
