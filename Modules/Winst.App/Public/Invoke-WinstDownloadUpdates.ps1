#Requires -Version 5.1

function Invoke-WinstDownloadUpdates {
    <#
    .SYNOPSIS
        批量下载更新包：把缓存里过期的安装包换成软件源里的最新版，只下载、不安装。
    .DESCRIPTION
        供「已下载包」列表的 `x) 下载全部更新包` 与「软件列表 → 详情 → p) 下载软件包」使用
        ：逐个 id 用**版本最高的可用来源**解析目标版本，复用安装流程的
        「仅下载」路径（`Invoke-WinstAppInstall -DownloadOnly`）把包写入安装包位置并更新缓存索引；
        不安装、不写台账、不落地任何系统项（download 类条目本就如此）。
        来源与目标版本的解析与「一键下载」共用同一口径（`Get-WinstRowBestPlanEntry`）：版本号取自主包
        文件信息的条目（versionFromPackage）在软件源里没有版本号可比 → 退回第一个可用来源，取包后再读版本。
        `-Download`：用「将被下载」而不是「可以更新」的措辞（软件列表 → `p)` 的单项下载用它）。
    .OUTPUTS
        @{ Ok; Cancelled; Count; Downloaded; Failed; Skipped }
    #>
    param(
        [Parameter(Mandatory = $true)][hashtable]$Context,
        $Items,
        [switch]$Download
    )

    $targets = @($Items)
    if ($targets.Count -eq 0) { return @{ Ok = $true; Cancelled = $false; Count = 0; Downloaded = 0; Failed = 0; Skipped = 0 } }

    # 整批都是「仅下载」类型时，更新的是软件包：列表与问句都换用「更新软件包」的措辞
    $downloadOnlyBatch = $true
    foreach ($item in $targets) { if ([string]$item['Type'] -ne 'download') { $downloadOnlyBatch = $false } }
    $packageNoun = '安装包'
    if ($downloadOnlyBatch) { $packageNoun = '软件包' }

    Write-Host ''
    if ($Download) {
        Write-Host ('  以下 {0} 个{1}将被下载（只放进安装包位置，不安装）：' -f $targets.Count, $packageNoun) -ForegroundColor Cyan
    } else {
        Write-Host ('  以下 {0} 个{1}可以更新：' -f $targets.Count, $packageNoun) -ForegroundColor Cyan
    }
    $index = 0
    foreach ($item in $targets) {
        $index++
        # 版本号取自主包文件信息的条目：缓存里那份的版本不代表软件源当前这一份 → 一律重新取包
        $freshRow = Test-WinstRowVersionFromPackage -Row $item['Row']
        $targetText = [string]$item['BestVersion']
        $sourceText = [string]$item['BestSource']
        if ($freshRow) {
            # 与检查更新同一判据：远端无新包时缓存里
            # 那份就是远端当前这份，目标直接写它的版本；远端有新包直说；没比出结论则如实说明
            $sourceText = ''
            $targetText = Get-WinstRemoteFreshTargetText -Row $item['Row'] -FallbackVersion $targetText
        } elseif (-not $targetText) {
            $targetText = '未知'
        }
        Write-Host ('    {0}) {1}' -f $index, [string]$item['DisplayName']) -NoNewline -ForegroundColor White
        Write-Host ('    {0} {1}  →  {2}' -f $packageNoun, [string]$item['CacheVersionText'], $targetText) -NoNewline -ForegroundColor Gray
        if ($sourceText) { Write-Host ('（来自 {0}）' -f $sourceText) -NoNewline -ForegroundColor DarkGray }
        Write-Host ''
    }
    Write-Host ('  只更新{0}，不会安装 / 改动电脑上的软件。' -f $packageNoun) -ForegroundColor DarkGray
    $confirmPrompt = ('  确认下载{0}？(y/N)' -f $packageNoun)
    if (-not $Download) {
        if ($downloadOnlyBatch) { $confirmPrompt = '  确认更新全部软件包？(y/N)' }
        else { $confirmPrompt = '  确认下载全部更新包？(y/N)' }
    }
    if (-not (Read-WinstConfirm -Prompt $confirmPrompt -Default 'n')) {
        Write-Host '  已取消。' -ForegroundColor DarkGray
        return @{ Ok = $false; Cancelled = $true; Count = $targets.Count; Downloaded = 0; Failed = 0; Skipped = 0 }
    }

    $downloaded = 0
    $failed = 0
    $skipped = 0
    foreach ($item in $targets) {
        $name = [string]$item['DisplayName']
        $row = $item['Row']
        if (-not $row) {
            $skipped++
            Write-Host ('  {0}: 已跳过：软件源里没有这个软件。' -f $name) -ForegroundColor DarkYellow
            continue
        }

        # 用**版本最高**的可用来源（与列表里「可更新到 x.y」的判定同源），并取该来源的定义。
        # 版本号取自主包文件信息的条目（versionFromPackage，如 Chrome）在软件源里没有版本号可比，
        # Get-WinstRowBestPlanEntry 会退回**第一个可用来源**
        # ——与「一键下载」同一口径；这里只认有可用版本的来源，避免这类软件在「软件列表 → 下载软件包」
        # 里被判成「软件源里没有可用的版本信息」而下载失败（安装流程却能装，因为它不看这个判定）。
        $chosen = Get-WinstRowBestPlanEntry -Row $row
        if (-not $chosen) {
            $failed++
            Write-Host ('  {0}: 软件源里没有可用的版本信息，无法下载。' -f $name) -ForegroundColor Red
            continue
        }

        Write-Host ''
        # 目标版本：版本号只能取自主包文件信息的条目（versionFromPackage）要等取包后才知道，
        # 标题按「最新版（取包后确认）」写——那种情况下 chosen.Version 也来自缓存里那份包，不能当目标版本
        $targetVersionText = [string]$chosen['Version']
        if (Test-WinstRowVersionFromPackage -Row $row) {
            # 远端无新包（unchanged）时缓存版本即目标版本；有新包 / 没比出结论才「取包后确认」
            $fresh = Get-WinstRowRemoteFreshState -Row $row
            if ($fresh -ieq 'changed') {
                $targetVersionText = '最新版（远端有新包，取包后确认）'
            } elseif ($fresh -ine 'unchanged' -or -not $targetVersionText) {
                $targetVersionText = '最新版（取包后确认）'
            }
        } elseif (-not $targetVersionText) {
            $targetVersionText = '最新版'
        }
        Write-Host ('  —— {0} 更新{1}到 {2}（来自 {3}）——' -f $name, $packageNoun, $targetVersionText, [string]$chosen['Source']) -ForegroundColor Cyan
        $one = Invoke-WinstAppInstall -Context $Context -Plan $chosen['Plan'] -SourceName ([string]$chosen['Source']) -DownloadOnly -Quiet
        if ($one.Ok) {
            $downloaded++
            if ($one.Message) { Write-Host ('  {0}' -f $one.Message) -ForegroundColor Green }
        } else {
            $failed++
            $reason = [string]$one.Error
            if (-not $reason) { $reason = [string]$one.Message }
            Write-Host ('  失败: {0}' -f $reason) -ForegroundColor Red
        }
    }

    Write-Host ''
    Write-WinstResultSummary -Result @{ Updated = $downloaded; Skipped = $skipped; Failed = $failed } -Fields @(
        @{ Key = 'Updated'; Text = '已更新' },
        @{ Key = 'Skipped'; Text = '已跳过'; SkipZero = $true },
        @{ Key = 'Failed'; Text = '失败'; SkipZero = $true }
    )
    return @{ Ok = ($failed -eq 0); Cancelled = $false; Count = $targets.Count; Downloaded = $downloaded; Failed = $failed; Skipped = $skipped }
}
