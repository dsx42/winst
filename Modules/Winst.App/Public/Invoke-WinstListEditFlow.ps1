#Requires -Version 5.1

function Invoke-WinstListEditFlow {
    <#
    .SYNOPSIS
        「编辑清单」：管理安装清单 里输入编号后按 e（或 CLI bundle edit）进入 →
        选定清单 → 从软件源挑选软件（多选切换）→ 保存 / 放弃。
    .DESCRIPTION
        按用户口径：挑选来源**只有软件源里的全部软件**，不提供「从已装软件挑选」入口；
        保存时原样保留清单里的 `#` 注释行，条目按清单顺序写回（新加入的追加在后面）。
    #>
    param(
        [Parameter(Mandatory = $true)][hashtable]$Context,
        [string]$Path = ''
    )

    $result = @{ Ok = $false; Cancelled = $false }
    if (Test-WinstInputRedirected) {
        Write-Host '  编辑清单需要交互输入，本次已取消，文件没有改动。' -ForegroundColor DarkYellow
        $result.Cancelled = $true
        return $result
    }
    $kindText = (Get-WinstListKindText)
    Write-Section ('编辑' + $kindText)

    if (-not (Assert-WinstContext $Context)) { return $result }

    $refresh = Update-WinstStaleSources -Context $Context -Quiet
    Write-WinstRefreshErrors -Errors $refresh.Errors


    $targetPath = ''
    if ($Path) {
        # 解析 + 报错文案在 Resolve-WinstListTargetPath 里（编辑 / 查看两页共用）
        $targetPath = Resolve-WinstListTargetPath -Context $Context -Path $Path
        if (-not $targetPath) { return $result }
    } else {
        $picked = Select-WinstListFile -Context $Context
        if (-not $picked.Ok) {
            Write-Host ''
            if ($picked.Cancelled) {
                $result.Cancelled = $true
                if (-not (Get-WinstState -Name WinstQuitRequested)) { Write-Host '  已返回。' -ForegroundColor DarkGray }
                return $result
            }
            Write-Host ('  {0}' -f $picked.Error) -ForegroundColor Red
            return $result
        }
        $targetPath = [string]$picked.Path
    }

    $existing = Read-WinstList -Path $targetPath
    if (-not $existing.Ok) {
        Write-Host ''
        Write-Host ('  {0}' -f $existing.Error) -ForegroundColor Red
        return $result
    }
    if (@($existing.BadLines).Count -gt 0) {
        Write-Host ('  提示: 清单里有 {0} 行无法识别，保存时会丢弃这些行。' -f @($existing.BadLines).Count) -ForegroundColor DarkYellow
    }

    # 选中集合与顺序：已有条目按清单顺序，新加入的追加在后面
    $order = @()
    $versionById = New-WinstOrdinalDictionary
    foreach ($entry in @($existing.Entries)) {
        $id = [string]$entry['Id']
        if (-not $id) { continue }
        if (-not $versionById.Contains($id)) { $order += $id }
        $versionById[$id] = [string]$entry['Version']
    }
    $selected = New-WinstOrdinalDictionary
    foreach ($id in @($order)) { $selected[$id] = $true }

    $rows = @(Get-WinstSearchCatalog -Context $Context)
    if ($rows.Count -eq 0) {
        Write-Host ''
        Write-Host '  软件源里还没有任何软件，无法挑选。' -ForegroundColor Yellow
        Write-Host '  可以到「高级功能 → 管理软件源」刷新软件源后再来。' -ForegroundColor DarkGray
        return $result
    }

    Write-Host ''
    if ($existing.Exists) {
        Write-Host ('  正在编辑: {0}（当前 {1} 项）' -f $targetPath, @($order).Count) -ForegroundColor Gray
    } else {
        Write-Host ('  将新建: {0}' -f $targetPath) -ForegroundColor Gray
    }

    $state = (Read-WinstState -InstallRoot $Context.InstallRoot).State
    $cacheIndex = (Read-WinstCacheIndex -PkgDir $Context.PkgDir).Index
    $rows = @($rows | ForEach-Object {
        $view = Copy-WinstObjectShallow -InputObject $_
        $ledger = Get-WinstInstalledApp -State $state -Id ([string]$view['Id'])
        $view['CompanionVersionLines'] = @(Get-WinstCompanionVersionLines -Context $Context -Id ([string]$view['Id']) -Row $view -Ledger $ledger -CacheIndex $cacheIndex)
        $view
    })
    $filter = ''
    while ($true) {
        $pick = Show-WinstListPickRows -Rows $rows -Selected $selected -Filter $filter `
            -Title ('挑选软件加入{0}（标 * 的是已在清单里的）' -f $kindText)
        $filter = [string]$pick.Filter

        if ($pick.Action -eq 'quit') { Set-WinstQuit; $result.Cancelled = $true; return $result }
        if ($pick.Action -eq 'cancel') {
            $result.Cancelled = $true
            Write-Host ''
            Write-Host ('  已取消：{0}没有改动。' -f $kindText) -ForegroundColor DarkGray
            return $result
        }
        if ($pick.Action -ne 'toggle') { break }

        foreach ($idText in @($pick.Ids)) {
            $id = [string]$idText
            if (-not $id) { continue }
            if ($selected.Contains($id)) {
                $selected.Remove($id)
                $order = @($order | Where-Object { [string]$_ -cne $id })
                Write-Host ('  已移出：{0}' -f $id) -ForegroundColor DarkGray
            } else {
                $selected[$id] = $true
                $order += $id
                Write-Host ('  已加入：{0}' -f $id) -ForegroundColor Green
            }
        }
    }

    if (@($order).Count -eq 0) {
        Write-Host ''
        if (-not (Read-WinstConfirm -Prompt ('  {0}里一个软件都没有，仍然保存（空清单）？(y/N)' -f $kindText) -Default 'n')) {
            $result.Cancelled = $true
            Write-Host ('  已取消：{0}没有改动。' -f $kindText) -ForegroundColor DarkGray
            return $result
        }
    }

    $dryRun = [bool]((Get-WinstState -Name WinstOptions) -and (Get-WinstState -Name WinstOptions).DryRun)
    $saved = Save-WinstList -Path $targetPath -CommentLines @($existing.CommentLines) -Ids @($order) `
        -VersionById $versionById -DryRun:$dryRun
    Write-Host ''
    if (-not $saved.Ok) {
        Write-Host ('  失败: {0}' -f $saved.Error) -ForegroundColor Red
        return $result
    }
    $result.Ok = $true
    if ($dryRun) {
        Write-Host ('  预览: 将把 {0} 项写入 {1}（--dry-run 不落盘）' -f [int]$saved.Count, $targetPath) -ForegroundColor DarkYellow
        return $result
    }
    Write-Host ('  已保存: {0}（{1} 项）' -f $targetPath, [int]$saved.Count) -ForegroundColor Green
    return $result
}
