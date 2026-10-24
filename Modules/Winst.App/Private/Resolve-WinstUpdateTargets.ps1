#Requires -Version 5.1

function Resolve-WinstUpdateTargets {
    <#
    .SYNOPSIS
        读台账、确定目标 id 集合、按需刷新清单，并建 id → 清单行 的查找表。
    .OUTPUTS
        @{ Empty; State; TargetIds; Explicit; RowById }
    #>
    param([hashtable]$Context, [string[]]$Ids = @(), [switch]$All, [switch]$Quiet, [switch]$NoRefresh, [hashtable]$Result)

    $stateRead = Read-WinstState -InstallRoot $Context.InstallRoot
    if ($stateRead.Error -and -not $stateRead.Reset) {
        Write-Host ''
        Write-Host ('  {0}' -f $stateRead.Error) -ForegroundColor Red
        $Result.ExitCode = 1
        return @{ Empty = $true; State = $stateRead.State; TargetIds = @(); Explicit = @(); RowById = $null }
    }
    if ($stateRead.Error) { Write-Host ('  提示: {0}' -f $stateRead.Error) -ForegroundColor Yellow }
    $state = $stateRead.State

    # 1. 目标集合
    $explicit = @()
    foreach ($one in @($Ids)) {
        $text = ([string]$one).Trim()
        if ($text -and ($explicit -notcontains $text)) { $explicit += $text }
    }
    $targetIds = @()
    if ($explicit.Count -gt 0 -and -not $All) {
        $targetIds = @($explicit)
    } else {
        foreach ($key in @($state['Installed'].Keys)) { $targetIds += [string]$key }
    }
    if ($targetIds.Count -eq 0) {
        Write-Host ''
        Write-Host '  安装记录里还没有已安装的软件，没有需要检查的内容。' -ForegroundColor DarkGray
        return @{ Empty = $true; State = $state; TargetIds = @(); Explicit = $explicit; RowById = $null }
    }

    # 2. 按需刷新：清单本体按源有效期决定是否重新下载，逐条版本解析只针对
    #    目标软件里「版本信息超过 manifestTTLHours」的（Update-WinstStaleSources -OnlyIds），
    #    避免「刚刷新过的源又被 update 抓一遍」；列表 / 检查 / 执行三步读到的是同一份数据。
    if (-not $NoRefresh) {
        $refresh = Update-WinstStaleSources -Context $Context -Quiet:$Quiet -OnlyIds $targetIds
        $Result.RefreshErrors = @($refresh.Errors)
        Write-WinstRefreshErrors -Errors $refresh.Errors
    }

    $rowById = New-WinstOrdinalDictionary
    foreach ($row in @(Get-WinstSearchCatalog -Context $Context)) {
        $rowId = [string]$row['Id']
        if (-not $rowId) { continue }
        if (-not $rowById.Contains($rowId)) { $rowById[$rowId] = $row }
    }

    return @{ Empty = $false; State = $state; TargetIds = $targetIds; Explicit = $explicit; RowById = $rowById }
}
