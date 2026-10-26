#Requires -Version 5.1

function Show-WinstBundlePlan {
    <#
    .SYNOPSIS
        ⑥ 制作计划确认：列出将复制的软件与文件数，确认后返回待复制项。
    .OUTPUTS
        @{ Cancelled; CopyItems }
    #>
    param([string]$TargetDir, $Plan, [switch]$DryRun, [bool]$Yes = $false, [switch]$NonInteractive)

    $copyItems = @()
    foreach ($entry in @($Plan)) {
        $item = $entry['Item']
        if (-not [bool]$item['CacheHas']) { continue }
        $copyItems += $entry
    }
    if ($copyItems.Count -eq 0) {
        Write-Host ''
        Write-Host '  没有任何可复制的安装包（清单里的软件都缺包），已取消。' -ForegroundColor Red
        Write-Host '  可先在联网机器上把安装包取到本地（「软件列表 → d 一键下载」或「已下载包 → x 下载全部更新包」），再重新制作。' -ForegroundColor DarkGray
        return @{ Cancelled = $false; Empty = $true; CopyItems = @() }
    }

    $totalFiles = 0
    foreach ($entry in $copyItems) { $totalFiles += @($entry['Item']['CacheFiles']).Count }

    Write-Host ''
    Write-Host ('  将复制 {0} 个软件的安装包（共 {1} 个文件）到:' -f $copyItems.Count, $totalFiles) -ForegroundColor Cyan
    Write-Host ('    {0}' -f (Join-WinstPath $TargetDir 'apps')) -ForegroundColor Gray
    Write-Host '  同时复制脚本本体、软件源清单数据、本次选中的那份清单文件，并生成 winst.cmd。' -ForegroundColor Gray
    Write-Host '  版本相同的包跳过；U 盘里是旧版本时覆盖该软件的旧目录（不碰其它软件的内容）。' -ForegroundColor DarkGray
    if ($DryRun) { Write-Host '  当前为预览模式（--dry-run）：只展示计划，不复制任何文件。' -ForegroundColor DarkYellow }

    if (-not $Yes -and -not $DryRun -and -not $NonInteractive -and -not (Test-WinstInputRedirected)) {
        if (-not (Read-WinstConfirm -Prompt '  确认制作？(y/N)' -Default 'n')) {
            Write-Host '  已取消。' -ForegroundColor DarkGray
            return @{ Cancelled = $true; Empty = $false; CopyItems = $copyItems }
        }
    }

    return @{ Cancelled = $false; Empty = $false; CopyItems = $copyItems }
}
