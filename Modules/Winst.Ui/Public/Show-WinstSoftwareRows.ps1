#Requires -Version 5.1

function Show-WinstSoftwareRows {
    <#
    .SYNOPSIS
        展示软件源里的全部软件。
    .DESCRIPTION
        每条 3 行（列表只给结论、细节留给详情页）：
          第 1 行：名称（id）+ 版本信息——软件源里各来源的版本（**全部来源并排**）；
          第 2 行：安装状态（未安装 / 已安装 x.y + 已装能否升级）；
          第 3 行：下载状态（未下载 / 已下载包 a.b + 大小 + 文件数 + 安装包能否更新）。
        统计信息（共多少个 / 已安装 / 已下载 / 可升级）在列表顶部与底部各给一份。
    .OUTPUTS
        @{ Action = 'select' | 'back' | 'quit' | 'empty'; Index = <选中下标>; Filter = <当前关键字过滤> }
    #>
    param(
        $Items,
        [string]$Prompt = '请选择',
        [string]$Filter = ''
    )

    $items = @($Items)
    if ($items.Count -eq 0) { return @{ Action = 'empty'; Index = -1 } }

    $installedCount = 0
    $cachedCount = 0
    $updatableCount = 0
    $downloadTypeCount = 0
    foreach ($one in $items) {
        if ([bool]$one['Installed']) { $installedCount++ }
        if ([bool]$one['CacheHas']) { $cachedCount++ }
        if ([bool]$one['Installed'] -and ([string]$one['InstalledUpdateState'] -eq 'update')) { $updatableCount++ }
        if ([string]$one['Type'] -eq 'download') { $downloadTypeCount++ }
    }

    # 统计信息（列表顶部与底部各给一份）
    $summaryParts = @(('{0} 个已安装' -f $installedCount), ('{0} 个已下载' -f $cachedCount))
    if ($updatableCount -gt 0) { $summaryParts += ('{0} 个可升级' -f $updatableCount) }
    $summaryText = ('共 {0} 个软件    {1}' -f $items.Count, ($summaryParts -join ' · '))
    $summaryColor = 'DarkGray'
    if ($updatableCount -gt 0) { $summaryColor = 'Green' }

    $renderRow = {
        param($item, $number)
            # —— 第 1 行：名称（id）+ 软件源里的版本（全部来源并排） ——
            Write-WinstListItemIdentity -Item $item -Number $number
            if ([string]$item['SourceText']) {
                Write-Host ('    软件源: {0}' -f [string]$item['SourceText']) -ForegroundColor DarkGray
            } else {
                Write-Host '    软件源: （没有可用的版本信息）' -ForegroundColor DarkYellow
            }

            # —— 第 2 行：安装状态 ——
            Write-WinstInstalledStateLine -Item $item -Label '安装:   '

            # —— 第 3 行：下载状态 ——
            Write-Host '     下载:   ' -NoNewline -ForegroundColor Gray
            if (-not [bool]$item['CacheHas']) {
                if ([string]$item['Type'] -eq 'download') {
                    Write-Host '未下载（下载软件包后会保存到安装包位置）' -NoNewline -ForegroundColor DarkGray
                } else {
                    Write-Host '未下载（安装 / 更新时会自动下载）' -NoNewline -ForegroundColor DarkGray
                }
            } else {
                Write-Host ('已下载包 {0} · {1} · {2} 个文件' -f [string]$item['CacheVersionText'], [string]$item['CacheSizeText'], [int]$item['CacheFileCount']) -NoNewline -ForegroundColor Gray
                $packageConclusion = Get-WinstVersionConclusion -Item $item -Kind 'package'
                if ([string]$item['Type'] -eq 'download') {
                    Write-Host ('    软件包: {0}' -f [string]$packageConclusion['Text']) -NoNewline -ForegroundColor ([string]$packageConclusion['Color'])
                } else {
                    Write-Host ('    安装包: {0}' -f [string]$packageConclusion['Text']) -NoNewline -ForegroundColor ([string]$packageConclusion['Color'])
                }
            }
            if ([string]$item['Type'] -eq 'download') { Write-Host '    [只下载软件包，不安装到电脑]' -NoNewline -ForegroundColor DarkGray }
            Write-Host ''
    }
    $renderFooter = {
        if ($downloadTypeCount -gt 0) {
            Write-Host ('  「仅下载」类型的 {0} 个软件只能下载 / 更新 / 删除软件包，不安装到电脑' -f $downloadTypeCount) -ForegroundColor DarkGray
        }
    }
    return (Invoke-WinstListPage -Items $items -SummaryText $summaryText -SummaryColor $summaryColor `
        -EmptyText '没有匹配的软件。' `
        -SelectHint '输入编号查看详情（安装 / 更新 / 卸载 / 删除安装包），也可以直接输入软件名搜索' `
        -Prompt $Prompt -Filter $Filter -RenderRow $renderRow -RenderFooter $renderFooter)
}
