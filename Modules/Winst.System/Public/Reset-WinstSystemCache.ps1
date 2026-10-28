#Requires -Version 5.1

function Reset-WinstSystemCache {
    <#
    .SYNOPSIS
        清空系统状态快照缓存（写注册表 / 环境变量 / 安装应用包 / 安装完成后调用）。
    .DESCRIPTION
        默认（不带开关）只清「受系统安装状态影响」的四项：
        注册表卸载项、环境变量、Appx 包、引擎路径。写注册表 / 环境变量 / 安装应用包之后，
        注册表卸载项与 Appx 包必须重读（新装的软件要能被检测到）。

        `-All` 额外清「与系统安装状态无关」的三项：进程快照、本地清单文件列表、台账读缓存。
        只在「明确要求整份重读」的场景（排障）才需要，不要放进常规写入路径。
    .OUTPUTS
        [void]
    #>
    param([switch]$All)

    $null = Set-WinstState -Name WinstRegistryEntriesCache -Value ($null)
    $null = Set-WinstState -Name WinstEnvironmentCache -Value ($null)
    $null = Set-WinstState -Name WinstAppxCache -Value ($null)
    $null = Set-WinstState -Name WinstEnginePathCache -Value ($null)
    if ($All) {
        $null = Set-WinstState -Name WinstProcessCache -Value ($null)
        $null = Set-WinstState -Name WinstLocalManifestFilesCache -Value ($null)
        # 台账读缓存：台账也可能被别的途径改动（repair 的外部扫描、手工替换文件）。
        # 文件戳能兜住内容变化，这里额外清掉是为了让「强制重读」有一个明确入口。
        $cache = Get-WinstState -Name WinstStateReadCache
        if ($null -ne $cache) { $cache.Clear() }
    }
}
