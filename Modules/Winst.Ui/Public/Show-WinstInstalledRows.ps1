#Requires -Version 5.1

function Show-WinstInstalledRows {
    <#
    .SYNOPSIS
        展示已安装软件。
    .DESCRIPTION
        `-AllowUpdateAll`（「已装软件」页面用）：存在可更新的软件时，列表下方提供 `u) 全部更新`
        —— 选中后由调用方列出可更新的软件并确认。
        其它调用方（如「卸载软件」的选软件步骤）不传该开关，列表里不出现这一项。
        统计信息（共多少个、几个可更新）在列表顶部与底部各给一份。
    .OUTPUTS
        @{ Action = 'select' | 'select-multi' | 'update-all' | 'back' | 'quit' | 'empty'; Index = <选中下标>; Indexes = <多选下标数组，仅 select-multi>; Filter = <当前关键字过滤> }
    #>
    param(
        $Items,
        [string]$Prompt = '请选择',
        [string]$ItemNoun = '已安装软件',
        [switch]$AllowUpdateAll,
        # 允许一次输入多个编号（如 1 3 5）：命中 Action = 'select-multi' + Indexes（原数组下标，按输入顺序）；
        # 不传该开关时维持旧语义——多个编号提示「只能选一个」（卸载流程的多关键字命中列表用）
        [switch]$AllowMultiSelect,
        [string]$Filter = ''
    )

    $items = @($Items)
    if ($items.Count -eq 0) { return @{ Action = 'empty'; Index = -1 } }

    $updatableCount = 0
    foreach ($one in $items) { if ([bool]$one['HasUpdate']) { $updatableCount++ } }

    $summaryText = ('共 {0} 个{1}    都是最新版本' -f $items.Count, $ItemNoun)
    $summaryColor = 'DarkGray'
    if ($updatableCount -gt 0) {
        $summaryText = ('共 {0} 个{1}    {2} 个可以更新' -f $items.Count, $ItemNoun, $updatableCount)
        $summaryColor = 'Green'
    }

    $renderRow = {
        param($item, $number)
            Write-WinstListItemIdentity -Item $item -Number $number
            Write-Host ('    版本 {0}' -f [string]$item['Version']) -NoNewline -ForegroundColor Gray
            if ([bool]$item['HasUpdate']) {
                Write-Host ('  {0}' -f [string]$item['UpdateHint']) -NoNewline -ForegroundColor Green
            }
            if ([bool]$item['DirMissing']) {
                Write-Host '  [安装目录不存在]' -NoNewline -ForegroundColor Yellow
            }
            Write-Host ''
            if ([string]$item['InstallDir']) {
                Write-Host ('     安装位置: {0}' -f [string]$item['InstallDir']) -ForegroundColor Gray
            } else {
                Write-Host '     安装位置: （未记录）' -ForegroundColor DarkGray
            }
            # 已装软件的来源（安装时用的是哪个软件源；可更新时 UpdateHint 里也标出更新来自哪个源）
            $noteParts = @([string]$item['ManagedText'])
            if ([string]$item['ManifestOrigin']) {
                $noteParts += ('来自软件源: {0}' -f [string]$item['ManifestOrigin'])
            } else {
                $noteParts += '来自软件源: （未记录）'
            }
            if (-not [bool]$item['InCatalog']) { $noteParts += '软件源里没有这个软件' }
            Write-Host ('     {0}' -f ($noteParts -join ' · ')) -ForegroundColor DarkGray
    }
    $renderFooter = {
        if ($AllowUpdateAll -and $updatableCount -gt 0) {
            Write-Host ('  u) 全部更新（一次性把这 {0} 个软件更新到最新版）' -f $updatableCount) -ForegroundColor White
        }
    }
    $extraKeys = @{}
    if ($AllowUpdateAll -and $updatableCount -gt 0) { $extraKeys['u'] = 'update-all' }
    return (Invoke-WinstListPage -Items $items -SummaryText $summaryText -SummaryColor $summaryColor `
        -EmptyText '没有匹配的软件。' -SelectHint '输入编号查看详情（更新 / 卸载），也可以直接输入软件名搜索' `
        -Prompt $Prompt -Filter $Filter -RenderRow $renderRow -RenderFooter $renderFooter `
        -ExtraKeys $extraKeys -AllowMultiple:$AllowMultiSelect)
}
