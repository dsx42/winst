#Requires -Version 5.1

function Invoke-ManifestManager {
    <#
    .SYNOPSIS
        「高级功能 → 管理软件源」：直接列出全部软件源，输入编号进详情（可刷新 / 删除），
        输入地址新建软件源（与「管理安装清单」同一交互形态）。
    .DESCRIPTION
        ① 每轮先渲染软件源列表（编号 = Show-ManifestMenu 返回的顺序）；
        ② 编号 → 先显示这个源的详情，再给 r 刷新 / d 删除 / 回车（或 b）返回列表；
        ③ 地址 → 新建软件源（GitHub 仓库或清单地址，名称自动取 用户名/仓库）；
        ④ 回车 / b 都返回上级，q 退出程序（与其它菜单一致）——回车不当「新建」。
    #>
    param([Parameter(Mandatory = $true)][hashtable]$Context)

    # 进入前先做内置源自愈，保证列表与后续操作基于一致的源列表
    $null = Ensure-OfficialManifest -Context $Context

    $pause = {
        Write-Host ''
        Read-WinstPause -Text '  按回车键返回列表…'
    }

    while ($true) {
        Clear-ScreenSafe
        $sources = @(Show-ManifestMenu -Context $Context)

        $answer = $null
        try { $answer = Read-Host '  请输入' } catch { $answer = $null }
        $text = ''
        if ($null -ne $answer) { $text = ([string]$answer).Trim() }

        # 回车与 b 同义：返回上一级（新建软件源靠输入地址，回车不等于「新建」）
        if (-not $text) { return }
        if ((Test-WinstQuitKey -Text $text)) { Set-WinstQuit; return }
        if ($text -ieq 'b') { return }

        # —— a：刷新全部软件源 ——
        if ($text -ieq 'a') {
            Write-Host ''
            $refresh = Invoke-ManifestRefreshAll -Context $Context
            if ($refresh.Aborted) { & $pause; continue }
            & $pause
            continue
        }

        # —— 输入编号：进入这个软件源的详情，随后可刷新 / 删除 ——
        $number = 0
        if ([int]::TryParse($text, [ref]$number)) {
            if ($sources.Count -eq 0) {
                Write-Host ''
                Write-Host '  现在还没有软件源，可直接输入地址新建。' -ForegroundColor Yellow
                & $pause
                continue
            }
            if ($number -lt 1 -or $number -gt $sources.Count) {
                Write-Host ''
                Write-Host ('  没有这个编号（可选 1 - {0}），请重新输入；也可以直接输入地址新建。' -f $sources.Count) -ForegroundColor Yellow
                & $pause
                continue
            }

            $source = $sources[$number - 1]
            $removed = $false
            while ($true) {
                Clear-ScreenSafe
                $actions = Show-ManifestSourceDetail -Context $Context -Source $source

                $sub = $null
                try { $sub = Read-Host '  请输入' } catch { $sub = $null }
                $subText = ''
                if ($null -ne $sub) { $subText = ([string]$sub).Trim() }

                if ((Test-WinstQuitKey -Text $subText)) { Set-WinstQuit; return }
                if (-not $subText -or $subText -ieq 'b') { break }   # 回车 / b 回列表

                if ($subText -ieq 'r') {
                    Write-Host ''
                    $null = Invoke-ManifestRefreshSource -Context $Context -Source $source
                    & $pause
                    continue
                }

                if ($subText -ieq 'd') {
                    if (-not $actions.CanRemove) {
                        Write-Host ''
                        Write-Host '  这个软件源不能在这里删除（内置源 / 本地清单）。' -ForegroundColor Yellow
                        & $pause
                        continue
                    }
                    $remove = Invoke-ManifestRemoveSource -Context $Context -Source $source
                    if ($remove.Removed -or $remove.Cancelled) {
                        if ($remove.Removed) { $removed = $true }
                        & $pause
                        break
                    }
                    & $pause
                    continue
                }

                Write-Host ''
                Write-Host '  请选择 r（刷新）/ d（删除）/ 回车或 b（返回列表）。' -ForegroundColor Yellow
                & $pause
            }

            # 删掉后这个源已不存在，直接回列表重绘（不再按旧编号找它）
            if ($removed) { continue }
            continue
        }

        # —— 输入地址：新建软件源 ——
        $added = Invoke-ManifestAddSource -Context $Context -RepoOrUrl $text
        if ($added.Cancelled) { continue }
        if ($added.Ok) {
            & $pause
            continue
        }
        & $pause
    }
}
