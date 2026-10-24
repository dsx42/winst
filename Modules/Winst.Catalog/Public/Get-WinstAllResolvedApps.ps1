#Requires -Version 5.1

function Get-WinstAllResolvedApps {
    <#
    .SYNOPSIS
        汇总全部软件源的软件清单条目：@( @{ Source; App } )。
    .DESCRIPTION
        某个来源还没有软件清单（从未刷新过）且允许联网时，自动刷新该来源一次
        （单次进程内每个来源最多一次）；`--offline` / `--dry-run` 不刷新，只用已有清单。
    #>
    param([Parameter(Mandatory = $true)][hashtable]$Context)

    # 一次会话内复用：同一份解析锁会被搜索 / 依赖索引 / 安装流程反复汇总，
    # 每次都遍历全部软件源并重读 meta.json 是最大的重复开销。
    # 软件源刷新 / 增删 / 本地清单变动后由 Reset-WinstCatalogCache 置空。
    #
    # 判断「是否已缓存」用 $null 判断：初始化值是 $null（无缓存），空数组是有效缓存
    # （Get-WinstState 用 -NoEnumerate 输出，空数组不会被展开成 $null）。
    if ($null -ne (Get-WinstState -Name WinstAllAppsCache)) { return @((Get-WinstState -Name WinstAllAppsCache)) }

    $all = New-Object 'System.Collections.Generic.List[object]'
    $offline = [bool]((Get-WinstState -Name WinstOptions) -and (Get-WinstState -Name WinstOptions).Offline)
    $dryRun = [bool]((Get-WinstState -Name WinstOptions) -and (Get-WinstState -Name WinstOptions).DryRun)

    foreach ($source in @(Get-ManifestSourceList -Context $Context)) {
        $name = [string]$source['name']
        if (-not $name) { continue }

        $apps = @(Get-ManifestResolvedApps -PkgDir $Context.PkgDir -Name $name)
        if ($apps.Count -eq 0 -and -not $offline -and -not $dryRun -and -not (Get-WinstState -Name WinstCatalogRefreshed).ContainsKey($name)) {
            (Get-WinstState -Name WinstCatalogRefreshed)[$name] = $true
            Write-Host ('  正在读取软件源 {0} 的软件清单 …' -f $name) -ForegroundColor Gray
            $null = Update-ManifestSource -Context $Context -Source $source
            $apps = @(Get-ManifestResolvedApps -PkgDir $Context.PkgDir -Name $name)
        }
        foreach ($app in $apps) { $all.Add(@{ Source = $name; App = $app }) }
    }

    $snapshot = @($all.ToArray())
    # 刷新过程中的 Update-ManifestSource 会把缓存置空（Write-ManifestMeta -> Reset-WinstCatalogCache）：
    # 这里只在还没有缓存时写回，避免把刷新前的旧快照盖到刷新后的状态上。
    # 空结果同样写回：Get-WinstState 用 -NoEnumerate 输出，$null 只表示「没缓存」。
    if ($null -eq (Get-WinstState -Name WinstAllAppsCache)) {
        $null = Set-WinstState -Name WinstAllAppsCache -Value ($snapshot)
    }
    return $snapshot
}
