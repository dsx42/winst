#Requires -Version 5.1

function Show-WinstListContent {
    <#
    .SYNOPSIS
        打印一份清单的逐项内容与状态（查看 / 一键安装 / 制作U盘安装包 共用）。
    .DESCRIPTION
        每条：编号、名称（id）、清单指定的版本（`id==版本` 时）、软件源版本、状态结论，
        以及该软件声明的依赖（`dependencies`，含传递依赖），标出已列入清单的依赖和安装时需要补齐的依赖。
        结尾给出一句汇总（已装 / 已有安装包 / 需联网下载 / 软件源里没有）。
    #>
    param(
        [Parameter(Mandatory = $true)][hashtable]$Context,
        [Parameter(Mandatory = $true)]$Items,
        [switch]$Quiet,
        $StateRead
    )

    $list = @($Items)
    $installedCount = 0
    $cachedCount = 0
    $needCount = 0
    $missingCount = 0
    $unusableCount = 0

    # 清单里的 id 集合（用于标注「依赖是否已写进这份清单」）
    if (-not $Quiet) {
        $listIds = New-WinstOrdinalDictionary
        foreach ($one in $list) {
            $oneId = [string]$one['Id']
            if ($oneId) { $listIds[$oneId] = $true }
        }
    }

    $index = 0
    foreach ($item in $list) {
        $index++
        if (-not [bool]$item['InCatalog']) { $missingCount++ }
        elseif (-not [bool]$item['PlanAvailable']) { $unusableCount++ }
        elseif ([bool]$item['Installed']) { $installedCount++ }
        elseif ([bool]$item['CacheHas']) { $cachedCount++ }
        else { $needCount++ }

        if ($Quiet) { continue }
        $status = Get-WinstListItemStatus -Item $item

        Write-Host ('  {0}) {1}' -f $index, [string]$item['DisplayName']) -NoNewline -ForegroundColor White
        if ([string]$item['DisplayName'] -cne [string]$item['Id']) {
            Write-Host ('  ({0})' -f [string]$item['Id']) -NoNewline -ForegroundColor DarkGray
        }
        Write-Host ('    清单项: {0}' -f (Get-WinstListItemPinNoteText -Item $item)) -ForegroundColor DarkGray
        Write-WinstCompanionVersions -Item $item
        Write-Host '     状态: ' -NoNewline -ForegroundColor Gray
        Write-Host ([string]$status['Text']) -ForegroundColor ([string]$status['Color'])
        if ([string]$item['SourceText']) {
            Write-Host ('     软件源: {0}' -f [string]$item['SourceText']) -ForegroundColor DarkGray
        }
        if ([string]$item['PinnedVersion']) {
            $pinNote = Get-WinstListItemPinNote -Item $item
            Write-Host ('     提示: {0}' -f [string]$pinNote.Text) -ForegroundColor ([string]$pinNote.Color)
        }

        $depLines = @(Get-WinstDependencyLines -Context $Context -Id ([string]$item['Id']) -Type ([string]$item['Type']) -StateRead $stateRead)
        if ($depLines.Count -gt 0) {
            $depTotal = 0
            $depInList = 0
            foreach ($one in $depLines) {
                $depIdText = [string]$one['Id']
                if (-not $depIdText) { continue }
                $depTotal++
                if ($listIds.Contains($depIdText)) { $depInList++ }
            }
            $depNote = '清单里没有的会在安装时自动安装'
            if ($depTotal -gt 0 -and $depInList -eq $depTotal) {
                $depNote = '都已写进这份清单'
            } elseif ($depInList -gt 0) {
                $depNote = ('其中 {0} 个已写进这份清单，其余会在安装时自动安装' -f $depInList)
            }
            Write-Host ('     依赖: {0} 个（{1}）' -f $depTotal, $depNote) -ForegroundColor DarkGray
            foreach ($one in $depLines) {
                $depIdText = [string]$one['Id']
                $depSuffix = ''
                if ($depIdText -and $listIds.Contains($depIdText)) { $depSuffix = '（清单里已有）' }
                Write-Host ('       - {0}{1}' -f [string]$one['Text'], $depSuffix) -ForegroundColor ([string]$one['Color'])
            }
        }
    }

    $parts = @(('共 {0} 项' -f $list.Count))
    if ($installedCount -gt 0) { $parts += ('已装 {0}' -f $installedCount) }
    if ($cachedCount -gt 0) { $parts += ('已有安装包 {0}' -f $cachedCount) }
    if ($needCount -gt 0) { $parts += ('需联网下载 {0}' -f $needCount) }
    if ($unusableCount -gt 0) { $parts += ('软件源里不可用 {0}' -f $unusableCount) }
    if ($missingCount -gt 0) { $parts += ('软件源里没有 {0}' -f $missingCount) }
    if (-not $Quiet) { Write-Host '' }
    $warn = ($missingCount -gt 0 -or $needCount -gt 0 -or $unusableCount -gt 0)
    Write-Host ('  汇总: {0}' -f ($parts -join ' / ')) -ForegroundColor $(if ($warn) { 'DarkYellow' } else { 'Gray' })

}
