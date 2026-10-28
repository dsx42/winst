#Requires -Version 5.1

function Invoke-CacheList {
    <#
    .SYNOPSIS
        菜单「已下载包」：列出已下载的安装包 → 列表处可直接 `u) 升级已装软件` / `d) 下载全部更新包`；
        选中某条后 `i` 安装 / `u` 升级这个软件 / `x` 下载它的更新包 / `d` 删除（删除前确认）。
    .DESCRIPTION
        **「仅下载」类型（download）的条目不安装**：它只有 `x) 更新软件包` 与 `d) 删除软件包` 两项。
        批量或单项操作结束后重新载入列表。
        载入 / 动作菜单 / 动作执行 各由独立函数承担。
    .OUTPUTS
        无（结果直接打印；q 时把状态项 WinstQuitRequested 置为 true）
    #>
    param([hashtable]$Context)

    Write-Section '已下载的安装包'

    if (-not (Assert-WinstContext $Context)) { return }

    $loaded = Get-WinstCachedListItems -Context $Context
    if (-not $loaded.Ok) { return }
    $items = @($loaded.Items)

    $filter = ''
    while ($true) {
        $pick = Show-WinstCachedRows -Items $items -Filter $filter
        if ($pick.Action -eq 'select') { $filter = [string]$pick.Filter }   # 进详情再返回时保持过滤

        if ($pick.Action -eq 'quit') { Set-WinstQuit; return }

        if ($pick.Action -eq 'update-all' -or $pick.Action -eq 'download-all') {
            # 批量：升级已装软件（u）/ 下载全部更新包（d）——都是先列出内容、确认后执行
            if ($pick.Action -eq 'update-all') {
                $targets = @()
                foreach ($one in $items) {
                    if ([bool]$one['Installed'] -and ([string]$one['InstalledUpdateState'] -eq 'update')) { $targets += $one }
                }
                $null = Invoke-WinstUpgradeAll -Context $Context -Items $targets
            } else {
                $targets = @()
                foreach ($one in $items) { if ([bool]$one['HasPackageUpdate']) { $targets += $one } }
                $null = Invoke-WinstDownloadUpdates -Context $Context -Items $targets
            }
        } elseif ($pick.Action -ne 'select') {
            Write-Host '  已返回。' -ForegroundColor DarkGray
            return
        } else {
            $item = $items[[int]$pick.Index]
            Show-WinstCachedDetail -Context $Context -Item $item
            Show-WinstCachedActionMenu -Item $item

            $text = Read-WinstAnswerText -Prompt '  请选择' -Lower
            if ((Test-WinstQuitKey -Text $text)) { Set-WinstQuit; return }

            $acted = Invoke-WinstCachedListAction -Context $Context -Item $item -Text $text
            if (-not $acted) { continue }   # 回车 / 其它 = 返回列表
        }

        # 安装 / 升级 / 下载 / 删除后重新载入列表，反映最新状态
        $reloaded = Get-WinstCachedListItems -Context $Context -Silent
        if (-not $reloaded.Ok) { return }
        $items = @($reloaded.Items)
        Write-Host ''
        Read-WinstPause
    }
}
