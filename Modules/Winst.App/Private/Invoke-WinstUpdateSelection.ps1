#Requires -Version 5.1

function Invoke-WinstUpdateSelection {
    <#
    .SYNOPSIS
        读取选择并执行：u = 全部更新（默认方式与来源）；编号 = 选择性更新（可确认后单独选方式 / 来源）。
    .DESCRIPTION
        返回值说明"这一轮到底跑没跑、跑成几个"：
        调用方据此决定是否回到检查结果页，并能如实告诉用户"更新了几个、还剩几个"。
    .OUTPUTS
        @{ Executed = <bool>; Updated = <int>; Failed = <int> }
    #>
    param([hashtable]$Context, [hashtable]$View)

    $result = @{ Executed = $false; Updated = 0; Failed = 0 }

    $updatableIds = @($View.UpdatableIds)
    $entryTexts = @($View.EntryTexts)

    $pick = Read-WinstIndexSelection -Prompt '  请选择' -Count $updatableIds.Count -AllowMultiple -AllowEmpty -AllKey 'u'
    if ($pick.Action -eq 'quit') { Set-WinstQuit; return $result }
    if ($pick.Action -eq 'back' -or $pick.Action -eq 'empty') {
        # 用户已经按过一次回车表示返回：跳过菜单的「按回车键返回菜单」
        Write-Host '  已返回。' -ForegroundColor DarkGray
        $null = Set-WinstState -Name WinstSkipMenuPause -Value ($true)
        return $result
    }

    if ($pick.Action -eq 'all') {
        # 全部更新：方式与来源都按默认，**不逐个确认**——列表已在上面完整展示，按 u 即视为对整批的确认；
        # 运行中的软件仍会问一次（不擅自结束用户正在用的程序）。
        Write-Host ''
        Write-Host ('  将更新上面全部 {0} 个软件。' -f $updatableIds.Count) -ForegroundColor Gray
        $done = Invoke-WinstUpdateTargets -Context $Context -Ids @($updatableIds) -AutoPickSource -Yes
        $result.Executed = $true
        $result.Updated = [int]$done.Updated
        $result.Failed = [int]$done.Failed
        return $result
    }

    # 选择性更新：先回显「这次更新哪几个、用什么方式与来源」，确认一次后执行；
    # 确认处输入 c 才逐条走「单独选更新方式与软件源」。
    $selectedIndexes = @($pick.Indexes)
    $targets = @()
    foreach ($index in $selectedIndexes) { $targets += [string]$updatableIds[[int]$index] }

    Write-Host ''
    Write-Host ('  将更新这 {0} 个软件：' -f $targets.Count) -ForegroundColor Cyan
    foreach ($index in $selectedIndexes) {
        Write-Host ('    {0}) {1}' -f ([int]$index + 1), $entryTexts[[int]$index]) -ForegroundColor White
    }
    Write-Host ('  更新方式: {0}' -f (Get-WinstUpdateModeName -Context $Context)) -ForegroundColor DarkGray
    Write-Host '  来源: 优先用安装时用的那个软件源（不可用时按默认优先级取有更新版本的来源）。' -ForegroundColor DarkGray

    $custom = $false
    while ($true) {
        $answer = Read-Host '  确认更新？(Y/n；输入 c = 单独选更新方式与软件源)'
        $confirmText = ''
        if ($null -ne $answer) { $confirmText = ([string]$answer).Trim() }
        if (-not $confirmText) { break }                                              # 回车 = 确认（已明确选过编号）
        if ($confirmText -ieq 'y' -or $confirmText -ieq 'yes') { break }
        if ($confirmText -ieq 'n') { Write-Host '  已取消。' -ForegroundColor DarkGray; return $result }
        if ($confirmText -ieq 'b') {
            # 用户已经按过一次回车表示返回：跳过菜单的「按回车键返回菜单」
            Write-Host '  已返回。' -ForegroundColor DarkGray
            $null = Set-WinstState -Name WinstSkipMenuPause -Value ($true)
            return $result
        }
        if ($confirmText -ieq 'c') { $custom = $true; break }
        Write-Host '  请输入 y（更新）/ n（不更新）/ c（单独选更新方式与软件源）。' -ForegroundColor Yellow
    }

    if (-not $custom) {
        $done = Invoke-WinstUpdateTargets -Context $Context -Ids @($targets) -AutoPickSource -Yes
        $result.Executed = $true
        $result.Updated = [int]$done.Updated
        $result.Failed = [int]$done.Failed
        return $result
    }

    $loop = Invoke-WinstUpdateCustomLoop -Context $Context -Targets $targets
    $result.Executed = $true
    $result.Updated = [int]$loop.Updated
    $result.Failed = [int]$loop.Failed
    return $result
}
