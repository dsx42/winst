#Requires -Version 5.1

function Invoke-UpdateCheck {
    <#
    .SYNOPSIS
        菜单「检查更新」：强制刷新软件源 → 展示检查结果 → 输入提示（u 全部更新 / 编号只更新这几个 / 回车或 b 返回）；
        更新完成后回到同一张结果页，只列出**现在仍然能更新**的软件，可以接着更新，不需要回主菜单重新进入。
    .DESCRIPTION
        - **总是强制刷新清单本体**（`Update-WinstStaleSources -Force`）：不受 `manifestTTLHours` 限制；
          但传 `-OnlyIds <已装软件 id>` 时只逐条解析已安装软件的最新版本。
        - **刷新后读取安装记录**（`Invoke-Repair -Quiet`）：按磁盘实际目录与注册表重新识别版本 / 安装位置并更正记录。
        - **结果页是一个循环**：每轮按当前记录重新比较版本（`-NoRefresh`，不重复联网下载清单），再渲染结果。
          执行过更新就重回结果页，直到用户返回或没有可更新项为止。
        - **展示顺序固定为「结果 → 建议 → 输入提示」**：无法比较段必须在提问之前展示完。
        - **全部更新（u）**：方式与来源都按默认，不逐个确认。
        - **选择性更新（编号）**：先回显再确认；确认处输入 `c` 才逐条单独选更新方式与来源。
        刷新与记录校对见 Update-WinstCheckSources；结果渲染见 Write-WinstUpdateCheckList；
        选择与执行见 Invoke-WinstUpdateSelection。
    #>
    param([hashtable]$Context)

    Write-Section '检查更新'

    if (-not (Assert-WinstContext $Context)) { return }

    Update-WinstCheckSources -Context $Context

    $round = 0
    while ($true) {
        $check = Invoke-WinstUpdateTargets -Context $Context -All -Check -Quiet -NoRefresh
        if ($check.ExitCode -eq 1) { return }

        if ($round -gt 0) {
            Write-Host ''
            Write-Host '  —— 又回到检查结果页：下面是现在还能更新的 ——' -ForegroundColor DarkGray
        }

        $view = Write-WinstUpdateCheckList -Context $Context -Check $check
        if (-not $view.ShouldPrompt) { return }

        $pick = Invoke-WinstUpdateSelection -Context $Context -View $view
        if (-not $pick.Executed) { return }

        $round++
        if ($pick.Failed -gt 0) {
            Write-Host ''
            Write-Host ('  上一轮：成功 {0} / 失败 {1}。失败的条目仍在下面的列表里，可以重试。' -f $pick.Updated, $pick.Failed) -ForegroundColor DarkYellow
        } elseif ($pick.Updated -gt 0) {
            Write-Host ''
            Write-Host ('  上一轮：成功更新 {0} 个。' -f $pick.Updated) -ForegroundColor Green
        }
    }
}
