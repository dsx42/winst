#Requires -Version 5.1

function Invoke-BundleInstall {
    <#
    .SYNOPSIS
        菜单「一键安装」：按安装清单批量安装。
    .DESCRIPTION
        输入安装清单的编号，确认后开始安装。
        安装复用 `Invoke-WinstInstallTarget`（含「已装同版本跳过、强制重装询问、缓存命中不重复下载、
        更新方式取设置」，与「安装软件」完全同一套决策），清单确认过一次后执行时不逐个询问。
        清单固定版本与可用版本不一致或可用版本未知时，提示用户选择继续或跳过。离线时核对缓存包。
    #>
    param([hashtable]$Context)

    Write-Section '一键安装'

    $picked = Select-WinstListFile -Context $Context -NoCreate
    if (-not $picked.Ok) {
        Write-Host ''
        if ($picked.Cancelled) {
            if (-not (Get-WinstState -Name WinstQuitRequested)) {
                Write-Host '  已返回。' -ForegroundColor DarkGray
                $null = Set-WinstState -Name WinstSkipMenuPause -Value ($true)
            }
            return
        }
        Write-Host ('  {0}' -f $picked.Error) -ForegroundColor Red
        return
    }

    $loaded = Get-WinstListItems -Context $Context -Path ([string]$picked.Path) -RefreshSources -BundleInstall
    if (-not $loaded.Ok) {
        Write-Host ''
        Write-Host ('  {0}' -f $loaded.Error) -ForegroundColor Red
        return
    }
    $Context = $loaded.Context
    if ($loaded.Warning) { Write-Host ('  提示: {0}' -f $loaded.Warning) -ForegroundColor DarkYellow }

    if (-not $loaded.Exists -or @($loaded.Items).Count -eq 0) {
        Write-Host ''
        Write-Host '  这份安装清单是空的，没有可安装的软件。' -ForegroundColor Yellow
        Write-Host ('  清单文件: {0}' -f [string]$picked.Path) -ForegroundColor DarkGray
        Write-Host '  请先到「高级功能 → 管理安装清单」里新建或编辑清单，挑选软件。' -ForegroundColor DarkGray
        return
    }


    Write-Host ''
    Write-Host ('  安装清单: {0}' -f [string]$picked.Path) -ForegroundColor Gray
    Show-WinstListContent -Context $Context -Items $loaded.Items -StateRead $loaded.Lookup.StateRead

    $yes = [bool]((Get-WinstState -Name WinstOptions) -and (Get-WinstState -Name WinstOptions).Yes)
    if (-not $yes) {
        if (-not (Read-WinstConfirm -Prompt '  确认按这份清单逐个安装？(y/N)' -Default 'n')) {
            Write-Host '  已取消。' -ForegroundColor DarkGray
            return
        }
    }

    $pinAuto = [bool]((Get-WinstState -Name WinstOptions) -and (Get-WinstState -Name WinstOptions).Yes)
    $stats = Invoke-WinstBundleInstallRun -Context $Context -Items @($loaded.Items) -InstallYes `
        -PinAutoContinue:$pinAuto -Presentation Menu
    Write-Host ''
    Write-WinstBundleInstallSummary -Stats $stats
}
