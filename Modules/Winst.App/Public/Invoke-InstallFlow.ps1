#Requires -Version 5.1

function Invoke-InstallFlow {
    <#
    .SYNOPSIS
        菜单「安装软件」：搜索 → 选择软件（可多选）→ 选择来源 → 展示详情 → 安装。
    .DESCRIPTION
        关键字支持一次写多个（用空格 / 逗号 / 顿号分隔，如「压缩 浏览器」）：**先把整串当一个关键字搜**
        （软件名本身可能带空格，如「Eclipse Temurin JDK 21」），整体搜不到再按分隔符拆开分别搜索、
        合并去重后一起列出——因此「jdk21 jdk25」这类输入可以一次搜到多个软件。
        装完一轮后直接回到关键字输入接着装下一个，不询问「是否继续」；
        在关键字输入处直接回车即结束、回主菜单。
        输入的是文件路径 / 命令行（含盘符、路径分隔符或以可执行文件扩展名结尾）时**不当关键字搜索**，
        而是明确说明「这不是软件名称」后重新输入（见 Test-WinstPathLikeKeyword）。
    #>
    param([hashtable]$Context)

    Write-Section '安装软件'

    if (-not (Assert-WinstContext $Context)) { return }

    while ($true) {
        $keyword = Read-Host '  请输入软件名称或关键字（多个用空格分隔，如「压缩 浏览器」；直接回车结束）'
        if ($null -eq $keyword -or -not ([string]$keyword).Trim()) {
            Write-Host '  已结束。' -ForegroundColor DarkGray
            return
        }
        $keyword = ([string]$keyword).Trim()

        # 路径 / 命令行噪声不当关键字：控制台里混进来的路径（如 `.\rufus.com`）拿去搜索必然
        # 零命中，只会回一句莫名其妙的「没有找到」；这里先认出来、明确说明后重新输入
        if (Test-WinstPathLikeKeyword -Text $keyword) {
            Write-Host ''
            Write-Host ('  「{0}」看起来是文件路径或命令行，不是软件名称。' -f $keyword) -ForegroundColor Yellow
            Write-Host '  请输入软件名称或关键字（例如「Rufus」「压缩」「浏览器」）。' -ForegroundColor DarkGray
            continue
        }

        # 先按缓存搜出要展示的软件，再按需刷新这些软件的版本信息，
        # 刷新有成果时用新数据重新搜索展示——不把软件源里所有软件都解析一遍
        $lookup = Search-WinstRowsWithRefresh -Context $Context -Keyword $keyword
        $searched = $lookup.Searched
        $refresh = $lookup.Refresh
        if ($refresh.Skipped) {
            if ((Get-WinstState -Name WinstOptions) -and (Get-WinstState -Name WinstOptions).Offline) {
                Write-Host '  当前为离线模式，直接使用已有软件清单。' -ForegroundColor DarkGray
            }
        }
        Write-WinstRefreshErrors -Errors $refresh.Errors

        # 关键字解析：整串优先、搜不到再按多个关键字分别搜索并合并去重
        $rows = @($searched.Rows)
        $keywords = @($searched.Keywords)
        if ($searched.Merged -and @($searched.HitKeywords).Count -gt 0) {
            Write-Host ('  没有整体匹配「{0}」的软件，已按 {1} 个关键字分别搜索并合并结果: {2}' -f `
                $keyword, @($searched.HitKeywords).Count, (@($searched.HitKeywords | ForEach-Object { '「' + $_ + '」' }) -join ' ')) -ForegroundColor DarkGray
        }

        Write-Host ''
        if ($rows.Count -eq 0) {
            Write-Host ('  没有找到和「{0}」有关的软件。' -f $keyword) -ForegroundColor Yellow
            Write-Host '  提示: 可在「高级功能 → 管理软件源」里刷新软件源后再试；想一次搜多个可写成「压缩 浏览器」。' -ForegroundColor DarkGray
            continue
        }
        if ($keywords.Count -gt 1 -and $rows.Count -gt 1) {
            Write-Host ('  已合并 {0} 个关键字的搜索结果，可多选安装（如 1 3 5）。' -f $keywords.Count) -ForegroundColor DarkGray
        }

        $stateRead = Read-WinstState -InstallRoot $Context.InstallRoot
        $state = $stateRead.State

        $selection = @()
        if ($rows.Count -eq 1) {
            $selection = @(1)
        } else {
            $selection = @(Show-WinstSearchRows -Rows $rows -State $state)
            if ($selection.Count -eq 0) {
                Write-Host '  已取消。' -ForegroundColor DarkGray
                continue
            }
        }

        $okCount = 0          # 安装成功
        $downloadOkCount = 0  # 仅下载类型：软件包下载成功
        $skipCount = 0
        $failCount = 0
        $cancelCount = 0
        # 失败 / 跳过的原因：汇总里只报条数，逐条原因必须在这里收好，
        # 否则「失败 1」之后没有任何线索
        $failureNotes = @()
        $skipNotes = @()

        foreach ($number in $selection) {
            $row = $rows[[int]$number - 1]
            $isDownloadRow = ((Get-WinstRowType -Row $row) -eq 'download')
            Write-Host ''
            Write-Host ('  —— {0}（{1}）——' -f [string]$row['Name'], [string]$row['Id']) -ForegroundColor Cyan

            $one = Invoke-WinstInstallTarget -Context $Context -Row $row
            if ($one.Cancelled) { $cancelCount++; continue }
            if (-not $one.Ok) {
                $failCount++
                # 原因已由 Invoke-WinstInstallTarget 就地打印时不再重复；没打印的一定要补上，
                # 否则汇总里只剩「失败 1」而没有线索
                if (-not [bool]$one.FailureShown) {
                    $reason = [string]$one.Error
                    if (-not $reason) { $reason = [string]$one.Message }
                    if (-not $reason) { $reason = '未知原因' }
                    $failureNotes += ('{0}（{1}）: {2}' -f [string]$row['Name'], [string]$row['Id'], $reason)
                }
                continue
            }
            if ($one.Skipped) {
                $skipCount++
                if ([string]$one.Message) { $skipNotes += ('{0}（{1}）: {2}' -f [string]$row['Name'], [string]$row['Id'], [string]$one.Message) }
                continue
            }
            # 仅下载类型不写台账，汇总里单列「已下载软件包」，不混进「已安装」
            if ($isDownloadRow) { $downloadOkCount++ } else { $okCount++ }
            # 安装后重读台账，后续展示能反映最新状态
            $state = (Read-WinstState -InstallRoot $Context.InstallRoot).State
        }

        Write-Host ''
        $summaryParts = @()
        if ($okCount -gt 0) { $summaryParts += ('已安装 {0}' -f $okCount) }
        if ($downloadOkCount -gt 0) { $summaryParts += ('已下载软件包 {0}' -f $downloadOkCount) }
        $summaryParts += @(('跳过 {0}' -f $skipCount), ('取消 {0}' -f $cancelCount), ('失败 {0}' -f $failCount))
        Write-Host ('  汇总: {0}' -f ($summaryParts -join ' / ')) -ForegroundColor $(if ($failCount -gt 0) { 'Yellow' } else { 'Gray' })
        foreach ($note in @($failureNotes)) {
            Write-Host ('    失败原因: {0}' -f $note) -ForegroundColor Red
        }
        foreach ($note in @($skipNotes)) {
            Write-Host ('    跳过原因: {0}' -f $note) -ForegroundColor DarkYellow
        }
    }
}
