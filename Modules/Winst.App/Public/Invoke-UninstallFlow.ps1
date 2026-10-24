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
        **输入界面先给、软件源刷新与安装记录读取放后面**：`Update-WinstStaleSources` 只刷超过
        `manifestTTLHours`（默认 24 小时）有效期的软件源，刷新时逐条联网重新解析（本地清单 60 个软件的
        可达数十秒到数分钟）。放在输入之前时，用户要先对着没有任何提示的界面干等——这正是「进入
        卸载软件要停顿一下才出现输入界面」的原因。挪到 `Read-Host` 之后，输入界面立刻可用，刷新的进度
        也直接打印在用户按下回车之后。
    #>
    param([hashtable]$Context)

    Write-Section '卸载软件'

    if (-not (Assert-WinstContext $Context)) { return }

    while ($true) {
        Write-Host ''
        Write-Host '  输入软件名称（可只写片段，多个用空格分隔）直接卸载；卸载完一个可继续输入下一个；直接回车返回主菜单。' -ForegroundColor DarkGray
        $typed = Read-Host '  请输入软件名称'
        $text = ''
        if ($null -ne $typed) { $text = ([string]$typed).Trim() }
        if (-not $text) {
            # 直接回车 = 结束；要按列表卸载请到「已装软件」页选 d
            Write-Host '  已结束。' -ForegroundColor DarkGray
            return
        }

        # 先读台账拿到要展示的软件，再按需刷新它们的版本信息；
        # 台账为空（没有已装软件）时不做任何刷新。每轮重读：刚卸载的软件不会再出现在列表里。
        $ledgerIds = @(Get-WinstDisplayIds -Ids (Read-WinstInstalledKeys -Context $Context))
        $refresh = Update-WinstDisplaySources -Context $Context -Ids $ledgerIds
        Write-WinstRefreshErrors -Errors $refresh.Errors


        $overview = Get-WinstInstalledOverview -Context $Context
        if (-not $overview.Ok) {
            Write-Host ''
            Write-Host ('  {0}' -f $overview.Error) -ForegroundColor Red
            return
        }
        if ($overview.Warning) { Write-Host ('  提示: {0}' -f $overview.Warning) -ForegroundColor Yellow }

        # Where-Object 过滤掉 $null 条目：列表函数一旦返回 $null，@() 会把它变成一个「空条目」→ 渲染时报错
        $items = @($overview.Items | Where-Object { $null -ne $_ })
        if ($items.Count -eq 0) {
            Write-Host ''
            Write-Host '  安装记录里还没有已安装的软件，没有可以卸载的内容。' -ForegroundColor Yellow
            return
        }

        $target = $null
        if ($text) {
            # 搜索范围 = 安装台账（state.json）里的全部条目，与「安装软件」同一规则：
            #   ① 整串优先——软件名可能带空格（如「Eclipse Temurin JDK 21」）；
            #   ② 整串没命中且输入含空格 / 逗号 / 顿号分隔的多个词时，按词分别搜索、按出现顺序合并、
            #      按 id 去重——「rufus 7-zip」这类输入一次搜到多个，列表里多选后逐个卸载。
            #   匹配全程不区分大小写（精确 -ieq / 子串 OrdinalIgnoreCase），台账里记着的软件用片段就能搜到。
            $searched = Search-WinstInstalledItemsByKeywords -Items $items -Keyword $text
            $hits = @($searched.Items)
            if ($searched.Merged -and @($searched.HitKeywords).Count -gt 0) {
                Write-Host ('  没有整体匹配「{0}」的已装软件，已按 {1} 个关键字分别搜索并合并结果: {2}' -f `
                    $text, @($searched.HitKeywords).Count, (@($searched.HitKeywords | ForEach-Object { '「' + $_ + '」' }) -join ' ')) -ForegroundColor DarkGray
            }

            if ($hits.Count -eq 1) {
                $target = $hits[0]
            } elseif ($hits.Count -gt 1) {
                # 命中多个：只列出**命中的这些**（不铺整份列表），可多选后逐个卸载
                if (-not $searched.Merged) {
                    Write-Host ('  有 {0} 个软件的名称或 id 含「{1}」：' -f $hits.Count, $text) -ForegroundColor DarkYellow
                }
                $pick = Show-WinstInstalledRows -Items $hits -Prompt '请输入编号（可多选，如 1 3 5）' -ItemNoun '匹配到的软件' -AllowMultiSelect
                if ($pick.Action -eq 'quit') { Set-WinstQuit; return }
                if ($pick.Action -eq 'select-multi') {
                    # 多选：逐个走卸载确认，结束给一行汇总
                    $okCount = 0
                    $cancelCount = 0
                    $failCount = 0
                    foreach ($idx in @($pick.Indexes)) {
                        $one = $hits[[int]$idx]
                        Write-Host ''
                        Write-Host ('  —— {0}（{1}）——' -f [string]$one['DisplayName'], [string]$one['Id']) -ForegroundColor Cyan
                        $r = Invoke-WinstUninstallApp -Context $Context -Id ([string]$one['Id'])
                        if ($r.Cancelled) { $cancelCount++; continue }
                        if (-not $r.Ok) {
                            $failCount++
                            Write-Host ('  失败: {0}' -f $r.Error) -ForegroundColor Red
                            continue
                        }
                        $okCount++
                        Write-Host ('  {0}' -f $r.Message) -ForegroundColor Green
                        if ($r.NeedRestart) { Write-Host '  提示: 卸载程序提示需要重启电脑才能完成。' -ForegroundColor DarkYellow }
                        foreach ($note in @($r.Notes)) { Write-Host ('  提示: {0}' -f $note) -ForegroundColor DarkYellow }
                    }
                    Write-Host ''
                    Write-Host ('  汇总: 已卸载 {0} / 取消 {1} / 失败 {2}' -f $okCount, $cancelCount, $failCount) -ForegroundColor Gray
                    continue   # 本轮结束，回到名称输入
                }
                if ($pick.Action -eq 'select') {
                    $target = $hits[[int]$pick.Index]
                } else {
                    # back / empty：放弃本轮选择，回到名称输入
                    Write-Host '  已返回。' -ForegroundColor DarkGray
                    continue
                }
            } else {
                # 没找到就回到名称输入：**不顺手把整份已装列表铺开**（用户没要求看列表，铺开会把
                # 输入的那一行冲掉）；想按列表卸载请到「已装软件」页选 d
                Write-Host ''
                Write-Host ('  没有找到名称或 id 含「{0}」的已装软件。' -f $text) -ForegroundColor DarkYellow
                continue
            }
        }

        $id = [string]$target['Id']
        Write-Host ''
        Write-Host ('  —— {0}（{1}）——' -f [string]$target['DisplayName'], $id) -ForegroundColor Cyan
        $one = Invoke-WinstUninstallApp -Context $Context -Id $id
        if ($one.Cancelled) { continue }   # 取消本轮：回到名称输入
        if (-not $one.Ok) {
            Write-Host ''
            Write-Host ('  失败: {0}' -f $one.Error) -ForegroundColor Red
            continue
        }
        Write-Host ''
        Write-Host ('  {0}' -f $one.Message) -ForegroundColor Green
        if ($one.NeedRestart) { Write-Host '  提示: 卸载程序提示需要重启电脑才能完成。' -ForegroundColor DarkYellow }
        foreach ($note in @($one.Notes)) { Write-Host ('  提示: {0}' -f $note) -ForegroundColor DarkYellow }
        # 卸载成功：回到名称输入接着卸载下一个
    }
}
