#Requires -Version 5.1

function Show-WinstSearchRows {
    <#
    .SYNOPSIS
        展示搜索结果（每行一个 id，列出各软件源与版本、是否已安装）；**不分页**，一次全部列出。
    .DESCRIPTION
        列表规模 = 一次搜索的命中数，分页只会让人多点几次 n / p 才看到全貌，因此直接列完；
        统计信息（共多少个）在列表顶部与底部各给一份，滚到列表末尾也能看到规模。
    .OUTPUTS
        [int[]] 用户选择的编号（未选择返回空数组）
    #>
    param(
        $Rows,
        [hashtable]$State = $null, [hashtable]$Context
    )

    $rows = @($Rows)
    if ($rows.Count -eq 0) { return @() }

    while ($true) {
        Write-Host ''
        $summaryText = ('共 {0} 个软件' -f $rows.Count)
        Write-Host ('  {0}' -f $summaryText) -ForegroundColor DarkGray
        $hasGrouped = [bool](@($rows | Where-Object { [string]$_['Group'] }).Count)
        $cacheIndex = (Read-WinstCacheIndex -PkgDir $Context.PkgDir).Index
        $lastGroup = ''
        for ($i = 0; $i -lt $rows.Count; $i++) {
            $row = $rows[$i]
            $lastGroup = Write-WinstGroupHeading -Group ([string]$row['Group']) -LastGroup $lastGroup -ShowUngrouped:$hasGrouped
            $view = Get-WinstSearchRowView -Row $row -State $State -Context $Context -CacheIndex $cacheIndex
            Write-WinstSearchRow -Item $view -Number ($i + 1)
        }

        # 底部再给一份统计（与顶部同一句），滚到列表末尾不用翻回顶部
        Write-Host ('  {0}' -f $summaryText) -ForegroundColor DarkGray
        Write-Host '  输入编号选择（可多选，如 1 3 5）；回车 = 取消' -ForegroundColor DarkGray

        $text = Read-WinstAnswerText -Prompt '  请选择'

        if (-not $text) { return @() }

        $selection = @(Read-WinstSelectionFrom -Text $text -Count $rows.Count)
        if ($selection.Count -gt 0) { return @($selection) }
        # 越界 / 非数字说清原因再问一次
        if ($text -match '^\d+$') {
            Write-Host ('  没有这个编号（可选 1 - {0}），请重新输入。' -f $rows.Count) -ForegroundColor Yellow
        } else {
            Write-Host ('  「{0}」不是编号，请输入 1 - {1} 之间的数字（回车 = 取消）。' -f $text, $rows.Count) -ForegroundColor Yellow
        }
    }
}
