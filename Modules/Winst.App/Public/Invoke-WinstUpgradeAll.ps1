#Requires -Version 5.1

function Invoke-WinstUpgradeAll {
    <#
    .SYNOPSIS
        批量更新：先列出将要更新的软件（当前版本 → 新版本（来自 <源名>）），确认后逐个更新。
    .DESCRIPTION
        供「已装软件」列表的 `u) 全部更新` 与「已下载包」列表的 `u) 更新已装软件` 共用：
        更新方式取「设置 → 更新方式」（默认只更新文件，这里只展示不改设置），来源按 8.5
        默认规则（优先安装时用的来源，不可用 / 不比本机新时回退到有更新版本的来源）。
        逐项详情与确认由 `Invoke-WinstUpdateTargets` 内部的安装流程负责。
    .OUTPUTS
        @{ Ok; Cancelled; Count; Result }
    #>
    param(
        [Parameter(Mandatory = $true)][hashtable]$Context,
        $Items
    )

    $targets = @($Items)
    if ($targets.Count -eq 0) { return @{ Ok = $true; Cancelled = $false; Count = 0; Result = $null } }

    Write-Host ''
    Write-Host ('  以下 {0} 个软件可以更新：' -f $targets.Count) -ForegroundColor Cyan
    $index = 0
    foreach ($item in $targets) {
        $index++
        # 已装软件的条目用 Version / LatestVersion，已下载包的条目用 InstalledVersion / BestVersion，两者都兼容
        $currentText = [string]$item['InstalledVersion']
        if (-not $currentText) { $currentText = [string]$item['RawVersion'] }
        if (-not $currentText) { $currentText = '未知' }
        $targetText = [string]$item['LatestVersion']
        if (-not $targetText) { $targetText = [string]$item['BestVersion'] }
        $sourceText = [string]$item['LatestSource']
        if (-not $sourceText) { $sourceText = [string]$item['BestSource'] }
        # 版本号取自主包文件信息的条目：与检查更新同一判据——看解析锁里的 HEAD 比对结论（remoteFresh）：
        # 远端无新包时缓存里那份就是远端当前这份，目标版本直接写它；远端有新包直说；
        # HEAD 没比出结论（unknown）时如实说明、取包后确认版本
        if (Test-WinstRowVersionFromPackage -Row $item['Row']) {
            $sourceText = ''
            $targetText = Get-WinstRemoteFreshTargetText -Row $item['Row'] -FallbackVersion $targetText `
                -UnchangedSuffix '取已下载的安装包版本'
        }

        Write-Host ('    {0}) {1}' -f $index, [string]$item['DisplayName']) -NoNewline -ForegroundColor White
        Write-Host ('    当前 {0}  →  {1}' -f $currentText, $targetText) -NoNewline -ForegroundColor Gray
        if ($sourceText) { Write-Host ('（来自 {0}）' -f $sourceText) -NoNewline -ForegroundColor DarkGray }
        Write-Host ''
    }
    Write-Host ('  更新方式: {0}' -f (Get-WinstUpdateModeName -Context $Context)) -ForegroundColor DarkGray
    Write-Host '  要改成完整更新（覆盖已有的环境变量 / 快捷方式），请先到「设置 → 更新方式」切换。' -ForegroundColor DarkGray
    if (-not (Read-WinstConfirm -Prompt '  确认全部更新？(y/N)' -Default 'n')) {
        Write-Host '  已取消。' -ForegroundColor DarkGray
        return @{ Ok = $false; Cancelled = $true; Count = $targets.Count; Result = $null }
    }

    $ids = @()
    foreach ($item in $targets) {
        $id = [string]$item['Id']
        if ($id) { $ids += $id }
    }
    # 上面已经列出全部内容并确认过，执行时不逐个询问（每个软件的动作仍会完整打印出来）
    Write-Host ''
    Write-Host '  正在更新（每个软件的动作会逐条打印）…' -ForegroundColor Gray
    $result = Invoke-WinstUpdateTargets -Context $Context -Ids $ids -AutoPickSource -Yes
    return @{ Ok = [bool]$result.Ok; Cancelled = $false; Count = $targets.Count; Result = $result }
}
