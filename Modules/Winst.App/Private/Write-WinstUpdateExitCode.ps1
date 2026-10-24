#Requires -Version 5.1

function Write-WinstUpdateExitCode {
    <#
    .SYNOPSIS
        —— 汇总与退出码 ——（-Quiet 时不打印：调用方自己渲染，避免同屏两份口径）
    .OUTPUTS
        原样返回 $Result（已填 Ok / ExitCode）
    #>
    param([hashtable]$Result, [switch]$Check, [switch]$Quiet, $Explicit = @(), [int]$InstalledTargets = 0, [int]$DownloadOnlySkipped = 0)

    # -Quiet 表示调用方（如菜单「检查更新」）会自己渲染结果与统计：这里一并不打印，
    # 否则同一屏会出现两份口径不同的统计（一份含「已是最新 / 未安装」，一份只讲「可以更新」）。
    if (-not $Quiet) { Write-Host '' }
    if ($Check) {
        $parts = @()
        $parts += ('可更新 {0}' -f $Result.Updatable)
        $parts += ('已是最新 {0}' -f $Result.UpToDate)
        if ($Result.Unknown -gt 0) { $parts += ('无法比较 {0}' -f $Result.Unknown) }
        if ($Result.NotInstalled -gt 0) { $parts += ('未安装 {0}' -f $Result.NotInstalled) }
        if (-not $Quiet) { Write-Host ('  检查结果: {0}' -f ($parts -join ' / ')) -ForegroundColor Gray }
        $Result.Ok = $true
        $Result.ExitCode = 0
        if ($Result.Updatable -gt 0) { $Result.ExitCode = 4 }
    } else {
        Write-WinstResultSummary -Result $Result -Quiet:$Quiet -Fields @(
            @{ Key = 'Updated'; Text = '已更新' },
            @{ Key = 'Skipped'; Text = '跳过' },
            @{ Key = 'Failed'; Text = '失败' },
            @{ Key = 'UpToDate'; Text = '已是最新' },
            @{ Key = 'Reported'; Text = '需自行更新'; SkipZero = $true },
            @{ Key = 'Unknown'; Text = '无法比较'; SkipZero = $true },
            @{ Key = 'NotInstalled'; Text = '未安装'; SkipZero = $true }
        )
        $Result.Ok = ($Result.Failed -eq 0)
        if ($Result.Failed -gt 0) {
            if ($Result.Network) { $Result.ExitCode = 2 } else { $Result.ExitCode = 3 }
        }
    }

    # 指定 id 但一个都没安装 → 参数错误（优先级高于「有可更新项」，否则 --check 的 4 会把参数错误吞掉）
    if (@($Explicit).Count -gt 0 -and $InstalledTargets -eq 0) {
        Write-Host ''
        if ($DownloadOnlySkipped -gt 0 -and $DownloadOnlySkipped -ge @($Explicit).Count) {
            # 全是「仅下载」类型：更新对它们没意义，改指向它们真正的三个操作
            Write-Host '  指定的软件都是「仅下载」类型（不安装、不写安装记录）：请用 winst download <id> 下载 / 更新软件包，winst clean <id> 删除软件包。' -ForegroundColor Yellow
        } else {
            Write-Host '  指定的软件都没有安装记录，更新无从执行（安装请用 winst install）。' -ForegroundColor Yellow
        }
        $Result.ExitCode = 1
        $Result.Ok = $false   # Ok 与 ExitCode 必须一致：调用方有按 Ok 判定成功的
    }
    return $Result
}
