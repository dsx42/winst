#Requires -Version 5.1

function Get-WinstUninstallTargets {
    <#
    .SYNOPSIS
        汇总卸载一个软件要执行的动作：安装记录里的卸载快照 + 软件源里的当前定义 + 已登记的系统项，去重合并。
    .DESCRIPTION
        两处定义**都要执行、不重复执行**——同一个动作（同一次卸载程序调用、同一个 PATH 项 /
        环境变量 / 快捷方式）只做一次；卸载方式（删目录 / 跑官方卸载器 / 清缓存）冲突时以**安装记录**为准，
        那是这台机器上真实的安装方式，并给出提示。两处都没有卸载定义时回退为「删安装目录 + 移除安装记录」。
        软件源信息取自**已刷新的软件清单**，不额外联网（软件源里删掉该软件也能正常卸载）。
        卸载方式判定 / 系统项合并 / 命令合并 各由合并函数承担。
    .OUTPUTS
        @{ Id; Type; Version; Managed; External; IsSelf; Method; Sources; Notes; InstallDir;
           Env; PathItems; Shortcuts; Commands; CleanupItems; NameRule; UninstallArgs; ManifestPlan }
    #>
    param(
        [Parameter(Mandatory = $true)][hashtable]$Context,
        [Parameter(Mandatory = $true)][string]$Id,
        [Parameter(Mandatory = $true)]$Entry
    )

    $type = (Get-EntryString -Entry $Entry -Key 'type').Trim().ToLowerInvariant()
    $managed = Get-EntryString -Entry $Entry -Key 'managed'
    if (-not $managed) { $managed = 'winst' }
    $isSelf = ($Id -ieq 'winst')

    $installDir = Get-EntryString -Entry $Entry -Key 'installDir'
    if ($isSelf -and $Context.InstallRoot) { $installDir = Join-Path $Context.InstallRoot 'winst' }

    $external = ($managed -ne 'winst' -and -not $isSelf)

    # ① 安装记录快照 ② 软件源当前定义 ③ 卸载方式（冲突时以安装记录为准）
    $recordSnapshot = ConvertTo-WinstUninstallSnapshot -Block (Get-EntryValue -Entry $Entry -Key 'uninstall' -Default $null)

    # 仅登记（external）的条目同样取：软件源里定义了卸载方式时，卸载按它执行——如 Windows App Runtime
    # 由系统 / 其它软件带装，但清单里定义了应用包卸载规则，「不是 winst 装的」不该等于「卸载不了」
    $manifestPlan = Get-WinstLockedPlan -Context $Context -Id $Id
    $manifestSnapshot = ConvertTo-WinstUninstallSnapshot -Block $null
    if ($manifestPlan) { $manifestSnapshot = Get-WinstUninstallSnapshotFromPlan -Plan $manifestPlan }
    $hasManifest = -not (Test-WinstUninstallSnapshotEmpty -Snapshot $manifestSnapshot)

    $methodInfo = Resolve-WinstUninstallMethod -IsSelf:$isSelf -External:$external `
        -RecordSnapshot $recordSnapshot -ManifestSnapshot $manifestSnapshot -HasManifest:$hasManifest
    $method = [string]$methodInfo.Method
    $notes = @($methodInfo.Notes)
    $sources = @($methodInfo.Sources)

    # ④ 合并要回收的系统项（去重）
    $defaultScope = Get-WinstInstallScope -InstallDir $installDir
    $merged = Merge-WinstUninstallEnvItems -Entry $Entry -RecordSnapshot $recordSnapshot -ManifestSnapshot $manifestSnapshot `
        -DefaultScope $defaultScope -InstallDir $installDir -InstallRoot $Context.InstallRoot
    $envList = @($merged.Env)
    $pathList = @($merged.Path)
    $shortcuts = @(Merge-WinstUninstallShortcuts -Entry $Entry -ManifestPlan $manifestPlan)
    $commands = @(Merge-WinstUninstallCommands -RecordSnapshot $recordSnapshot -ManifestSnapshot $manifestSnapshot)
    $cleanupItems = @(New-WinstUninstallCleanupItems -Env $envList -PathItems $pathList -Shortcuts $shortcuts)

    # 名称规则支持数组：字符串与数组都按原样透传
    $nameRule = @($recordSnapshot['nameRule'] | Where-Object { $null -ne $_ -and ([string]$_) })
    if ($nameRule.Count -eq 0) { $nameRule = @($manifestSnapshot['nameRule'] | Where-Object { $null -ne $_ -and ([string]$_) }) }
    $uninstallArgs = [string]$recordSnapshot['uninstallArgs']
    if (-not $uninstallArgs) { $uninstallArgs = [string]$manifestSnapshot['uninstallArgs'] }

    return @{
        Id            = $Id
        Type          = $type
        # 卸载确认页要展示的当前版本号：取安装记录里的值，识别不出时为 unknown / 空（由展示层说明，不猜）
        Version       = (Get-EntryString -Entry $Entry -Key 'version')
        Managed       = $managed
        External      = $external
        IsSelf        = $isSelf
        Method        = $method
        Sources       = @($sources)
        Notes         = @($notes)
        InstallDir    = $installDir
        Env           = @($envList)
        PathItems     = @($pathList)
        Shortcuts     = @($shortcuts)
        Commands      = @($commands)
        CleanupItems  = @($cleanupItems)
        NameRule      = $nameRule
        UninstallArgs = $uninstallArgs
        ManifestPlan  = $manifestPlan
    }
}
