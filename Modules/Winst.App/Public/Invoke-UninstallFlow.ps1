#Requires -Version 5.1

function Invoke-UninstallFlow {
    <#
    .SYNOPSIS
        菜单「卸载软件」：输入名称（或片段）→ 展示将删除的内容 → 确认后卸载。
    .DESCRIPTION
        名称支持一次写多个（空格 / 逗号 / 顿号分隔，如「rufus 7-zip」）：**整串优先**（软件名可能带空格），
        整体搜不到再按词分别搜索、合并去重后一起列出，**多选（如 1 3 5）后逐个走卸载确认**；
        匹配全程不区分大小写（精确 -ieq / 子串 OrdinalIgnoreCase）。
        卸载完一个（取消 / 失败 / 没找到同理）后回到名称输入接着操作，与「安装软件」同一节奏；
        **在名称输入处直接回车即结束、回主菜单**（安装 / 卸载同一口径）。
        **软件源刷新只刷选中的软件**：搜索阶段只读安装台账与软件清单缓存（零网络），
        确定要卸载的 id（单个或多选）之后才 `Update-WinstDisplaySources -Ids <选中 id>`，
        只对这些条目做按需解析（超过 `manifestTTLHours` 的才联网）。已装软件可能几十个，
        进入本页就把它们全部刷新一遍会让输入名称后长时间干等。
    #>
    param([hashtable]$Context)

    Write-Section '卸载软件'

    while ($true) {
        Write-Host ''
        Write-Host '  输入软件名称（可只写片段，多个用空格分隔）直接卸载；卸载完一个可继续输入下一个；直接回车返回主菜单。' -ForegroundColor DarkGray
        $typed = Read-Host '  请输入软件名称'
        $text = ([string]$typed).Trim()
        if (-not $text) {
            # 直接回车 = 结束；要按列表卸载请到「已装软件」页选 d
            Write-Host '  已结束。' -ForegroundColor DarkGray
            return
        }

        # 搜索阶段只读台账 + 清单缓存（零网络）：已装软件可能几十个，先全部刷新会让输入名称后干等。
        # 软件源的刷新放在选中之后、只刷选中项（见下方）；每轮重读台账：刚卸载的软件不会再出现在列表里。
        $overview = Get-WinstInstalledOverview -Context $Context
        if (-not $overview.Ok) {
            Write-Host ''
            Write-Host ('  {0}' -f $overview.Error) -ForegroundColor Red
            return
        }
        if ($overview.Warning) { Write-Host ('  提示: {0}' -f $overview.Warning) -ForegroundColor Yellow }

        $items = $overview.Items
        if ($items.Count -eq 0) {
            Write-Host ''
            Write-Host '  安装记录里还没有已安装的软件，没有可以卸载的内容。' -ForegroundColor Yellow
            return
        }

        $searched = Search-WinstInstalledItemsByKeywords -Items $items -Keyword $text
        $hits = @($searched.Items)
        if ($searched.Merged -and @($searched.HitKeywords).Count -gt 0) {
            Write-Host ('  没有整体匹配「{0}」的已装软件，已按 {1} 个关键字分别搜索并合并结果: {2}' -f `
                $text, @($searched.HitKeywords).Count, (@($searched.HitKeywords | ForEach-Object { '「' + $_ + '」' }) -join ' ')) -ForegroundColor DarkGray
        }
        if ($hits.Count -eq 0) {
            Write-Host ('  没有找到名称或 id 含「{0}」的已装软件。' -f $text) -ForegroundColor DarkYellow
            continue
        }

        $targets = $hits
        if ($hits.Count -gt 1) {
            if (-not $searched.Merged) {
                Write-Host ('  有 {0} 个软件的名称或 id 含「{1}」：' -f $hits.Count, $text) -ForegroundColor DarkYellow
            }
            $pick = Show-WinstInstalledRows -Items $hits -Prompt '请输入编号（可多选，如 1 3 5）' -ItemNoun '匹配到的软件' -AllowMultiSelect
            if ($pick.Action -eq 'quit') { Set-WinstQuit; return }
            if ($pick.Action -eq 'select-multi') { $targets = @($hits[$pick.Indexes]) }
            elseif ($pick.Action -eq 'select') { $targets = @($hits[$pick.Index]) }
            else { Write-Host '  已返回。' -ForegroundColor DarkGray; continue }
        }

        $ids = @(foreach ($target in $targets) { $target['Id'] })
        $refresh = Update-WinstDisplaySources -Context $Context -Ids $ids
        Write-WinstRefreshErrors -Errors $refresh.Errors
        $okCount = 0
        $failCount = 0
        $restartInitiated = $false
        foreach ($target in $targets) {
            Write-Host ''
            Write-Host ('  —— {0}（{1}）——' -f $target['DisplayName'], $target['Id']) -ForegroundColor Cyan
            $one = Invoke-WinstUninstallApp -Context $Context -Id $target['Id']
            Write-WinstUninstallResult -Result $one
            if (-not $one.Cancelled) {
                if ($one.Ok) { $okCount++ } else { $failCount++ }
            }
            $restartInitiated = Get-EntryBool -Entry $one -Key 'RestartInitiated'
            if ($restartInitiated) {
                Write-Host '  系统已发起重启，本次卸载流程已结束。' -ForegroundColor DarkYellow
                break
            }
        }
        if ($targets.Count -gt 1) {
            Write-Host ('  汇总: 已卸载 {0} / 取消 {1} / 失败 {2}' -f $okCount, ($targets.Count - $okCount - $failCount), $failCount) -ForegroundColor Gray
        }
        if ($restartInitiated) { return }
    }
}
