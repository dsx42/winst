#Requires -Version 5.1

function Save-WinstConfig {
    <#
    .SYNOPSIS
        把配置写回 config.json（UTF-8 无 BOM；临时文件 + 重命名原子写）。
    .DESCRIPTION
        按固定键序写出全部键，保留未知/探针读到的既有值，避免手工删键后丢失。
    #>
    param(
        [Parameter(Mandatory = $true)]
        [string]$DataRoot,
        [Parameter(Mandatory = $true)]
        [hashtable]$Config
    )

    $configPath = Join-Path $DataRoot 'config.json'

    $ordered = [ordered]@{
        installRoot      = $Config['installRoot']
        pkgDir           = $Config['pkgDir']
        pruneOldPackages = $Config['pruneOldPackages']
        manifestTTLHours = $Config['manifestTTLHours']
        proxy            = $Config['proxy']
        proxyMode        = $Config['proxyMode']
        updateFilesOnly  = $Config['updateFilesOnly']
    }

    # 与清单 / 解析锁同一序列化口径（还原 & < > ' 的 \uXXXX 转义，保证代理地址等原样可读）
    $json = ConvertTo-WinstJson -InputObject $ordered -Depth 5

    Write-FileAtomic -Path $configPath -Content $json
}
