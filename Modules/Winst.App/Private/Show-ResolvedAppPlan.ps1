#Requires -Version 5.1

function Show-ResolvedAppPlan {
    <#
    .SYNOPSIS
        渲染单个软件的软件清单：下载 → 安装 → 复制/改名 → 环境变量 → 安装后命令 → 版本检测 → 卸载。
    .DESCRIPTION
        路径按本机设置展开为实际值，便于普通用户直接阅读；%VAR% 形式的引用按原样保留
        （含义是「跟随该环境变量的值」，切换变量即可整体切换版本）。
        软件源里配置了依赖（dependencies）时，在「来源」之后列出依赖的软件与各自状态；
        `-Context` 缺省（$null）时不展示依赖。
        本函数只做编排：视图变量由 New-WinstPlanViewState 计算，各阶段由 Write-WinstPlan*Stage 渲染。
    #>
    param(
        $Plan,
        [int]$Index = 0,
        [int]$Total = 0,
        [string]$SourceName = '',
        [string]$InstallRoot = '',
        [string]$PkgDir = '',
        [string]$DesktopDir = '',
        [string]$StartMenuDir = '',
        [string]$InstalledVersion = '',
        [string]$InstalledDir = '',
        [hashtable]$Context = $null
    )

    $view = New-WinstPlanViewState -Plan $Plan -Index $Index -Total $Total -SourceName $SourceName `
        -InstallRoot $InstallRoot -PkgDir $PkgDir -DesktopDir $DesktopDir -StartMenuDir $StartMenuDir `
        -InstalledVersion $InstalledVersion -InstalledDir $InstalledDir

    Write-WinstPlanHeader -Plan $Plan -View $view -Context $Context

    if (-not $view.Ok) {
        # 清单有误时把备注全部打出来（不过滤技术说明），方便看到配置本身的错
        foreach ($note in @(Get-EntryArray -Entry $Plan -Key 'notes')) {
            Write-Host ('    说明: {0}' -f $note) -ForegroundColor DarkYellow
        }
        return
    }

    # 校验说明的展示名取自 Get-WinstHashRule（Winst.Store），由这里传入委托，
    # 使 Write-WinstPlanDownloadStage 本身不必依赖 Store
    Write-WinstPlanDownloadStage -Plan $Plan -View $view -HashRuleFor { param($kind) Get-WinstHashRule -Kind $kind }

    # 仅下载类型：只显示「下载（软件包）」与「删除已下载的软件包」，
    # 安装 / 复制 / 环境变量 / 安装后命令 / 版本检测这几段对它都不存在，直接跳过。
    if ($view.IsDownloadType) {
        Write-WinstPlanDownloadOnlyStages -View $view
        Write-WinstPlanNotes -Plan $Plan
        return
    }

    $mainProgram = Write-WinstPlanInstallStage -Plan $Plan -View $view
    Write-WinstPlanCopyStage -Plan $Plan -View $view
    Write-WinstPlanEnvStage -Plan $Plan -View $view
    Write-WinstPlanCommandStage -Plan $Plan -View $view
    Write-WinstPlanDetectStage -Plan $Plan -View $view -MainProgram $mainProgram
    Write-WinstPlanUninstallStage -Plan $Plan -View $view
    Write-WinstPlanNotes -Plan $Plan
}
