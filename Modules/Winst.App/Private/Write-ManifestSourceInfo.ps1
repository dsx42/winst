#Requires -Version 5.1

function Write-ManifestSourceInfo {
    <#
    .SYNOPSIS
        输出单个软件源的信息（来源位置、清单版本与时间、软件清单概况）。
    .DESCRIPTION
        供「软件源列表」与「管理软件源」共用，保证两处显示一致；本地清单显示清单文件路径。
    #>
    param(
        [Parameter(Mandatory = $true)][hashtable]$Context,
        [Parameter(Mandatory = $true)]$Source,
        [int]$Index = 0
    )

    $name = [string]$Source['name']
    $isLocal = Get-EntryBool -Entry $Source -Key 'isLocal'
    $isBuiltin = Get-EntryBool -Entry $Source -Key 'isBuiltin'

    $suffix = ''
    if ($isBuiltin) { $suffix = '  [内置]' }
    if ($isLocal) { $suffix = '  [本地清单·自动识别]' }

    if ($Index -gt 0) {
        Write-Host ('  {0}) {1}{2}' -f $Index, $name, $suffix) -ForegroundColor White
    } else {
        Write-Host ('     {0}{1}' -f $name, $suffix) -ForegroundColor White
    }

    if ($isLocal) {
        $first = $true
        foreach ($file in @(Get-EntryArray -Entry $Source -Key 'files')) {
            if ($first) {
                Write-Host ('     清单文件: {0}' -f $file) -ForegroundColor Gray
                $first = $false
            } else {
                Write-Host ('               {0}' -f $file) -ForegroundColor Gray
            }
        }
    } else {
        Write-Host ('     地址: {0}' -f ([string]$Source['url'])) -ForegroundColor Gray
    }

    $meta = Read-ManifestMeta -PkgDir $Context.PkgDir -Name $name

    if ($meta -and $meta.Version) {
        $timeText = ''
        if ($meta.FetchedAt) { $timeText = '  更新于 ' + (Format-ManifestTime -Value $meta.FetchedAt) }
        Write-Host ('     清单版本: {0}{1}' -f $meta.Version, $timeText) -ForegroundColor Green
    } elseif ($meta) {
        Write-Host '     清单版本: 未知（清单里没有版本信息）' -ForegroundColor DarkYellow
    } else {
        Write-Host '     清单版本: 尚未获取（请刷新）' -ForegroundColor DarkGray
    }
    Write-Host ('     软件清单: {0}' -f (Format-ResolvedLockSummary -Meta $meta)) -ForegroundColor DarkGray
    if ($isLocal) {
        Write-Host '     说明: 清单文件放在脚本同目录即自动生效，与其它软件源互不覆盖。' -ForegroundColor DarkGray
    }
    if ($isBuiltin) {
        Write-Host '     说明: 内置软件源，随 winst 提供，不可删除。' -ForegroundColor DarkGray
    }
}
