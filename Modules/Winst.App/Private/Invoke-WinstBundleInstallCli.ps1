#Requires -Version 5.1

function Invoke-WinstBundleInstallCli {
    <#
    .SYNOPSIS
        CLI `bundle install [<file>] [--skip-existing]`：按安装清单逐个安装，单个失败不中断。
    .DESCRIPTION
        缺省使用 lists\setup.list（不存在时报错并列出可选清单）；`--skip-existing` 时**已安装（任意版本）**
        的条目直接跳过（重装后幂等补装）。每条复用 `Invoke-WinstInstallTarget`（未加 --yes 时仍逐个确认）。
        退出码：0 成功 / 1 参数或清单问题 / 3 存在失败项。
    #>
    param(
        [Parameter(Mandatory = $true)][hashtable]$Context,
        [string]$Path = '',
        [switch]$SkipExisting
    )

    Write-Section 'winst bundle install'

    $target = Resolve-WinstListFileForCli -Context $Context -Text $Path
    if (-not $target.Ok) { return 1 }

    $loaded = Get-WinstListItems -Context $Context -Path ([string]$target.Path)
    if (-not $loaded.Ok) {
        Write-Host ''
        Write-Host ('  {0}' -f $loaded.Error) -ForegroundColor Red
        return 1
    }
    if ($loaded.Warning) { Write-Host ('  提示: {0}' -f $loaded.Warning) -ForegroundColor DarkYellow }
    if (@($loaded.Items).Count -eq 0) {
        Write-Host ''
        Write-Host ('  {0}里还没有软件。' -f [string]$target.Path) -ForegroundColor Yellow
        return 1
    }

    Write-Host ''
    Write-Host ('  安装清单: {0}（{1} 项）' -f [string]$target.Path, @($loaded.Items).Count) -ForegroundColor Gray
    $null = Show-WinstListContent -Context $Context -Items $loaded.Items -Quiet

    $yes = [bool]((Get-WinstState -Name WinstOptions) -and (Get-WinstState -Name WinstOptions).Yes)
    $stats = Invoke-WinstBundleInstallRun -Context $Context -Items @($loaded.Items) -InstallYes:$yes `
        -SkipExisting:$SkipExisting -Presentation Cli

    Write-Host ''
    Write-WinstBundleInstallSummary -Stats $stats

    $failCount = [int]$stats['FailCount']
    $okCount = [int]$stats['OkCount']
    $skipCount = [int]$stats['SkipCount']
    if ($failCount -gt 0) { return 3 }
    if ($okCount -eq 0 -and $skipCount -eq 0) { return 1 }
    return 0
}
