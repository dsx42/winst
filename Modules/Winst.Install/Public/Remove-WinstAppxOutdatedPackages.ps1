#Requires -Version 5.1

function Remove-WinstAppxOutdatedPackages {
    <#
    .SYNOPSIS
        应用包更新后的残留清点：按清单卸载规则命中、但版本低于本次检出版本的包逐一移除。
    .DESCRIPTION
        Windows App SDK 运行时的 DDLM（Dynamic Dependency Lifetime Manager）包「按版本命名」
        （如 Microsoft.WinAppRuntime.DDLM.2.4.0.0-x6），安装器升级到新版本后，旧版本的 DDLM 包
        会一直留着、越积越多（系统里能看到一排「Windows App Runtime DDLM xxx」）。安装 / 更新
        完成后按清单卸载规则清点：版本等于 / 高于本次检出版本的包保留（Singleton 的 8002.x
        前缀版本号天然高于检出值，不会被误删），低于的逐一移除；只对卸载方式为 appx 的条目
        生效。
    .OUTPUTS
        @{ Ok; Error; Removed; Failed; Kept }
    #>
    param([hashtable]$Context, $Plan, [switch]$Quiet)

    $result = @{ Ok = $true; Error = ''; Removed = @(); Failed = @(); Kept = 0 }
    $uninstall = Get-EntryValue -Entry $Plan -Key 'uninstall' -Default $null
    if ($null -eq $uninstall) { return $result }
    if ((Get-EntryString -Entry $uninstall -Key 'method').Trim().ToLowerInvariant() -ne 'appx') { return $result }

    $detect = Get-WinstDetectedVersion -Context $Context -Plan $Plan -InstallDir ''
    if (-not ($detect.Ok -and [string]$detect.Version)) { return $result }
    $detectedVersion = [string]$detect.Version

    $rules = Get-EntryValue -Entry $uninstall -Key 'name' -Default $null
    if ($null -eq $rules) {
        $rules = Get-EntryValue -Entry (Get-EntryValue -Entry $Plan -Key 'detect' -Default $null) -Key 'name' -Default $null
    }
    $packages = @(Get-WinstAppxPackagesMatching -NameRules $rules)
    if ($packages.Count -eq 0) { return $result }
    if (-not (Get-Command Remove-AppxPackage -ErrorAction SilentlyContinue)) { return $result }

    foreach ($package in $packages) {
        $pkgVersion = ''
        try { $pkgVersion = [string]$package.Version } catch { $pkgVersion = '' }
        $cmp = 0
        try { $cmp = Compare-WinstVersion -A $pkgVersion -B $detectedVersion } catch { $cmp = 0 }
        if ($cmp -ge 0) { $result.Kept++; continue }   # 版本相同 / 更高 → 本次安装的（或更高的版本前缀）→ 保留
        $fullName = ''
        try { $fullName = [string]$package.PackageFullName } catch { $fullName = '' }
        if (-not $Quiet) { Write-Host ('    正在清理旧版本应用包: {0} …' -f $fullName) -ForegroundColor Gray }
        try {
            Remove-AppxPackage -Package $fullName -ErrorAction Stop
            $result.Removed += $fullName
        } catch {
            $result.Failed += [ordered]@{ PackageFullName = $fullName; Error = [string]$_.Exception.Message }
        }
    }

    # 包已变化：Appx 快照必须立刻失效。否则紧接着的安装后回读（Resolve-WinstActualInstallDir）
    # 会读到仍含已删包的 30 秒快照，把「已清理的旧版本」当成仍在。
    if (@($result.Removed).Count -gt 0) { Reset-WinstSystemCache }

    if (@($result.Failed).Count -gt 0) {
        $result.Ok = $false
        $parts = @()
        foreach ($one in @($result.Failed)) { $parts += ('{0}（{1}）' -f $one['PackageFullName'], $one['Error']) }
        $result.Error = ('有 {0} 个旧版本应用包没有清理成功: {1}' -f @($result.Failed).Count, ($parts -join '；'))
    }
    return $result
}
