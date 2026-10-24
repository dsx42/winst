#Requires -Version 5.1

function Invoke-SoftwareList {
    <#
    .SYNOPSIS
        菜单「软件列表」：列出软件源里的全部软件（安装状态 / 下载状态 / 版本信息）→ 查看详情后可安装、更新、卸载、删除已下载的安装包。
    .DESCRIPTION
        只列**软件源里的软件**：本机已装但软件源里没有的条目不在本页（请在「已装软件」里查看 / 卸载）。
        「仅下载」类型（download）只有三个操作：下载软件包 / 更新软件包 / 删除已下载的软件包。
        列表载入 / 动作菜单 / 动作执行 各由独立函数承担。
    .OUTPUTS
        无（结果直接打印；q 时设置 $script:WinstQuitRequested）
    #>
    param([hashtable]$Context)

    Write-Section '软件列表'

    if (-not (Assert-WinstContext $Context)) { return }

    # 超期软件源按有效期先刷新一次，列表里的「可更新」标注才是当前值（--offline 自动跳过、有效期内的源不动）
    $refresh = Update-WinstStaleSources -Context $Context
    Write-WinstRefreshErrors -Errors $refresh.Errors

    $loaded = Get-WinstSoftwareListItems -Context $Context -EmptyText '  软件源里还没有任何软件。'
    if (-not $loaded.Ok) { return }
    $items = @($loaded.Items)

    $filter = ''
    while ($true) {
        $pick = Show-WinstSoftwareRows -Items $items -Filter $filter
        if ($pick.Action -eq 'select') { $filter = [string]$pick.Filter }   # 进详情再返回时保持过滤
        if ($pick.Action -eq 'quit') { Set-WinstQuit; return }
        if ($pick.Action -ne 'select') {
            Write-Host '  已返回。' -ForegroundColor DarkGray
            return
        }

        $item = $items[[int]$pick.Index]
        Show-WinstSoftwareDetail -Context $Context -Item $item
        Show-WinstSoftwareActionMenu -Item $item

        $text = Read-WinstAnswerText -Prompt '  请选择' -Lower
        if ((Test-WinstQuitKey -Text $text)) { Set-WinstQuit; return }

        $acted = Invoke-WinstSoftwareListAction -Context $Context -Item $item -Text $text
        if (-not $acted) { continue }   # 回车 / 其它 = 返回列表

        # 安装 / 更新 / 卸载 / 删除安装包后重新载入列表，反映最新状态
        $reloaded = Get-WinstSoftwareListItems -Context $Context -Silent -EmptyText '  软件源里已经没有软件了。'
        if (-not $reloaded.Ok) { return }
        $items = @($reloaded.Items)
        Write-Host ''
        Read-WinstPause
    }
}
