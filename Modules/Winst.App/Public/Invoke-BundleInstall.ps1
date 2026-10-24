#Requires -Version 5.1

function Invoke-BundleInstall {
    <#
    .SYNOPSIS
        菜单「一键安装」：按安装清单批量安装。
    .DESCRIPTION
        选安装清单（列出已有清单，或输入文件名 / 路径）→ 显示清单内容与每项状态
        （已装 x.y / 已有安装包 / 需联网下载 / 软件源里没有）→ 确认后逐个安装。
        安装复用 `Invoke-WinstInstallTarget`（含「已装同版本跳过、强制重装询问、缓存命中不重复下载、
        更新方式取设置」，与「安装软件」完全同一套决策），清单确认过一次后执行时不逐个询问。
        清单里写了 `id==版本` 而软件源版本不一致时，先提示并让用户选择「按软件源里的版本安装」或「跳过」。
    #>
    param([hashtable]$Context)

    Write-Section '一键安装'

    if (-not (Assert-WinstContext $Context)) { return }

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

    $loaded = Get-WinstListItems -Context $Context -Path ([string]$picked.Path)
    if (-not $loaded.Ok) {
        Write-Host ''
        Write-Host ('  {0}' -f $loaded.Error) -ForegroundColor Red
        return
    }
    if ($loaded.Warning) { Write-Host ('  提示: {0}' -f $loaded.Warning) -ForegroundColor DarkYellow }

    if (-not $loaded.Exists -or @($loaded.Items).Count -eq 0) {
        Write-Host ''
        Write-Host '  这份安装清单是空的，没有可安装的软件。' -ForegroundColor Yellow
        Write-Host ('  清单文件: {0}' -f [string]$picked.Path) -ForegroundColor DarkGray
        Write-Host '  请先到「高级功能 → 管理安装清单」里新建或编辑清单，挑选软件。' -ForegroundColor DarkGray
        return
    }

    # 清单里的软件才是要展示 / 安装的：按需刷新它们的版本信息
    $bundleIds = @(Get-WinstDisplayIds -Items $loaded.Items)
    $refresh = Update-WinstDisplaySources -Context $Context -Ids $bundleIds -Quiet
    Write-WinstRefreshErrors -Errors $refresh.Errors


    Write-Host ''
    Write-Host ('  安装清单: {0}' -f [string]$picked.Path) -ForegroundColor Gray
    $null = Show-WinstListContent -Context $Context -Items $loaded.Items

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
