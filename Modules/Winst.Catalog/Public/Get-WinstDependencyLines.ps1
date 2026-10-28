#Requires -Version 5.1

function Get-WinstDependencyLines {
    <#
    .SYNOPSIS
        汇总某个软件的依赖明细（直接 + 传递），供各详情页展示（软件列表 / 已装软件 / 已下载包）。
    .DESCRIPTION
        依赖取自各软件源解析锁的 dependencies（Get-WinstDependencyIndex 汇总），传递依赖按
        Resolve-WinstDependencyOrder 展开——因此这里列出的正是安装 / 更新时会一并处理的那几个，
        详情页与安装提示不会互相打脸。每项给出「名称 (id)：状态」，其中状态把用户关心的五件事说全
        （软件名 / 是否已安装 / 已安装版本 / 能否更新 / 更新后的版本）：
          - 未安装（将安装 x）——软件源里有可用版本时带上将安装的版本；
          - 已安装 x，已是最新 / 已安装 x，可更新到 y / 已安装 x（软件源里没有可用版本）；
          - 已安装（版本未知）——台账里没有版本号；
          - 依赖 id 在软件源里不存在时说明「安装时会跳过」（与 4.7 的安装口径一致）。
        间接依赖标出经由谁。`download` 类型（只下载软件包、不安装到电脑）不处理依赖，返回空列表。
    .OUTPUTS
        @( @{ Text; Color; Id; Missing } )：一行一条（Text 不含缩进），Color 为 Write-Host 颜色名，
        Id 为对应的依赖 id，Missing = $true 表示软件源里没有这个依赖
    #>
    param(
        [Parameter(Mandatory = $true)][hashtable]$Context,
        [Parameter(Mandatory = $true)][string]$Id,
        [string]$Type = ''
    )

    $lines = New-Object 'System.Collections.Generic.List[object]'
    if (-not $Id) { return @() }
    if (([string]$Type).Trim().ToLowerInvariant() -eq 'download') { return @() }

    $index = Get-WinstDependencyIndex -Context $Context
    if (-not $index['Deps'].Contains($Id)) { return $lines }
    if (@($index['Deps'][$Id]).Count -eq 0) { return $lines }

    $resolved = Resolve-WinstDependencyOrder -Context $Context -Id $Id
    if (-not $resolved.Ok) { return $lines }

    $rows = $index['Rows']
    $state = (Read-WinstState -InstallRoot $Context.InstallRoot).State

    # 依赖名称：优先软件源里的展示名，取不到就用 id（间接依赖的「经由」同样处理）
    $nameOf = {
        param([string]$OneId)
        if ($rows.Contains($OneId)) {
            $rowName = Get-EntryString -Entry $rows[$OneId] -Key 'Name'
            if ($rowName) { return $rowName }
        }
        return $OneId
    }

    foreach ($one in @($resolved.Order)) {
        $depId = [string]$one['Id']
        $targetVersion = ''
        if ($rows.Contains($depId)) {
            $depBest = Get-WinstRowBestSourceEntry -Row $rows[$depId]
            if ($depBest) { $targetVersion = [string]$depBest['Version'] }
        }

        # 状态把「是否已安装 / 已装版本 / 能否更新 / 更新后的版本」一次说清（见上方说明）
        $status = '未安装'
        if ($targetVersion) { $status = ('未安装（将安装 {0}）' -f $targetVersion) }
        $color = 'DarkYellow'
        $ledger = Get-WinstInstalledApp -State $state -Id $depId
        if ($ledger) {
            $installedVersion = Get-EntryString -Entry $ledger -Key 'version'
            if (-not $installedVersion) {
                $status = '已安装（版本未知）'
            } elseif (-not $targetVersion) {
                $status = ('已安装 {0}' -f $installedVersion)
            } elseif ((Compare-WinstVersion -A $targetVersion -B $installedVersion) -gt 0) {
                $status = ('已安装 {0}，可更新到 {1}' -f $installedVersion, $targetVersion)
            } else {
                $status = ('已安装 {0}，已是最新' -f $installedVersion)
            }
            $color = 'Gray'
        }

        $levelText = ''
        if ([int]$one['Level'] -gt 1) {
            $levelText = ('（间接依赖，经 {0}）' -f (& $nameOf ([string]$one['Via'])))
        }
        $lines.Add(@{ Text = ('{0} ({1})：{2}{3}' -f (& $nameOf $depId), $depId, $status, $levelText); Color = $color; Id = $depId; Missing = $false })
    }

    foreach ($miss in @($resolved.Missing)) {
        $lines.Add(@{ Text = ('{0}：软件源里没有这个依赖，安装时会跳过' -f [string]$miss['Id']); Color = 'DarkYellow'; Id = [string]$miss['Id']; Missing = $true })
    }

    return @($lines.ToArray())
}
