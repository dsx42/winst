#Requires -Version 5.1

function Write-WinstUpdateCheckList {
    <#
    .SYNOPSIS
        渲染检查结果（总览 / 可更新行 / 无法比较段 / 输入提示），返回选择性更新需要的数据。
    .OUTPUTS
        @{ ShouldPrompt; UpdatableIds; EntryTexts }
    #>
    param([hashtable]$Context, $Check)

    # 检查结果分两段展示：
    #   ① 可以更新：绿色 + 编号，含「主包无变化、只有附加文件有更新」的条目；
    #   ② 无法比较且无从下手：黄色 + 原因（软件源里没有这个软件 / 本机版本比软件源里的更新）；
    #      解析阶段就失败的条目（ResolutionError）改用红色。
    $buckets = Get-WinstUpdateCheckBuckets -Entries $Check.Entries
    $updatableIds = @($buckets.UpdatableIds)
    $updateEntries = @($buckets.UpdateEntries)
    $uncomparable = @($buckets.Uncomparable)

    if ($updatableIds.Count -eq 0 -and $uncomparable.Count -eq 0) {
        Write-Host ''
        Write-Host '  已安装的软件都是最新版本，没有需要更新的。' -ForegroundColor Green
        return @{ ShouldPrompt = $false; UpdatableIds = @(); EntryTexts = @() }
    }

    # 总览一行：-Quiet 已抑制 Invoke-WinstUpdateTargets 内部的同一行，这里由菜单统一给出（同一屏只说一次）
    $latestCount = 0
    foreach ($one in @($Check.Entries)) { if ([string]$one['Action'] -eq 'latest') { $latestCount++ } }
    $overviewParts = @()
    $overviewParts += ('可更新 {0}' -f $updatableIds.Count)
    $overviewParts += ('已是最新 {0}' -f $latestCount)
    if ($uncomparable.Count -gt 0) { $overviewParts += ('无法比较 {0}' -f $uncomparable.Count) }
    Write-Host ''
    Write-Host ('  检查结果: {0}' -f ($overviewParts -join ' / ')) -ForegroundColor Gray

    # 行文本只在这里生成一次：编号列表与随后的「确认更新」回显共用，两处内容必然一致。
    $entryTexts = @()
    if ($updatableIds.Count -gt 0) {
        Write-Host ('  {0}：' -f [string]$buckets.SummaryText) -ForegroundColor Green
        for ($i = 0; $i -lt $updateEntries.Count; $i++) {
            $one = $updateEntries[$i]
            $installedText = [string]$one['Installed']
            if (-not $installedText -or $installedText -ieq 'unknown') { $installedText = '未知' }
            if ([string]$one['Action'] -eq 'files') {
                # 主包没变、只有配套文件变了：单独一行说明，选中后只更新这些文件
                $rowText = ('{0}    附加文件有更新（{1} 个）: {2}（主包已是最新 {3}）' -f [string]$one['Name'], [int]$one['CompanionCount'], (@($one['CompanionNames']) -join '、'), $installedText)
                $entryTexts += $rowText
                Write-Host ('  {0}) {1}' -f ($i + 1), $rowText) -ForegroundColor Green
                continue
            }
            # 目标版本兜底：versionFromPackage 条目按远端新鲜度展示——远端有新包 → 「新版本」，
            # 不显示「版本未知」；远端无新包时 Latest 已在检查时填成已下载安装包的版本
            $targetText = '版本未知（按软件源里的版本更新）'
            if ([string]$one['RemoteFresh'] -ieq 'changed' -and -not [string]$one['Latest']) {
                $targetText = '新版本'
            }
            if ([string]$one['Latest']) {
                $targetText = [string]$one['Latest']
                if ([string]$one['LatestSource']) { $targetText += ('（来自 {0}）' -f [string]$one['LatestSource']) }
            }
            $noteText = ''
            if ([string]$one['Message']) { $noteText = ('（{0}）' -f [string]$one['Message']) }
            # 版本未知但软件源里有可用信息：整行标黄（其余条目仍为绿色）
            $rowColor = 'Green'
            if ($noteText) { $rowColor = 'DarkYellow' }
            $rowText = ('{0}    当前 {1}  →  {2}  ↑{3}' -f [string]$one['Name'], $installedText, $targetText, $noteText)
            $entryTexts += $rowText
            Write-Host ('  {0}) {1}' -f ($i + 1), $rowText) -ForegroundColor $rowColor
        }
    } else {
        Write-Host '  没有可以更新的软件。' -ForegroundColor Gray
    }

    if ($uncomparable.Count -gt 0) {
        Write-Host ''
        Write-Host ('  另外 {0} 个软件这次不会处理（没法自动判断版本）：' -f $uncomparable.Count) -ForegroundColor Yellow
        $hasMissing = $false
        $hasNewer = $false
        foreach ($one in $uncomparable) {
            $installedText = [string]$one['Installed']
            if (-not $installedText) { $installedText = '未知' }
            $latestText = [string]$one['Latest']
            if (-not $latestText) { $latestText = '未知' }
            $reason = [string]$one['Message']
            if (-not $reason) { $reason = '无法比较版本' }
            if ($reason -ieq '本机版本比软件源里的更新') { $hasNewer = $true } else { $hasMissing = $true }
            $reasonColor = 'Yellow'
            if ([bool]$one['ResolutionError']) { $reasonColor = 'Red' }
            Write-Host ('    - {0}    本机 {1}，软件源 {2}（{3}）' -f [string]$one['Name'], $installedText, $latestText, $reason) -ForegroundColor $reasonColor
        }
        # 一句能落地的建议：这些条目要么软件源里没有定义，要么本机版本更高（winst 不自动降级）
        if ($hasMissing) {
            Write-Host '    软件源里没有的，可以到「软件列表」里搜一下，或到「高级功能 → 管理软件源」刷新软件源后再检查一次。' -ForegroundColor DarkGray
        }
        if ($hasNewer) {
            Write-Host '    本机版本更新的是正常的，不用处理；要重装 / 降级到软件源里的版本，可到「安装软件」里搜这个软件，按提示确认强制重装。' -ForegroundColor DarkGray
        }
    }

    if ($updatableIds.Count -eq 0) {
        return @{ ShouldPrompt = $false; UpdatableIds = @(); EntryTexts = $entryTexts }
    }

    Write-Host ''
    $hintParts = @()
    $hintParts += '输入编号（如 1 3）只更新这几个'
    $hintParts += ('u = 全部更新（{0} 个）' -f $updatableIds.Count)
    $hintParts += '回车 / b = 返回'
    Write-Host ('  {0}' -f ($hintParts -join '；')) -ForegroundColor DarkGray
    Write-Host ('  更新方式按「设置 → 更新方式」（{0}）；来源优先安装时用的那个软件源。' -f (Get-WinstUpdateModeName -Context $Context)) -ForegroundColor DarkGray

    return @{ ShouldPrompt = $true; UpdatableIds = @($updatableIds); EntryTexts = @($entryTexts) }
}
