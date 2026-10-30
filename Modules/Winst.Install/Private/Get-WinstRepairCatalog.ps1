#Requires -Version 5.1

function Get-WinstRepairCatalog {
    <#
    .SYNOPSIS
        ① 加载清单并建三个查找表（按 id / 来源 / 不区分大小写 id），同时判断能否做清单匹配扫描。
    .OUTPUTS
        @{ Plan; Source; CiId; CanScan }
    #>
    param([hashtable]$Context, [switch]$Quiet, [string[]]$RefreshIds = $null)

    # 超期软件源先按 TTL 刷新，避免用过期清单匹配 id。
    # 页面内嵌调用（已装软件 / 检查更新）传 -RefreshIds：只刷这些 id，不把仅下载条目的版本也解析一遍；
    # 独立执行 `winst repair`、或台账为空（没有可限定的 id）时按未限定处理，保持「刷新全部超期缓存」的口径。
    if ($RefreshIds -and @($RefreshIds).Count -gt 0) {
        $null = Update-WinstStaleSources -Context $Context -Quiet -OnlyIds $RefreshIds
    } else {
        $null = Update-WinstStaleSources -Context $Context -Quiet
    }
    if (-not $Quiet) { Write-Host '  正在读取软件源清单 …' -ForegroundColor Gray }
    $allApps = @(Get-WinstAllResolvedApps -Context $Context)

    $planLookup = New-WinstOrdinalDictionary
    $sourceLookup = New-WinstOrdinalDictionary
    $ciIdLookup = New-Object 'System.Collections.Hashtable' ([StringComparer]::OrdinalIgnoreCase)
    foreach ($item in $allApps) {
        $app = $item['App']
        if (-not (Get-EntryBool -Entry $app -Key 'ok')) { continue }
        $id = Get-EntryString -Entry $app -Key 'id'
        if (-not $id) { continue }
        $type = (Get-EntryString -Entry $app -Key 'type').Trim().ToLowerInvariant()
        if ($type -eq 'download') { continue }   # download 类不写台账
        if (-not $planLookup.Contains($id)) {
            $planLookup[$id] = $app
            $sourceLookup[$id] = [string]$item['Source']
            if (-not $ciIdLookup.ContainsKey($id)) { $ciIdLookup[$id] = $id }
        }
    }

    # 无可用清单时仍会按目录登记 installRoot 下的全部文件夹，并校对缓存索引、报告异常
    $canScan = $true
    if ($planLookup.Count -eq 0) {
        $canScan = $false
        Write-Host ''
        Write-Host '  没有可用的软件清单：跳过清单匹配与注册表扫描，安装目录下的文件夹仍会登记。' -ForegroundColor Yellow
        Write-Host '  如需找回已装软件，请先刷新软件源，或把清单文件放到脚本同目录（本地清单）后重试。' -ForegroundColor DarkGray
    }

    return @{ Plan = $planLookup; Source = $sourceLookup; CiId = $ciIdLookup; CanScan = $canScan }
}
