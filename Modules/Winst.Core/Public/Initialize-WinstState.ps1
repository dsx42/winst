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
        winst.ps1，导入全部模块之后。

    幂等：
        重复执行保留已有数据，补齐缺失项，并重建值为空且需要初值的项。
#>

function Initialize-WinstState {
    <#
    .SYNOPSIS
        创建跨模块状态项及其初值。

    .DESCRIPTION
        补齐缺失的状态项。缓存字典及要求非空的状态项在值为 $null 时也会重新初始化。
    #>
    [CmdletBinding()]
    param()

    $defaults = @{
        WinstScriptPath = ''
        WinstScriptDir = ''
        WinstProtectedDirectoryPaths = $null
        WinstMenuMode = $false
        WinstQuitRequested = $false
        WinstSkipMenuPause = $false
        WinstOptions = $null
        WinstConfigCorruptReported = $false
        WinstAllAppsCache = $null
        WinstSearchCatalogCache = $null
        WinstDependencyIndex = $null
        WinstInstanceLock = $null
        WinstRegistryEntriesCache = $null
        WinstEnvironmentCache = $null
        WinstAppxCache = $null
        WinstLocalManifestFilesCache = $null
        WinstEnginePathCache = $null
    }
    foreach ($name in $defaults.Keys) {
        if (-not (Test-WinstState -Name $name)) {
            $null = Set-WinstState -Name $name -Value $defaults[$name]
        }
    }

    $comparers = @{
        WinstHttpCache = [StringComparer]::Ordinal
        WinstJsonCache = [StringComparer]::OrdinalIgnoreCase
        WinstPackageHashCache = [StringComparer]::OrdinalIgnoreCase
        WinstCatalogRefreshed = [StringComparer]::Ordinal
        WinstManifestPersistUnavailable = [StringComparer]::Ordinal
        WinstManifestSessionMeta = [StringComparer]::OrdinalIgnoreCase
        WinstStateReadCache = [StringComparer]::OrdinalIgnoreCase
        WinstEngineUpdateChecked = [StringComparer]::Ordinal
    }
    foreach ($name in $comparers.Keys) {
        if ($null -eq (Get-WinstState -Name $name)) {
            $null = Set-WinstState -Name $name -Value (New-Object System.Collections.Hashtable ($comparers[$name]))
        }
    }

    if ($null -eq (Get-WinstState -Name 'WinstHttpCacheSweepAt')) {
        $null = Set-WinstState -Name 'WinstHttpCacheSweepAt' -Value ([DateTime]::MinValue)
    }
    if ($null -eq (Get-WinstState -Name 'WinstInstallingAppIds')) {
        $null = Set-WinstState -Name 'WinstInstallingAppIds' -Value @()
    }
    if ($null -eq (Get-WinstState -Name 'WinstSelfChecked')) {
        $null = Set-WinstState -Name 'WinstSelfChecked' -Value $false
    }
    if ($null -eq (Get-WinstState -Name 'WinstBrowserProfileDir')) {
        $null = Set-WinstState -Name 'WinstBrowserProfileDir' -Value ''
    }
    if ($null -eq (Get-WinstState -Name 'WinstSettingChangeReady')) {
        $null = Set-WinstState -Name 'WinstSettingChangeReady' -Value $false
    }
}

function Set-WinstScriptLocation {
    <#
    .SYNOPSIS
        记录当前运行的脚本路径和目录。

    .DESCRIPTION
        脚本目录用于查找本地清单与列表文件。脚本路径供离线自安装、
        自身位置检查与实例锁记录使用。

        这里不能用 $PSCommandPath / $MyInvocation：在模块内部这两个自动变量
        指向模块文件而不是 winst.ps1，因此由调用方显式传入。

    .PARAMETER ScriptPath
        正在运行的 winst.ps1 完整路径。从命令字符串执行时可能为空，
        此时目录仍会被记录。

    .PARAMETER Directory
        winst.ps1 所在目录（「脚本目录」）。
    #>
    [CmdletBinding()]
    param(
        [string]$ScriptPath,
        [string]$Directory
    )

    $null = Set-WinstState -Name 'WinstScriptPath' -Value ([string]$ScriptPath)
    $null = Set-WinstState -Name 'WinstScriptDir' -Value ([string]$Directory)
}
