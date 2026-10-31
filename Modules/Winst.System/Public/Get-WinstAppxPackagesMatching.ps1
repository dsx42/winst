#Requires -Version 5.1

function Get-WinstAppxPackagesMatching {
    <#
    .SYNOPSIS
        按名称规则（通配，字符串或数组）找出已安装的应用包（MSIX / AppX），返回全部命中；没有则返回空数组。
    .DESCRIPTION
        供 detect.method = appx 的检测（取版本）与卸载（按规则移除）共用：Windows App Runtime 的运行时
        由 .exe 安装器装成多个包家族（framework / Main / Singleton / DDLM，名字前缀都不同），清单可在
        uninstall.name 里声明多个规则，命中任意一个即纳入。系统自带位置（%WINDIR%\SystemApps 下的
        收件箱包）一律排除。
    #>
    param($NameRules, [hashtable]$Status = $null)

    if ($null -ne $Status) { $Status.Ok = $false; $Status.Error = '没有可用的应用包名称规则' }

    $rules = @()
    foreach ($one in @($NameRules)) {
        $text = ''
        if ($null -ne $one) { $text = ([string]$one).Trim() }
        if (-not $text) { continue }
        $rule = New-MatchRule -Rule $text -Kind '应用包名称'
        if ($rule.Ok) { $rules += $rule }
    }
    if ($rules.Count -eq 0) { return @() }

    # 短 TTL 快照：不带 -Name 过滤的 Get-AppxPackage 是秒级枚举，而检测 / 清理 / 安装后各调一次。
    # 写入侧（Add-AppxPackage / Remove-WinstAppxPackage）立即失效
    $packages = @()
    try {
        if (-not (Get-Command Get-AppxPackage -ErrorAction SilentlyContinue)) {
            if ($null -ne $Status) { $Status.Error = '当前系统无法查询应用包记录' }
            return @()
        }
        $cacheValid = $false
        if ((Get-WinstState -Name WinstAppxCache)) {
            $age = ((Get-Date) - [datetime](Get-WinstState -Name WinstAppxCache)['At']).TotalSeconds
            if ($age -ge 0 -and $age -lt 30) { $cacheValid = $true }
        }
        if ($cacheValid) {
            $packages = @((Get-WinstState -Name WinstAppxCache)['Items'])
        } else {
            $packages = @(Get-AppxPackage -ErrorAction Stop)
            $null = Set-WinstState -Name WinstAppxCache -Value (@{ At = (Get-Date); Items = $packages })
        }
        if ($null -ne $Status) { $Status.Ok = $true; $Status.Error = '' }
    } catch {
        if ($null -ne $Status) { $Status.Error = ('查询应用包记录失败：{0}' -f $_.Exception.Message) }
        return @()
    }
    if ($packages.Count -eq 0) { return @() }

    $matched = New-Object 'System.Collections.Generic.List[object]'
    foreach ($package in $packages) {
        $name = [string]$package.Name
        if (-not $name) { continue }
        foreach ($rule in $rules) {
            if (Test-CompiledMatchRule -Rule $rule -Text $name) { $matched.Add($package); break }
        }
    }
    if ($matched.Count -eq 0) { return @() }

    # 系统自带位置（%WINDIR%\SystemApps）里的包不是用户安装的运行时，先排除（如 Microsoft.WindowsAppRuntime.CBS*）
    $systemApps = ''
    if ($env:WINDIR) { $systemApps = (Join-WinstPath $env:WINDIR 'SystemApps').TrimEnd('\') }
    $notInbox = New-Object 'System.Collections.Generic.List[object]'
    foreach ($package in $matched) {
        $location = ''
        try { $location = ([string]$package.InstallLocation).Trim() } catch { $location = '' }
        $isInbox = $false
        if ($systemApps -and $location) {
            $isInbox = $location.TrimEnd('\').StartsWith($systemApps, [StringComparison]::OrdinalIgnoreCase)
        }
        if (-not $isInbox) { $notInbox.Add($package) }
    }
    return @($notInbox.ToArray())
}
