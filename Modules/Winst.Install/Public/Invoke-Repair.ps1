#Requires -Version 5.1

function Invoke-Repair {
    <#
    .SYNOPSIS
        「修复安装记录」：扫描本机，按已加载清单重建 / 补全安装台账。
    .DESCRIPTION
        ① 扫描 installRoot 下**全部子目录**：目录名与清单 id 匹配的按该条目 detect 识别版本；
           清单里没有对应条目的目录也照常登记（id = 目录名，version / type 留空）；
        ② 扫描注册表 Uninstall 键，与 installer 类型条目匹配（名称规则取 detect.name，缺省按条目
           name 推导）——安装版软件可能装在 installRoot 之外，命中即登记，installDir 取 InstallLocation；
        ②′ 扫描系统应用包记录（detect.method = appx 的条目，如 Windows App Runtime）：安装包是 .exe
           安装器、装完以应用包存在——既没有安装目录也不写注册表卸载项，只能从应用包记录识别；
        ③ 已有记录：版本与本次识别结果不一致时**更新记录里的版本**（含 unknown → 识别值），
           其余字段保持原值；本次未识别出版本时不动记录；清单里有、但本机未找到的软件不登记；
        ④ 已有记录（含与记录一致的）照样展示；目录缺失的台账条目只报告，不删除记录、不动系统项；
        ⑤ 校对安装包缓存索引 pkgDir\winst.json（缺失 / 损坏时重建，不删除任何文件）；
        修复**只写 state.json**（与必要的索引重建）：不删环境变量、不删快捷方式等任何文件；
        安装异常请按需「重新安装 / 更新 / 卸载」处理（卸载会按台账登记回收系统项）。
        **措辞**：修复只做「记录 ↔ 磁盘实际」的校对，因此逐条只说「与记录一致 / 更正版本 / 补全版本 /
        软件源里没有这个软件（仅按目录登记）」，不出现「无需更新」——是否需要更新由「检查更新」与
        「已装软件」里的 `↑ 可更新到 x.y` 负责，避免同一台机器上两处说法互相打脸。
        本函数只做编排：清单 → 三类扫描 → 合并 → 落盘 → 汇总，各段由独立函数承担。
    .OUTPUTS
        退出码：0 = 完成（含无变更）；1 = 无法执行（台账版本过高 / 读取失败）
    #>
    param(
        [Parameter(Mandatory = $true)][hashtable]$Context,
        # 被其它流程（如进入「已装软件」列表时）内嵌调用：不打印标题 / 进度 / 逐条「已登记」，
        # 只报告本次真正发生的改动与一行汇总
        [switch]$Quiet
    )

    if (-not $Quiet) { Write-Section '修复安装记录' }

    $dryRun = [bool]((Get-WinstState -Name WinstOptions) -and (Get-WinstState -Name WinstOptions).DryRun)
    $verbose = [bool]((Get-WinstState -Name WinstOptions) -and (Get-WinstState -Name WinstOptions).Verbose)

    $catalog = Get-WinstRepairCatalog -Context $Context -Quiet:$Quiet
    $planLookup = $catalog.Plan
    $sourceLookup = $catalog.Source
    $ciIdLookup = $catalog.CiId
    $canScan = [bool]$catalog.CanScan

    $stateRead = Read-WinstState -InstallRoot $Context.InstallRoot
    if ($stateRead.Error -and -not $stateRead.Reset) {
        Write-Host ''
        Write-Host ('  {0}' -f $stateRead.Error) -ForegroundColor Red
        return 1
    }
    if ($stateRead.Error) { Write-Host ('  提示: {0}' -f $stateRead.Error) -ForegroundColor Yellow }
    $state = $stateRead.State
    $ledgerBefore = @($state['Installed'].Keys).Count

    # —— ② 扫描安装根目录 → ③ 注册表 → ③′ 应用包 → ④ 目录登记 ——
    $found = New-WinstOrdinalDictionary
    $dirRecords = @(Get-WinstInstallDirRecords -Context $Context -Plan $planLookup -Source $sourceLookup -CiId $ciIdLookup -Quiet:$Quiet)

    if ($canScan) {
        Get-WinstRegistryScanRecords -Context $Context -Plan $planLookup -Source $sourceLookup -Found $found -Quiet:$Quiet -VerboseOutput:$verbose
        Get-WinstAppxScanRecords -Context $Context -Plan $planLookup -Source $sourceLookup -Found $found -Quiet:$Quiet -VerboseOutput:$verbose
    }
    Merge-WinstDirScanRecords -Context $Context -DirRecords $dirRecords -Found $found -VerboseOutput:$verbose

    # —— ⑤ 合并台账 ——
    $counters = @{ Added = 0; Filled = 0; Updated = 0; Kept = 0; DirOnlyAdded = 0; Changed = $false }
    Update-WinstLedgerFromScan -Context $Context -State $state -Found $found -Plan $planLookup `
        -Now ((Get-Date).ToString('s')) -Counters $counters -Quiet:$Quiet

    # —— ⑥ 目录缺失的台账条目（只报告） ——
    $missingDirs = @(Get-WinstMissingLedgerDirs -State $state)

    # —— ⑦ 校对安装包缓存索引 ——
    $indexNote = Sync-WinstRepairCacheIndex -Context $Context -DryRun:$dryRun

    # —— ⑧ 落盘 ——
    $save = Save-WinstRepairState -Context $Context -State $state -Changed ([bool]$counters.Changed) `
        -NeedSave ([bool]$stateRead.NeedSave) -DryRun:$dryRun
    if ($save.Error) {
        Write-Host ''
        Write-Host ('  安装记录写入失败: {0}' -f $save.Error) -ForegroundColor Red
        return 1
    }

    # —— 汇总 ——
    return (Write-WinstRepairSummary -Context $Context -State $state -Quiet:$Quiet -DryRun:$dryRun `
        -Saved ([bool]$save.Saved) -Counters $counters -LedgerBefore $ledgerBefore -IndexNote $indexNote -MissingDirs $missingDirs)
}
