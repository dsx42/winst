#Requires -Version 5.1

function Get-WinstProcessSnapshot {
    <#
    .SYNOPSIS
        取当前进程快照（进程号 / 名称 / 可执行文件路径 / 创建时间）。
    .DESCRIPTION
        优先用 CIM（第三方程序以管理员运行时，Get-Process 读不到 Path），失败时退回 Get-Process。
    #>
    $list = New-Object 'System.Collections.Generic.List[object]'
    try {
        Get-CimInstance -ClassName Win32_Process -Property ProcessId,Name,ExecutablePath,CreationDate -ErrorAction Stop | ForEach-Object {
            $p = $_
            $list.Add([ordered]@{
                Id   = [int]$p.ProcessId
                Name = [string]$p.Name
                Path = [string]$p.ExecutablePath
                StartedAt = $p.CreationDate
            })
        }
        if ($list.Count -gt 0) {
            return $list.ToArray()
        }
    } catch {
        $list = New-Object 'System.Collections.Generic.List[object]'
    }
    try {
        foreach ($p in @(Get-Process -ErrorAction SilentlyContinue)) {
            try { $path = [string]$p.Path } catch { $path = '' }
            $startedAt = $null
            try { $startedAt = $p.StartTime } catch { }
            $list.Add([ordered]@{ Id = [int]$p.Id; Name = ([string]$p.ProcessName + '.exe'); Path = $path; StartedAt = $startedAt })
        }
    } catch { }
    return $list.ToArray()
}
