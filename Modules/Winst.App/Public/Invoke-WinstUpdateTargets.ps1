#Requires -Version 5.1

function Invoke-WinstUpdateTargets {
    <#
    .SYNOPSIS
        检查 / 执行更新：解析目标集合 → 取软件源最新版本 → 比较 → 复用安装流程更新。
    .DESCRIPTION
        - `-All` 或未指定 id：遍历安装记录里的全部软件；指定 id：只处理这些软件（未安装项报告并跳过）。
        - `-Check` 仅报告。
        - `-DownloadOnly` 只刷新软件包缓存，不安装。
        - `-FilesOnly` 仅更新文件：完全不处理环境变量 / PATH / 快捷方式（多个同族软件共存时，
          避免更新其中一个就把 `JAVA_HOME` 之类的共享变量改写；
          不带该开关时按「设置 → 更新方式」——默认档「只更新文件」对更新同样是**完全不处理**系统项，
          CLI 与菜单两条入口在更新场景下行为一致，差别只在首次安装时是否补齐（`--files-only` 不补）。
        - `-ForceSystemItems` 完整更新：按软件源里的定义覆盖已存在的环境变量 / 快捷方式，忽略「设置 → 更新方式」。
        - `-SourceName` 明确指定用哪个软件源更新（CLI `--source` / 「自定义更新」）；
          缺省优先**安装时选择的那个来源**（安装记录 `manifestOrigin`），它不可用、或它没有比本机更新的版本
          而别的来源有 → 回退到「有更新版本」的来源并说明；都没命中才按默认优先级
          （本地清单 → 内置源 → 其它按添加顺序）。
        - external 记录规则：installer 类可更新（成功后转为 winst 管理）；
          免安装版 / 单文件程序一律只报告、不覆盖。
        单条软件的判定与执行见 Invoke-WinstUpdateEntry；汇总与退出码见 Write-WinstUpdateExitCode。
    .OUTPUTS
        @{ Ok; ExitCode; Updatable; Updated; Skipped; Failed; UpToDate; NotInstalled; Unknown;
           Reported; Network; RefreshErrors; Entries }
    #>
    param(
        [Parameter(Mandatory = $true)][hashtable]$Context,
        [string[]]$Ids = @(),
        [switch]$All,
        [switch]$Check,
        [switch]$DownloadOnly,
        [switch]$Force,
        [switch]$Yes,
        [switch]$Quiet,
        [switch]$AutoPickSource,
        [switch]$NoRefresh,
        [switch]$FilesOnly,
        [switch]$ForceSystemItems,
        [string]$SourceName = ''
    )

    $result = @{
        Ok = $false; ExitCode = 0; Updatable = 0; Updated = 0; Skipped = 0; Failed = 0;
        UpToDate = 0; NotInstalled = 0; Unknown = 0; Reported = 0; Network = $false;
        RefreshErrors = @(); Entries = @()
    }

    # 0. 读台账 / 目标集合 / 按需刷新 / 搜索目录
    $targets = Resolve-WinstUpdateTargets -Context $Context -Ids $Ids -All:$All -Quiet:$Quiet -NoRefresh:$NoRefresh -Result $result
    if ($targets.Empty) {
        # 读台账失败时 ExitCode 已被置 1（Ok 保持 false）；正常「没有已安装软件」则视为成功
        if ([int]$result.ExitCode -eq 0) { $result.Ok = $true }
        return $result
    }
    $state = $targets.State
    $autoPick = [bool]$AutoPickSource -or [bool]$Yes
    $installedTargets = 0
    $downloadOnlySkipped = 0   # 指定 id 里「仅下载」类型的条数（结尾提示据此改口径）
    $entries = @()

    foreach ($id in @($targets.TargetIds)) {
        $one = Invoke-WinstUpdateEntry -Context $Context -Id $id -State $state -RowById $targets.RowById `
            -Check:$Check -DownloadOnly:$DownloadOnly -Force:$Force -Yes:$Yes -Quiet:$Quiet `
            -AutoPick $autoPick -FilesOnly:$FilesOnly -ForceSystemItems:$ForceSystemItems -SourceName $SourceName `
            -Result $result
        if ($one.Entries.Count -gt 0) { $entries += @($one.Entries) }
        if ($one.Installed) { $installedTargets++ }
        if ($one.DownloadOnlySkipped) { $downloadOnlySkipped++ }
        if ($one.RefreshState) { $state = (Read-WinstState -InstallRoot $Context.InstallRoot).State }
    }

    $result.Entries = @($entries)
    return (Write-WinstUpdateExitCode -Result $result -Check:$Check -Quiet:$Quiet `
            -Explicit (@($targets.Explicit)) -InstalledTargets $installedTargets -DownloadOnlySkipped $downloadOnlySkipped)
}
