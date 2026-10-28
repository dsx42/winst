#Requires -Version 5.1

function Invoke-WinstInfoCommand {
    <#
    .SYNOPSIS
        CLI：winst info <id> —— 显示某个软件的详情（各来源版本 / 安装状态 / 下载状态）。
    .OUTPUTS
        [int] 退出码：0 成功 / 1 参数错误或软件源里没有这个软件
    #>
    param(
        [Parameter(Mandatory = $true)][hashtable]$Context,
        [string[]]$Arguments = @()
    )

    $id = ''
    $force = $false
    foreach ($one in @($Arguments)) {
        $text = ([string]$one).Trim()
        if (-not $text) { continue }
        if ($text -ieq '--force') { $force = $true; continue }
        if ($text.StartsWith('-')) { continue }
        if (-not $id) { $id = $text }
    }
    if (-not $id) {
        Write-Host ''
        Write-Host '  用法: winst info <id> [--force]' -ForegroundColor Yellow
        Write-Host '  示例: winst info jdk21' -ForegroundColor Gray
        Write-Host '  --force: 忽略版本信息有效期（manifestTTLHours），重新解析这个软件；调试本地清单时用' -ForegroundColor DarkGray
        return 1
    }

    # 按需刷新这个软件的版本信息。
    # --force 走「强制刷新 + 只解析这一个 id」：调试本地清单时改完 manifest.json 立刻能看到结果，
    # 否则 24 小时有效期内的 id 会直接沿用解析锁里的旧值（改了什么都要等到期才生效）。
    if ($force) {
        $refresh = Update-WinstStaleSources -Context $Context -Force -OnlyIds @($id)
        Write-WinstRefreshErrors -Errors $refresh.Errors
    } else {
        $null = Update-WinstDisplaySources -Context $Context -Ids @($id) -Quiet
    }
    $overview = Get-WinstSoftwareOverview -Context $Context
    if (-not $overview.Ok) {
        Write-Host ''
        Write-Host ('  {0}' -f $overview.Error) -ForegroundColor Red
        return 1
    }
    if ($overview.Warning) { Write-Host ('  提示: {0}' -f $overview.Warning) -ForegroundColor DarkYellow }

    $item = $null
    foreach ($one in @($overview.Items)) {
        if ([string]$one['Id'] -ieq $id) { $item = $one; break }
    }
    if (-not $item) {
        Write-Host ''
        Write-Host ('  软件源里没有「{0}」这个软件。' -f $id) -ForegroundColor Yellow
        Write-Host '  可先用 winst search <关键字> 搜索，或到「高级功能 → 管理软件源」刷新软件源后重试。' -ForegroundColor DarkGray
        return 1
    }

    Show-WinstSoftwareDetail -Context $Context -Item $item
    return 0
}
