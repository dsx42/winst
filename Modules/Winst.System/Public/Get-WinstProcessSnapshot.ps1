#Requires -Version 5.1

function Get-WinstProcessSnapshot {
    <#
    .SYNOPSIS
        取当前进程快照（进程号 / 名称 / 可执行文件路径）。
    .DESCRIPTION
        优先用 CIM（第三方程序以管理员运行时，Get-Process 读不到 Path），失败时退回 Get-Process。
        -Refresh 跳过缓存强制重新枚举：判断「进程是不是真的还在」必须用实时数据。
    #>
    param([switch]$Refresh)

    # 3 秒快照：运行中检测会按依赖逐层问、按重试轮次反复问，而 Win32_Process 全量枚举
    # （含 ExecutablePath）单次就要几百毫秒
    $cached = Get-WinstState -Name WinstProcessCache
    if (-not $Refresh -and $cached) {
        $age = ((Get-Date) - [datetime]$cached['At']).TotalSeconds
        if ($age -ge 0 -and $age -lt 3) { return @($cached['List']) }
    }

    $list = New-Object 'System.Collections.Generic.List[object]'
    try {
        foreach ($p in @(Get-CimInstance -ClassName Win32_Process -ErrorAction Stop)) {
            $list.Add([ordered]@{
                Id   = [int]$p.ProcessId
                Name = [string]$p.Name
                Path = [string]$p.ExecutablePath
            })
        }
        if ($list.Count -gt 0) {
            $snapshot = @($list.ToArray())
            $null = Set-WinstState -Name WinstProcessCache -Value (@{ At = (Get-Date); List = $snapshot })
            return $snapshot
        }
    } catch {
        $list = New-Object 'System.Collections.Generic.List[object]'
    }
    try {
        foreach ($p in @(Get-Process -ErrorAction SilentlyContinue)) {
            $path = ''
            try { $path = [string]$p.Path } catch { $path = '' }
            $list.Add([ordered]@{ Id = [int]$p.Id; Name = ([string]$p.ProcessName + '.exe'); Path = $path })
        }
    } catch { }
    $fallback = @($list.ToArray())
    $null = Set-WinstState -Name WinstProcessCache -Value (@{ At = (Get-Date); List = $fallback })
    return $fallback
}
