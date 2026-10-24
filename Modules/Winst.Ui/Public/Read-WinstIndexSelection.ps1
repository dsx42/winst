#Requires -Version 5.1

function Read-WinstIndexSelection {
    <#
    .SYNOPSIS
        统一编号选择（单选 / 多选）：越界与非法输入都说清原因并重新提示，不静默当成取消。
    .DESCRIPTION
        编号按列表显示的顺序从 1 开始，支持 `1 3 5` / `1,3` / `1、3` 这类写法：
        - 回车：带 -AllowEmpty 时返回 Action = 'empty'（语义由调用方定义，如「返回」），
          否则提示「请输入编号」后继续问；
        - `b` / `q`：返回 Action = 'back' / 'quit'，由调用方决定返回还是退出；
        - -AllKey（如「u = 全部更新」的 u）：输入它时返回 Action = 'all'，语义由调用方定义；
        - 越界：`没有这个编号（可选 1 - N），请重新输入。`；非数字：`「x」不是编号，…`；
        - 单选场景给出多个编号：`这里只能选一个编号，请重新输入。`。
    .OUTPUTS
        @{ Action = 'select' | 'empty' | 'all' | 'back' | 'quit'; Indexes = @() }   Indexes 为 0 基下标
    #>
    param(
        [Parameter(Mandatory = $true)][string]$Prompt,
        [Parameter(Mandatory = $true)][int]$Count,
        [switch]$AllowMultiple,
        [switch]$AllowEmpty,
        [int]$MaxSelect = 0,
        [string]$AllKey = ''
    )

    if ($Count -le 0) { return @{ Action = 'empty'; Indexes = @() } }
    $rangeText = '1 - {0}' -f $Count

    while ($true) {
        $raw = $null
        try {
            $raw = Read-Host $Prompt
        } catch {
            return @{ Action = 'back'; Indexes = @() }
        }

        $text = ''
        if ($null -ne $raw) { $text = ([string]$raw).Trim() }

        if (-not $text) {
            if ($AllowEmpty) { return @{ Action = 'empty'; Indexes = @() } }
            Write-Host ('  请输入编号（可选 {0}）。' -f $rangeText) -ForegroundColor Yellow
            continue
        }
        if ($text -ieq 'b') { return @{ Action = 'back'; Indexes = @() } }
        if ((Test-WinstQuitKey -Text $text)) { return @{ Action = 'quit'; Indexes = @() } }
        if ($AllKey -and $text -ieq $AllKey) { return @{ Action = 'all'; Indexes = @() } }

        $resolved = Resolve-WinstSelectionText -Text $text -Count $Count
        $indexes = @()
        if ($resolved.Ok) {
            foreach ($n in @($resolved.Numbers)) { $indexes += ([int]$n - 1) }
        } elseif ($resolved.Bad) {
            Write-Host (Get-WinstSelectionErrorText -Resolved $resolved -Count $Count -RangeText $rangeText -Suffix '（b = 返回）') -ForegroundColor Yellow
            continue
        }
        if ($indexes.Count -eq 0) {
            Write-Host ('  请输入编号（可选 {0}）。' -f $rangeText) -ForegroundColor Yellow
            continue
        }
        if (-not $AllowMultiple -and $indexes.Count -gt 1) {
            Write-Host '  这里只能选一个编号，请重新输入。' -ForegroundColor Yellow
            continue
        }
        if ($MaxSelect -gt 0 -and $indexes.Count -gt $MaxSelect) {
            Write-Host ('  最多只能选 {0} 个，请重新输入。' -f $MaxSelect) -ForegroundColor Yellow
            continue
        }

        return @{ Action = 'select'; Indexes = @($indexes) }
    }
}
