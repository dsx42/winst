#Requires -Version 5.1

function Invoke-WinstListShow {
    <#
    .SYNOPSIS
        「查看清单」：管理安装清单 里输入编号后直接调用（没有单独的查看菜单项）；
        不指定清单时列出全部清单文件，指定后逐项显示内容与状态。
    #>
    param(
        [Parameter(Mandatory = $true)][hashtable]$Context,
        [string]$Path = ''
    )

    $kindText = (Get-WinstListKindText)
    Write-Section ('查看' + $kindText)

    if (-not (Assert-WinstContext $Context)) { return }

    $targetPath = ''
    if ($Path) {
        # 解析 + 报错文案在 Resolve-WinstListTargetPath 里（编辑 / 查看两页共用）
        $targetPath = Resolve-WinstListTargetPath -Context $Context -Path $Path
        if (-not $targetPath) { return }
    } else {
        $files = @(Get-WinstListFiles -Context $Context)
        Write-Host ''
        if ($files.Count -eq 0) {
            Write-Host ('  lists 目录里还没有{0}。' -f $kindText) -ForegroundColor Yellow
            Write-Host ('  清单目录: {0}' -f (Get-WinstListsDir -Context $Context)) -ForegroundColor DarkGray
            Write-Host ('  可到「高级功能 → 管理{0}」里新建。' -f $kindText) -ForegroundColor DarkGray
            return
        }

        if ($files.Count -eq 1) {
            $targetPath = [string]$files[0]['Path']
        } else {
            Write-Host ('  已有的{0}：' -f $kindText) -ForegroundColor Gray
            Write-WinstListFileRows -Files $files
            Write-Host ''
            $pick = @(Read-WinstSelection -Count $files.Count -Single)
            if ($pick.Count -eq 0) {
                Write-Host '  已返回。' -ForegroundColor DarkGray
                return
            }
            $targetPath = [string]$files[[int]$pick[0] - 1]['Path']
        }
    }

    $loaded = Get-WinstListItems -Context $Context -Path $targetPath
    if (-not $loaded.Ok) {
        Write-Host ''
        Write-Host ('  {0}' -f $loaded.Error) -ForegroundColor Red
        return
    }
    if ($loaded.Warning) { Write-Host ('  提示: {0}' -f $loaded.Warning) -ForegroundColor DarkYellow }
    if (@($loaded.BadLines).Count -gt 0) {
        Write-Host ('  提示: 清单里有 {0} 行无法识别，编辑保存时会丢弃这些行。' -f @($loaded.BadLines).Count) -ForegroundColor DarkYellow
    }

    Write-Host ''
    Write-Host ('  {0}' -f $targetPath) -ForegroundColor Gray
    if (-not $loaded.Exists) {
        Write-Host ('  这个{0}还不存在（空的）。' -f $kindText) -ForegroundColor Yellow
        return
    }
    if (@($loaded.Items).Count -eq 0) {
        Write-Host ('  {0}里还没有软件。' -f $kindText) -ForegroundColor Yellow
        Write-Host ('  可到「高级功能 → 管理{0}」里编辑这份清单，挑选软件加入。' -f $kindText) -ForegroundColor DarkGray
        return
    }

    # 清单里的软件才是要展示的：按需刷新它们的版本信息
    $listIds = @(Get-WinstDisplayIds -Items $loaded.Items)
    $refresh = Update-WinstDisplaySources -Context $Context -Ids $listIds -Quiet
    Write-WinstRefreshErrors -Errors $refresh.Errors


    Write-Host ''
    $null = Show-WinstListContent -Context $Context -Items $loaded.Items
}
