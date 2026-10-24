#Requires -Version 5.1

function Write-WinstCachedList {
    <#
    .SYNOPSIS
        `winst list --cached`：列出已下载的安装包（先按索引确定展示项，再按需刷新版本）。
    .OUTPUTS
        [int] 退出码
    #>
    param([hashtable]$Context)

    # 先用本地安装包索引确定要展示的软件，再按需刷新这些软件的版本信息，
    # 最后重建总览渲染——不把软件源里所有软件都解析一遍；没有已下载包时不做任何刷新
    $preview = Get-WinstCachedOverview -Context $Context
    $displayIds = @(Get-WinstDisplayIds -Items $(if ($preview.Ok) { $preview.Items } else { @() }))
    $refresh = Update-WinstDisplaySources -Context $Context -Ids $displayIds
    Write-WinstRefreshErrors -Errors $refresh.Errors

    $overview = Get-WinstCachedOverview -Context $Context
    if (-not $overview.Ok) {
        Write-Host ''
        Write-Host ('  {0}' -f $overview.Error) -ForegroundColor Red
        return 1
    }
    if ($overview.Warning) { Write-Host ('  提示: {0}' -f $overview.Warning) -ForegroundColor Yellow }

    # Where-Object 过滤掉 $null 条目：列表函数一旦返回 $null，@() 会把它变成一个「空条目」→ 渲染时报错
    $items = @($overview.Items | Where-Object { $null -ne $_ })
    Write-Host ''
    if ($items.Count -eq 0) {
        Write-Host '  安装包位置里还没有下载好的安装包。' -ForegroundColor Yellow
        Write-Host ('  安装包位置: {0}  {1}' -f $Context.PkgDir, $Context.PkgDirLabel) -ForegroundColor Gray
        Write-Host '  提示: 安装或更新软件时会自动把安装包下载到这里。' -ForegroundColor DarkGray
        return 0
    }

    # 安装包位置只在开头给一次：每个软件的包都在 <安装包位置>\<id>\ 下
    Write-Host ('  安装包位置: {0}  {1}' -f $Context.PkgDir, $Context.PkgDirLabel) -ForegroundColor Gray

    $packageUpdatable = 0
    $installedUpdatable = 0
    $installedCount = 0
    $index = 0
    $hasGrouped = [bool](@($items | Where-Object { [string]$_['Group'] }).Count)
    $lastGroup = ''
    foreach ($item in $items) {
        $index++
        $lastGroup = Write-WinstGroupHeading -Group ([string]$item['Group']) -LastGroup $lastGroup -ShowUngrouped:$hasGrouped
        # 第 1 行：名称（id）+ 已下载包版本 / 大小 / 文件数
        Write-Host ('  {0}) {1}  ({2})' -f $index, [string]$item['DisplayName'], [string]$item['Id']) -NoNewline -ForegroundColor White
        Write-Host ('    已下载包 {0}' -f [string]$item['CacheVersionText']) -NoNewline -ForegroundColor Gray
        Write-Host (' · {0} · {1} 个文件' -f [string]$item['CacheSizeText'], [int]$item['CacheFileCount']) -ForegroundColor Gray

        # 第 2 行：本机是否已安装 + 已装能否升级（升级到哪个版本、来自哪个源）
        Write-Host '     本机安装: ' -NoNewline -ForegroundColor Gray
        if ([string]$item['Type'] -eq 'download') {
            Write-Host '不适用（这类软件只下载软件包，不安装到电脑）' -NoNewline -ForegroundColor DarkGray
        } elseif (-not [bool]$item['Installed']) {
            Write-Host '未安装' -NoNewline -ForegroundColor DarkGray
        } else {
            $installedCount++
            if ([string]$item['InstalledUpdateState'] -eq 'update') { $installedUpdatable++ }
            Write-Host ('已安装 {0}' -f [string]$item['InstalledVersionText']) -NoNewline -ForegroundColor Gray
            $installedConclusion = Get-WinstVersionConclusion -Item $item -Kind 'installed'
            Write-Host ('    {0}' -f [string]$installedConclusion['Text']) -NoNewline -ForegroundColor ([string]$installedConclusion['Color'])
            if ([bool]$item['InstalledDirMissing']) { Write-Host '   [安装目录不存在]' -NoNewline -ForegroundColor Yellow }
        }
        Write-Host ''

        # 第 3 行：安装包能否更新 + 软件源里的版本（全部来源并排）；仅下载类型叫「软件包」
        $packageLabel = '安装包:   '
        if ([string]$item['Type'] -eq 'download') { $packageLabel = '软件包:   ' }
        Write-Host ('     ' + $packageLabel) -NoNewline -ForegroundColor Gray
        $packageConclusion = Get-WinstVersionConclusion -Item $item -Kind 'package'
        if ([bool]$item['HasPackageUpdate']) { $packageUpdatable++ }
        Write-Host ([string]$packageConclusion['Text']) -NoNewline -ForegroundColor ([string]$packageConclusion['Color'])
        if ([string]$item['SourceText']) {
            Write-Host ('    软件源: {0}' -f [string]$item['SourceText']) -NoNewline -ForegroundColor DarkGray
        }
        if ([string]$item['Type'] -eq 'download') { Write-Host '    [只下载软件包，不安装到电脑]' -NoNewline -ForegroundColor DarkGray }
        Write-Host ''
    }

    Write-Host ''
    $notes = @()
    if ($packageUpdatable -gt 0) { $notes += ('{0} 个安装包可以更新' -f $packageUpdatable) }
    if ($installedUpdatable -gt 0) { $notes += ('{0} 个已装软件可以升级' -f $installedUpdatable) }
    if ($notes.Count -gt 0) { Write-Host ('  其中 {0}。' -f ($notes -join '，')) -ForegroundColor Green }
    Write-Host ('  共 {0} 个已下载的安装包，{1} 个已安装。' -f $items.Count, $installedCount) -ForegroundColor DarkGray
    Write-Host '  安装 / 更新: winst install <id>    删除: winst clean <id>' -ForegroundColor DarkGray
    Write-Host '  「仅下载」类型: winst download <id> 下载 / 更新软件包，winst clean <id> 删除软件包' -ForegroundColor DarkGray
    return 0
}
