#Requires -Version 5.1
<#
    Initialize-WinstState.ps1  (Winst.Core / Public)

    声明全部跨模块状态项及其初值。

    为什么需要专门的初始化函数
    --------------------------
    每个状态项都必须在其它模块读取之前就存在，否则首次读取得到 $null，
    随后像

        (Get-WinstState -Name WinstHttpCache).ContainsKey($key)

    这样的代码就会抛「不能对空值表达式调用方法」。

    Set-StrictMode -Version 2 要求这件事必须显式完成：读取未定义变量会报错，
    而状态查询返回 $null。提前初始化就让「始终存在」成为默认。

    调用方：
        winst.ps1，紧接着 Winst.Core 导入之后。

    幂等：
        重复执行只补仍然为 $null 的项，因此同一会话内入口跑两次也不会丢掉进程内缓存。
#>

function Initialize-WinstState {
    <#
    .SYNOPSIS
        创建跨模块状态项及其初值。

    .DESCRIPTION
        只设置从未设置过的项。已经持有数据（本会话早前填过的缓存）的值不动。

    .OUTPUTS
        [int] 本次初始化的项数
    #>
    [CmdletBinding()]
    [OutputType([int])]
    param()

    $initialized = 0

    # ------------------------------------------------------------ 标志
    # 菜单 / CLI 的控制流。
    if (-not (Test-WinstState -Name 'WinstMenuMode')) {
        $null = Set-WinstState -Name 'WinstMenuMode' -Value $false
        $initialized++
    }

    if (-not (Test-WinstState -Name 'WinstQuitRequested')) {
        $null = Set-WinstState -Name 'WinstQuitRequested' -Value $false
        $initialized++
    }

    if (-not (Test-WinstState -Name 'WinstSkipMenuPause')) {
        $null = Set-WinstState -Name 'WinstSkipMenuPause' -Value $false
        $initialized++
    }

    # 全局选项集合，多个模块都会读。
    if (-not (Test-WinstState -Name 'WinstOptions')) {
        $null = Set-WinstState -Name 'WinstOptions' -Value $null
        $initialized++
    }

    # ------------------------------------------------------------ 缓存
    # HTTP 响应缓存（Winst.Net）。
    if ($null -eq (Get-WinstState -Name 'WinstHttpCache')) {
        $null = Set-WinstState -Name 'WinstHttpCache' -Value (New-Object 'System.Collections.Hashtable' ([StringComparer]::Ordinal))
        $initialized++
    }

    # JSON 解析缓存（Winst.Core）。
    if ($null -eq (Get-WinstState -Name 'WinstJsonCache')) {
        $null = Set-WinstState -Name 'WinstJsonCache' -Value (New-Object 'System.Collections.Hashtable' ([StringComparer]::OrdinalIgnoreCase))
        $initialized++
    }

    # 目录聚合缓存（Winst.Catalog）。
    # 三个条目初始化成 $null 表示「尚无缓存」；Get-WinstState 用 -NoEnumerate 输出，
    # 因此空数组 / 空字典是有效缓存值，与 $null 可区分。
    if (-not (Test-WinstState -Name 'WinstAllAppsCache')) {
        $null = Set-WinstState -Name 'WinstAllAppsCache' -Value $null
        $initialized++
    }

    if (-not (Test-WinstState -Name 'WinstSearchCatalogCache')) {
        $null = Set-WinstState -Name 'WinstSearchCatalogCache' -Value $null
        $initialized++
    }

    if (-not (Test-WinstState -Name 'WinstDependencyIndex')) {
        $null = Set-WinstState -Name 'WinstDependencyIndex' -Value $null
        $initialized++
    }

    if ($null -eq (Get-WinstState -Name 'WinstCatalogRefreshed')) {
        $null = Set-WinstState -Name 'WinstCatalogRefreshed' -Value (New-Object 'System.Collections.Hashtable' ([StringComparer]::Ordinal))
        $initialized++
    }

    # 本次进程内「解析成功但落盘不可用」的软件源（目标盘不可见 / 只读）：
    # 源有效期靠 meta.json 判断，写不进去就永远是「过期」，于是每次列表 / 检查 / 安装都会
    # 重跑一遍同样的网络请求与解析。记下来，同一进程内不再为同一个源重复刷新。
    if ($null -eq (Get-WinstState -Name 'WinstManifestPersistUnavailable')) {
        $null = Set-WinstState -Name 'WinstManifestPersistUnavailable' -Value (New-Object 'System.Collections.Hashtable' ([StringComparer]::Ordinal))
        $initialized++
    }

    # 台账读缓存（Winst.Store）：按文件戳缓存解析 + 归一化后的台账，写入侧 Save-WinstState 负责刷新。
    # 台账在一次操作里会被反复读，一次完整解析在几十条记录时是百毫秒级。
    if ($null -eq (Get-WinstState -Name 'WinstStateReadCache')) {
        $null = Set-WinstState -Name 'WinstStateReadCache' -Value (New-Object 'System.Collections.Hashtable' ([StringComparer]::OrdinalIgnoreCase))
        $initialized++
    }

    # 单进程锁的独占文件句柄（Winst.Core）。必须挂在状态里：局部变量被回收会让锁提前释放。
    if (-not (Test-WinstState -Name 'WinstInstanceLock')) {
        $null = Set-WinstState -Name 'WinstInstanceLock' -Value $null
        $initialized++
    }

    # 短 TTL 的系统快照（Winst.System）。
    if ($null -eq (Get-WinstState -Name 'WinstRegistryEntriesCache')) {
        $null = Set-WinstState -Name 'WinstRegistryEntriesCache' -Value $null
        $initialized++
    }

    if ($null -eq (Get-WinstState -Name 'WinstEnvironmentCache')) {
        $null = Set-WinstState -Name 'WinstEnvironmentCache' -Value $null
        $initialized++
    }

    if ($null -eq (Get-WinstState -Name 'WinstAppxCache')) {
        $null = Set-WinstState -Name 'WinstAppxCache' -Value $null
        $initialized++
    }

    if ($null -eq (Get-WinstState -Name 'WinstProcessCache')) {
        $null = Set-WinstState -Name 'WinstProcessCache' -Value $null
        $initialized++
    }

    if ($null -eq (Get-WinstState -Name 'WinstLocalManifestFilesCache')) {
        $null = Set-WinstState -Name 'WinstLocalManifestFilesCache' -Value $null
        $initialized++
    }

    # 引擎路径缓存（Winst.Engine）。
    if ($null -eq (Get-WinstState -Name 'WinstEnginePathCache')) {
        $null = Set-WinstState -Name 'WinstEnginePathCache' -Value $null
        $initialized++
    }

    # 进程级「已检查过」标记（Winst.Install）。
    if ($null -eq (Get-WinstState -Name 'WinstEngineUpdateChecked')) {
        $null = Set-WinstState -Name 'WinstEngineUpdateChecked' -Value (New-Object 'System.Collections.Hashtable' ([StringComparer]::Ordinal))
        $initialized++
    }

    if ($null -eq (Get-WinstState -Name 'WinstSelfChecked')) {
        $null = Set-WinstState -Name 'WinstSelfChecked' -Value $false
        $initialized++
    }

    # 浏览器临时配置目录路径（Winst.Browser）。
    if ($null -eq (Get-WinstState -Name 'WinstBrowserProfileDir')) {
        $null = Set-WinstState -Name 'WinstBrowserProfileDir' -Value ''
        $initialized++
    }

    # SettingChange P/Invoke 就绪标志（Winst.System）。
    if ($null -eq (Get-WinstState -Name 'WinstSettingChangeReady')) {
        $null = Set-WinstState -Name 'WinstSettingChangeReady' -Value $false
        $initialized++
    }

    return $initialized
}

function Set-WinstScriptLocation {
    <#
    .SYNOPSIS
        Record where winst itself is running from.

    .DESCRIPTION
        有两处调用依赖它，且都不可缺：

        - Winst.Manifest / Get-LocalManifestFiles 会在脚本同目录找 manifest.json
          与 manifests\*.json。WinstScriptDir 为空时本地清单不会被发现，
          「local」源会直接从源列表里消失。

        - Winst.Install / Get-WinstSelfPackageSource 与
          Invoke-WinstPackageDownloadLoop 用 WinstScriptPath 把当前运行的脚本
          当作 winst 自身的离线安装包。为空时离线自安装会报「没有可用的安装包」，
          而不是退回当前运行的副本。

        这里不能用 $PSCommandPath / $MyInvocation：在模块内部这两个自动变量
        指向模块文件而不是 winst.ps1，因此由调用方显式传入。

    .PARAMETER ScriptPath
        正在运行的 winst.ps1 完整路径。从命令字符串执行时可能为空，
        此时目录仍会被记录。

    .PARAMETER Directory
        winst.ps1 所在目录（「脚本目录」）。

    .OUTPUTS
        [hashtable] the values that were stored
    #>
    [CmdletBinding()]
    [OutputType([hashtable])]
    param(
        [string]$ScriptPath = '',
        [string]$Directory = ''
    )

    if (-not $Directory -and $ScriptPath) {
        try { $Directory = Split-Path -Parent $ScriptPath } catch { $Directory = '' }
    }

    $null = Set-WinstState -Name 'WinstScriptPath' -Value ([string]$ScriptPath)
    $null = Set-WinstState -Name 'WinstScriptDir' -Value ([string]$Directory)

    return @{
        ScriptPath = [string]$ScriptPath
        Directory  = [string]$Directory
    }
}
