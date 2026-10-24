#Requires -Version 5.1

function Show-WinstListPickRows {
    <#
    .SYNOPSIS
        清单编辑页：展示软件源里的全部软件（**不分页**，一次全部列出），输入编号切换选中（可多选），支持关键字过滤。
    .DESCRIPTION
        与 Show-WinstSearchRows（选一次就返回）不同，本函数**每次切换选中后重新渲染**，
        由调用方（Invoke-WinstListEditFlow）循环消费返回的 Action：
          toggle —— 本次切换了这些 id，继续循环；
          save   —— 直接回车，保存；
          cancel —— c，放弃；
          quit   —— q，退出程序。
        统计信息（软件源共多少个 / 过滤命中多少个 / 已选中多少个）在列表顶部与底部各给一份。
    .OUTPUTS
        @{ Action; Ids; Filter }
    #>
    param(
        $Rows,
        [hashtable]$Selected = $null,
        [string]$Filter = '',
        [string]$Title = ''
    )

    $all = @($Rows)
    if (-not $Selected) { $Selected = New-WinstOrdinalDictionary }

    $filterText = ''
    if ($null -ne $Filter) { $filterText = ([string]$Filter).Trim() }

    while ($true) {
        $visible = @()
        if ($filterText) {
            foreach ($row in $all) {
                $hit = ([string]$row['Id']).IndexOf($filterText, [StringComparison]::OrdinalIgnoreCase) -ge 0
                if (-not $hit) { $hit = ([string]$row['Name']).IndexOf($filterText, [StringComparison]::OrdinalIgnoreCase) -ge 0 }
                if (-not $hit) { $hit = ([string]$row['Description']).IndexOf($filterText, [StringComparison]::OrdinalIgnoreCase) -ge 0 }
                if ($hit) { $visible += $row }
            }
        } else {
            $visible = $all
        }

        # 统计信息（列表顶部与底部各给一份）
        $summaryText = ('软件源里共 {0} 个软件    已选中 {1} 个' -f $visible.Count, $Selected.Count)
        if ($filterText) {
            $summaryText = ('软件源里共 {0} 个软件，已按「{1}」过滤：命中 {2} 个    已选中 {3} 个' -f `
                $all.Count, $filterText, $visible.Count, $Selected.Count)
        }

        Write-Host ''
        if ($Title) { Write-Host ('  {0}' -f $Title) -ForegroundColor Cyan }
        Write-Host ('  {0}' -f $summaryText) -ForegroundColor DarkGray

        if ($visible.Count -eq 0) {
            Write-Host '  没有匹配的软件。' -ForegroundColor DarkYellow
        } else {
            for ($i = 0; $i -lt $visible.Count; $i++) {
                $row = $visible[$i]
                $id = [string]$row['Id']
                $chosen = $Selected.Contains($id)
                $mark = ' '
                if ($chosen) { $mark = '*' }
                Write-Host ('  {0}) {1}{2}' -f ($i + 1), $mark, [string]$row['Name']) -NoNewline -ForegroundColor $(if ($chosen) { 'Green' } else { 'White' })
                if ([string]$row['Name'] -cne $id) { Write-Host ('  ({0})' -f $id) -NoNewline -ForegroundColor DarkGray }
                Write-Host ('    软件源: {0}' -f (Get-WinstRowSourceText -Row $row)) -ForegroundColor DarkGray
            }
        }

        # 底部再给一份统计（与顶部同一句）
        Write-Host ('  {0}' -f $summaryText) -ForegroundColor DarkGray
        Write-Host '  输入编号切换选中（可多选，如 1 3 5；再输一遍同一个编号 = 取消选中）' -ForegroundColor DarkGray
        Write-Host '  标 * 的是已经选中的软件，也可以直接输入关键字过滤' -ForegroundColor DarkGray
        if ($filterText) { Write-Host '  输入 f 清除过滤' -ForegroundColor DarkGray }
        Write-Host '  回车 = 保存，c = 放弃，q = 退出程序' -ForegroundColor DarkGray

        $text = Read-WinstAnswerText -Prompt '  请输入'

        if (-not $text) { return @{ Action = 'save'; Ids = @(); Filter = $filterText } }
        if ($text -ieq 'c') { return @{ Action = 'cancel'; Ids = @(); Filter = $filterText } }
        if ((Test-WinstQuitKey -Text $text)) { return @{ Action = 'quit'; Ids = @(); Filter = $filterText } }
        if ($filterText -and $text -ieq 'f') { $filterText = ''; continue }

        $numbers = @()
        $allNumeric = $true
        $outOfRange = $false
        foreach ($token in @($text -split '[\s,，、]+')) {
            $one = ([string]$token).Trim()
            if (-not $one) { continue }
            $value = 0
            if (-not [int]::TryParse($one, [ref]$value)) { $allNumeric = $false; break }
            if ($value -lt 1 -or $value -gt $visible.Count) { $outOfRange = $true; break }
            if ($numbers -notcontains $value) { $numbers += $value }
        }

        # 纯数字但越界：说清可用范围再问一次
        if ($allNumeric -and $outOfRange) {
            Write-Host ('  没有这个编号（可选 1 - {0}），请重新输入。' -f $visible.Count) -ForegroundColor Yellow
            continue
        }

        if ($allNumeric -and $numbers.Count -gt 0) {
            $ids = @()
            foreach ($number in $numbers) {
                $id = [string]$visible[[int]$number - 1]['Id']
                if ($id) { $ids += $id }
            }
            return @{ Action = 'toggle'; Ids = @($ids); Filter = $filterText }
        }

        # 既不是编号也不是控制键 → 当作关键字过滤
        $filterText = $text
    }
}
