#Requires -Version 5.1

function Get-WinstRepairCatalog {
    <#
    .SYNOPSIS
        ① 加载清单并建三个查找表（按 id / 来源 / 不区分大小写 id），同时判断能否做清单匹配扫描。
    .OUTPUTS
        @{ Plan; Source; CiId; CanScan }
    #>
    param([hashtable]$Context, [switch]$Quiet)

    # 超期软件源先按 TTL 刷新，避免用过期清单匹配 id
    $null = Update-WinstStaleSources -Context $Context -Quiet
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
