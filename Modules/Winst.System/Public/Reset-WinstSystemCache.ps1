#Requires -Version 5.1

function Reset-WinstSystemCache {
    <#
    .SYNOPSIS
        清空系统状态快照缓存（写注册表 / 环境变量 / 安装应用包 / 安装完成后调用）。
    .DESCRIPTION
        `-All` 时连进程快照与本地清单文件列表一并清空；
        注册表卸载项与 Appx 包在安装动作之后必须重读（新装的软件要能被检测到）。
    #>
    param([switch]$All)

    $null = Set-WinstState -Name WinstRegistryEntriesCache -Value ($null)
    $null = Set-WinstState -Name WinstEnvironmentCache -Value ($null)
    $null = Set-WinstState -Name WinstAppxCache -Value ($null)
    if ($All) {
        $null = Set-WinstState -Name WinstProcessCache -Value ($null)
        $null = Set-WinstState -Name WinstLocalManifestFilesCache -Value ($null)
        $null = Set-WinstState -Name WinstEnginePathCache -Value ($null)
        # 台账读缓存：Save-WinstState 会自己刷新，但台账也可能被别的途径改动
        # （repair 的外部扫描、手工替换文件）。文件戳能兜住内容变化，
        # 这里额外清掉是为了让「强制重读」有一个明确入口。
        $cache = Get-WinstState -Name WinstStateReadCache
        if ($null -ne $cache) { $cache.Clear() }
    }
}
