#Requires -Version 5.1

function Read-WinstListPageInput {
    <#
    .SYNOPSIS
        列表页统一输入：回车 / b / q、批量键、f 清过滤、编号选择与越界提示。
    .DESCRIPTION
        「已装软件」「已下载包」「软件列表」三个页面共用这一套输入循环（含越界提示文案），
        三份容易走样。这里返回 0 基下标，由调用方换算成原数组下标。
        多选页（Show-WinstListPickRows）自己维护「切换选中」的输入循环，不复用本函数。
    .OUTPUTS
        @{ Action = 'select' | 'back' | 'quit' | 'filter' | <ExtraKeys 里的动作>; Indexes; Filter }
          - filter：Filter 为新的过滤词（f = 清空，其它文本 = 设为该词）
          - select：Indexes 为 0 基下标（按输入顺序）
    #>
    param(
        [Parameter(Mandatory = $true)][string]$Prompt,
        [Parameter(Mandatory = $true)][int]$Count,
        [string]$Filter = '',
        [hashtable]$ExtraKeys = @{},
        [switch]$AllowMultiple
    )

    while ($true) {
        $raw = $null
        try {
            $raw = Read-Host ('  {0}' -f $Prompt)
        } catch {
            return @{ Action = 'back'; Indexes = @(); Filter = $Filter }
        }

        $text = ''
        if ($null -ne $raw) { $text = ([string]$raw).Trim() }

        if (-not $text) { return @{ Action = 'back'; Indexes = @(); Filter = $Filter } }
        if ($text -ieq 'b') { return @{ Action = 'back'; Indexes = @(); Filter = $Filter } }
        if ((Test-WinstQuitKey -Text $text)) { return @{ Action = 'quit'; Indexes = @(); Filter = $Filter } }
        if ($ExtraKeys -and $ExtraKeys.ContainsKey($text)) {
            return @{ Action = [string]$ExtraKeys[$text]; Indexes = @(); Filter = $Filter }
        }
        if ($Filter -and $text -ieq 'f') { return @{ Action = 'filter'; Indexes = @(); Filter = '' } }

        $selection = @(Read-WinstSelectionFrom -Text $text -Count $Count)
        if ($selection.Count -gt 0) {
            if ($selection.Count -gt 1 -and -not $AllowMultiple) {
                Write-Host '  这里只能选一个编号，请重新输入。' -ForegroundColor Yellow
                continue
            }
            $indexes = @()
            foreach ($n in $selection) { $indexes += ([int]$n - 1) }
            return @{ Action = 'select'; Indexes = @($indexes); Filter = $Filter }
        }
        # 纯数字但越界 → 提示编号范围；其它内容 → 当作关键字过滤
        if ($text -match '^\d+$') {
            Write-Host ('  没有这个编号（可选 1 - {0}），请重新输入。' -f $Count) -ForegroundColor Yellow
            continue
        }
        return @{ Action = 'filter'; Indexes = @(); Filter = $text }
    }
}
