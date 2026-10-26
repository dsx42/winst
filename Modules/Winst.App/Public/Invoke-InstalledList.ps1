#Requires -Version 5.1

function Invoke-InstalledList {
    <#
    .SYNOPSIS
        菜单「已装软件」：列出安装记录里的全部软件 → 选择后 u 更新 / d 卸载 / 回车查看详情。
    .DESCRIPTION
        列表展示名称、版本、安装位置，软件源里有更新版本时用绿色标出；非 winst 安装（仅登记）
        与安装目录缺失分别标注。
    #>
    param([hashtable]$Context)

    Write-Section '已装软件'

    if (-not (Assert-WinstContext $Context)) { return }

    # 先读台账拿到要展示的软件，再按需刷新它们的版本信息（per-app TTL，--offline 自动跳过；
    # 展示集合全部有效时零解析、无提示，列表里的「可更新」标注才是当前值
    $ledgerIds = @(Get-WinstDisplayIds -Ids (Read-WinstInstalledKeys -Context $Context))
    $refresh = Update-WinstDisplaySources -Context $Context -Ids $ledgerIds
    Write-WinstRefreshErrors -Errors $refresh.Errors


    # 软件源刷新之后顺手刷新安装记录：
    # 按磁盘上的实际目录与注册表重新识别版本 / 安装位置并更正记录，列表才不会停留在过期数据上；
    # 只写 state.json，不动任何文件与系统项；--dry-run 下整段跳过（预览模式不写盘）。
    # 进度提示说「读取」而不是「刷新」：这一步对用户来说就是开始读记录，改了什么会在随后的一行结论里说清楚。
    if (-not [bool]((Get-WinstState -Name WinstOptions) -and (Get-WinstState -Name WinstOptions).DryRun)) {
        Write-Host '  正在读取安装记录 …' -ForegroundColor Gray
        $null = Invoke-Repair -Context $Context -Quiet
    }

    $overview = Get-WinstInstalledOverview -Context $Context
    if (-not $overview.Ok) {
        Write-Host ''
        Write-Host ('  {0}' -f $overview.Error) -ForegroundColor Red
        Write-Host ''
        Read-WinstPause -Text '  按回车键返回主菜单 …'

        return
    }
    if ($overview.Warning) { Write-Host ('  提示: {0}' -f $overview.Warning) -ForegroundColor Yellow }

    # Where-Object 过滤掉 $null 条目：列表函数一旦返回 $null，@() 会把它变成一个「空条目」→ 渲染时报错
    $items = @($overview.Items | Where-Object { $null -ne $_ })
    if ($items.Count -eq 0) {
        Write-Host ''
        Write-Host '  安装记录里还没有已安装的软件。' -ForegroundColor Yellow
        Write-Host '  可以先用「安装软件」装一个。本页每次进入都会重新扫描安装记录：如果软件确实装在这台电脑上却没被识别，' -ForegroundColor DarkGray
        Write-Host '  请检查「设置 → 软件安装位置」是否指向它所在的目录。' -ForegroundColor DarkGray
        Write-Host ''
        Read-WinstPause -Text '  按回车键返回主菜单 …'

        return
    }

    $filter = ''
    while ($true) {
        $pick = Show-WinstInstalledRows -Items $items -AllowUpdateAll -Filter $filter
        if ($pick.Action -eq 'select') { $filter = [string]$pick.Filter }   # 进详情再返回时保持过滤
        if ($pick.Action -eq 'quit') { Set-WinstQuit; return }

        if ($pick.Action -eq 'update-all') {
            # u) 全部升级：列出可升级的软件并确认后一次性更新（更新方式取「设置 → 更新方式」）
            $updatable = @()
            foreach ($one in $items) { if ([bool]$one['HasUpdate']) { $updatable += $one } }
            $null = Invoke-WinstUpgradeAll -Context $Context -Items $updatable
        } elseif ($pick.Action -ne 'select') {
            Write-Host '  已返回。' -ForegroundColor DarkGray
            return
        } else {
            $item = $items[[int]$pick.Index]
            $id = [string]$item['Id']
            Show-WinstInstalledDetail -Context $Context -Item $item

            # 更新相关的两个选项**只在真的有更新时出现**（HasUpdate = 软件源里有比本机更高的版本）：
            # 没有更新就没有可执行的动作，摆着只会让人试一次才发现没内容。
            $canUpdate = [bool]$item['HasUpdate']
            $hasOldVersions = [bool]$item['HasOldVersions']
            Write-Host ''
            if ($canUpdate) {
                # u) 更新：注明当前更新方式（设置 → 更新方式）与默认使用的来源（安装时选的那个软件源）
                $updateSourceText = '默认优先级（本地清单 → 内置源 → 其它源）'
                if ([string]$item['ManifestOrigin']) { $updateSourceText = ('安装时用的软件源 {0}' -f [string]$item['ManifestOrigin']) }
                Write-Host ('  u) 更新（按「设置 → 更新方式」: {0}）' -f (Get-WinstUpdateModeName -Context $Context)) -ForegroundColor White
                Write-Host ('     来源: {0}' -f $updateSourceText) -ForegroundColor DarkGray
                Write-Host '  c) 更新（可单独选更新方式与软件源）' -ForegroundColor White
            }
            if ($hasOldVersions) {
                Write-Host ('  o) 清理旧版本（{0}）' -f [string]$item['OldVersionsText']) -ForegroundColor White
            }
            Write-Host '  d) 卸载    r) 重新检测版本    b) 返回    q) 退出' -ForegroundColor DarkGray
            $text = Read-WinstAnswerText -Prompt '  请选择' -Lower

            if ((Test-WinstQuitKey -Text $text)) { Set-WinstQuit; return }
            if (-not $canUpdate -and ($text -eq 'u' -or $text -eq 'c')) {
                Write-Host '  没有可更新的内容（软件源里没有比本机更高的版本）。要重装 / 降级请到「安装软件」里搜索它，按提示确认强制重装。' -ForegroundColor DarkYellow
                continue
            }
            if ($text -eq 'o') {
                if (-not $hasOldVersions) {
                    Write-Host '  本机没有检测到并存的其他版本。' -ForegroundColor DarkYellow
                    continue
                }
                $null = Invoke-WinstOldVersionCleanup -Context $Context -Item $item
            } elseif ($text -ne 'u' -and $text -ne 'c' -and $text -ne 'd' -and $text -ne 'r') {
                continue   # 回车 / 其它 = 返回列表
            } elseif ($text -eq 'u') {
                # 默认更新：方式按「设置 → 更新方式」，来源优先安装时选的来源（不询问；要临时换源 / 换方式用 c）
                $null = Invoke-WinstUpdateTargets -Context $Context -Ids @($id) -AutoPickSource
            } elseif ($text -eq 'c') {
                $custom = Invoke-WinstUpdateCustom -Context $Context -Item $item
                if (-not $custom.Cancelled -and -not $custom.Ok) {
                    Write-Host ('  更新失败: {0}' -f [string]$custom.Error) -ForegroundColor Red
                }
            } elseif ($text -eq 'd') {
                Write-WinstUninstallResult -Result (Invoke-WinstUninstallApp -Context $Context -Id $id)
            } elseif ($text -eq 'r') {
                $sync = Sync-WinstInstalledRecord -Context $Context -Id $id
                if ($sync.Ok) {
                    Write-Host ''
                    Write-Host ('  {0}' -f $sync.Message) -ForegroundColor $(if ($sync.Changed) { 'Green' } else { 'Gray' })
                } else {
                    Write-Host ''
                    Write-Host ('  失败: {0}' -f $sync.Error) -ForegroundColor Red
                }
            }
        }

        # 升级 / 更新 / 卸载后重新载入列表，反映最新状态
        $overview = Get-WinstInstalledOverview -Context $Context
        if (-not $overview.Ok) {
            Write-Host ('  {0}' -f $overview.Error) -ForegroundColor Red
            Write-Host ''
            Read-WinstPause -Text '  按回车键返回主菜单 …'
            return
        }
        # Where-Object 过滤掉 $null 条目：列表函数一旦返回 $null，@() 会把它变成一个「空条目」→ 渲染时报错
        $items = @($overview.Items | Where-Object { $null -ne $_ })
        if ($items.Count -eq 0) {
            Write-Host ''
            Write-Host '  安装记录里已经没有已安装的软件了。' -ForegroundColor DarkGray
            Write-Host ''
            Read-WinstPause -Text '  按回车键返回主菜单 …'
            return
        }
        Write-Host ''
        Read-WinstPause

    }
}
