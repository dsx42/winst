#Requires -Version 5.1

function Show-WinstCachedRows {
    <#
    .SYNOPSIS
        展示已下载的安装包。
    .DESCRIPTION
        每条三行（列表只给结论、细节留给详情页）：
          第 1 行：名称（id）+ 已下载包版本 · 大小 · 文件数；
          第 2 行：本机安装情况（未安装 / 已安装 x.y + 已装能否升级，升级到哪个版本、来自哪个源）；
          第 3 行：安装包能否更新 + 软件源里各来源的版本（全部来源并排）。
        存在可更新的安装包 / 可升级的已装软件时，列表下方提供两个批量选项（由调用方执行）：
        `d) 下载全部更新包`、`u) 升级已装软件`。统计信息在列表顶部与底部各给一份。
    .OUTPUTS
        @{ Action = 'select' | 'update-all' | 'download-all' | 'back' | 'quit' | 'empty'; Index = <选中下标>; Filter = <当前关键字过滤> }
    #>
    param(
        $Items,
        [string]$Prompt = '请选择',
        [string]$Filter = ''
    )

    $items = @($Items)
    if ($items.Count -eq 0) { return @{ Action = 'empty'; Index = -1 } }

    # 可批量处理的两类：安装包过期的、已安装但可以升级的；另统计「仅下载」类型的条数（页脚提示用）
    $packageUpdatable = 0
    $installedUpdatable = 0
    $downloadTypeCount = 0
    foreach ($one in $items) {
        if ([bool]$one['HasPackageUpdate']) { $packageUpdatable++ }
        if ([bool]$one['Installed'] -and ([string]$one['InstalledUpdateState'] -eq 'update')) { $installedUpdatable++ }
        if ([string]$one['Type'] -eq 'download') { $downloadTypeCount++ }
    }

    # 统计信息（列表顶部与底部各给一份）
    $packageNoun = '安装包'
    if ($downloadTypeCount -gt 0 -and $downloadTypeCount -eq $items.Count) { $packageNoun = '软件包' }
    $summaryText = ('共 {0} 个已下载的{1}' -f $items.Count, $packageNoun)
    $summaryColor = 'DarkGray'
    $summaryNotes = @()
    if ($packageUpdatable -gt 0) { $summaryNotes += ('{0} 个{1}可更新' -f $packageUpdatable, $packageNoun) }
    if ($installedUpdatable -gt 0) { $summaryNotes += ('{0} 个软件可更新' -f $installedUpdatable) }
    if ($summaryNotes.Count -gt 0) {
        $summaryText += ('    {0}' -f ($summaryNotes -join ' · '))
        $summaryColor = 'Green'
    }

    $renderRow = {
        param($item, $number)
            # —— 第 1 行：名称（id）+ 已下载包版本 / 大小 / 文件数 ——
            Write-WinstListItemIdentity -Item $item -Number $number
            Write-Host ('    已下载包 {0}' -f [string]$item['CacheVersionText']) -NoNewline -ForegroundColor Gray
            Write-Host (' · {0} · {1} 个文件' -f [string]$item['CacheSizeText'], [int]$item['CacheFileCount']) -ForegroundColor Gray

            # —— 第 2 行：本机是否已安装 + 已装能否升级 ——
            Write-WinstInstalledStateLine -Item $item -Label '本机安装: '

            # —— 第 3 行：安装包能否更新 + 软件源里的版本（全部来源并排） ——
            $packageLabel = '安装包:   '
            if ([string]$item['Type'] -eq 'download') { $packageLabel = '软件包:   ' }
            Write-Host ('     ' + $packageLabel) -NoNewline -ForegroundColor Gray
            $packageConclusion = Get-WinstVersionConclusion -Item $item -Kind 'package'
            Write-Host ([string]$packageConclusion['Text']) -NoNewline -ForegroundColor ([string]$packageConclusion['Color'])
            if ([string]$item['SourceText']) {
                Write-Host ('    软件源: {0}' -f [string]$item['SourceText']) -NoNewline -ForegroundColor DarkGray
            }
            if ([string]$item['Type'] -eq 'download') { Write-Host '    [只下载软件包，不安装到电脑]' -NoNewline -ForegroundColor DarkGray }
            Write-Host ''
    }
    $renderFooter = {
        if ($downloadTypeCount -gt 0) {
            Write-Host ('  「仅下载」类型的 {0} 个软件只能更新 / 删除软件包，不安装到电脑' -f $downloadTypeCount) -ForegroundColor DarkGray
        }
        if ($installedUpdatable -gt 0) {
            Write-Host ('  u) 更新已安装的软件（把上面 {0} 个可以更新的软件更新到最新版）' -f $installedUpdatable) -ForegroundColor White
        }
        if ($packageUpdatable -gt 0) {
            if ($downloadTypeCount -gt 0 -and $downloadTypeCount -eq $items.Count) {
                Write-Host ('  d) 更新全部软件包（把上面 {0} 个过期的软件包换成最新版）' -f $packageUpdatable) -ForegroundColor White
            } else {
                Write-Host ('  d) 下载全部更新包（把上面 {0} 个过期的安装包换成最新版）' -f $packageUpdatable) -ForegroundColor White
            }
        }
    }
    $extraKeys = @{}
    if ($installedUpdatable -gt 0) { $extraKeys['u'] = 'update-all' }
    if ($packageUpdatable -gt 0) { $extraKeys['d'] = 'download-all' }
    return (Invoke-WinstListPage -Items $items -SummaryText $summaryText -SummaryColor $summaryColor `
        -EmptyText '没有匹配的安装包。' `
        -SelectHint '输入编号查看详情（安装 / 更新 / 删除安装包），也可以直接输入软件名搜索' `
        -Prompt $Prompt -Filter $Filter -RenderRow $renderRow -RenderFooter $renderFooter -ExtraKeys $extraKeys)
}
