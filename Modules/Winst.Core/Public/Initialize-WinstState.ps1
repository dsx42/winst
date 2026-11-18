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
        重复执行只补缺失的项与需要重建的非空缓存，因此同一会话内入口跑两次也不会丢掉进程内缓存。
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
        WinstProcessCache = $null
        WinstLocalManifestFilesCache = $null
        WinstEnginePathCache = $null
    }
    foreach ($name in $defaults.Keys) {
        if (-not (Test-WinstState -Name $name)) {
            $null = Set-WinstState -Name $name -Value $defaults[$name]
            $initialized++
        }
    }

    $comparers = @{
        WinstHttpCache = [StringComparer]::Ordinal
        WinstJsonCache = [StringComparer]::OrdinalIgnoreCase
        WinstCatalogRefreshed = [StringComparer]::Ordinal
        WinstManifestPersistUnavailable = [StringComparer]::Ordinal
        WinstManifestSessionMeta = [StringComparer]::OrdinalIgnoreCase
        WinstStateReadCache = [StringComparer]::OrdinalIgnoreCase
        WinstEngineUpdateChecked = [StringComparer]::Ordinal
    }
    foreach ($name in $comparers.Keys) {
        if ($null -eq (Get-WinstState -Name $name)) {
            $null = Set-WinstState -Name $name -Value (New-Object System.Collections.Hashtable ($comparers[$name]))
            $initialized++
        }
    }

    if ($null -eq (Get-WinstState -Name 'WinstHttpCacheSweepAt')) {
        $null = Set-WinstState -Name 'WinstHttpCacheSweepAt' -Value ([DateTime]::MinValue)
        $initialized++
    }
    if ($null -eq (Get-WinstState -Name 'WinstInstallingAppIds')) {
        $null = Set-WinstState -Name 'WinstInstallingAppIds' -Value @()
        $initialized++
    }
    if ($null -eq (Get-WinstState -Name 'WinstSelfChecked')) {
        $null = Set-WinstState -Name 'WinstSelfChecked' -Value $false
        $initialized++
    }
    if ($null -eq (Get-WinstState -Name 'WinstBrowserProfileDir')) {
        $null = Set-WinstState -Name 'WinstBrowserProfileDir' -Value ''
        $initialized++
    }
    if ($null -eq (Get-WinstState -Name 'WinstSettingChangeReady')) {
        $null = Set-WinstState -Name 'WinstSettingChangeReady' -Value $false
        $initialized++
    }

    return $initialized
}

function Set-WinstScriptLocation {
    <#
    .SYNOPSIS
        记录当前运行的脚本路径和目录。

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
        [hashtable] 已记录的位置
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
