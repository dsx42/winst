#Requires -Version 5.1

function Update-WinstCheckSources {
    <#
    .SYNOPSIS
        强制刷新软件源（只解析已装软件）→ 校对安装记录 → 补刷新修复时新登记的软件。
    #>
    param([hashtable]$Context)

    # 先读安装台账拿到「已安装软件」的 id 集合（纯本地文件读取）：检查更新只解析已装软件的最新版本，
    # 不对软件源里所有软件逐条联网解析。台账读取失败或没有安装记录（首次运行）
    # 时回退全量刷新，保证 id 匹配可用。
    $ledgerIds = @()
    $stateRead = Read-WinstState -InstallRoot $Context.InstallRoot
    if (-not $stateRead.Error) {
        foreach ($key in @($stateRead.State['Installed'].Keys)) { $ledgerIds += [string]$key }
    }

    # 每次进入都强制刷新（不受有效期限制）：清单本体仍强制重新下载 / 读取（保证发现清单变更），
    # 但传 -OnlyIds 时只逐条解析已装软件的最新版本。
    if ($ledgerIds.Count -gt 0) {
        $refresh = Update-WinstStaleSources -Context $Context -Force -OnlyIds $ledgerIds
    } else {
        $refresh = Update-WinstStaleSources -Context $Context -Force
    }
    Write-WinstRefreshErrors -Errors $refresh.Errors

    # 软件源刷新之后紧接着读取安装记录（与「已装软件」页同一套扫描）：
    # 升级判断必须建立在「刷新后的软件源 + 校对过的记录」上；只写 state.json，--dry-run 下整段跳过。
    if (-not [bool]((Get-WinstState -Name WinstOptions) -and (Get-WinstState -Name WinstOptions).DryRun)) {
        Write-Host '  正在读取安装记录 …' -ForegroundColor Gray
        $null = Invoke-Repair -Context $Context -Quiet
    }

    # 修复可能新登记了之前不在台账里的软件：这些软件的版本信息若已过期则按需补刷新
    # （非 Force 按需路径：只刷过期的，全部有效时零开销、无提示）。
    $postStateRead = Read-WinstState -InstallRoot $Context.InstallRoot
    if (-not $postStateRead.Error) {
        $postIds = @()
        foreach ($key in @($postStateRead.State['Installed'].Keys)) { $postIds += [string]$key }
        if ($postIds.Count -gt 0) {
            $null = Update-WinstStaleSources -Context $Context -Quiet -OnlyIds $postIds
        }
    }
}
