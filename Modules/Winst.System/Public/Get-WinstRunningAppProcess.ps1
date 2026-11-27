#Requires -Version 5.1

function Get-WinstRunningAppProcess {
    <#
    .SYNOPSIS
        找出正在运行的、属于该软件安装目录的进程。
    .DESCRIPTION
        按进程可执行文件路径是否位于安装目录之下判定（避免误伤同名但别处的程序）；
        清单声明的进程名也用于匹配。读不到路径时，还会匹配主程序名。
        Certain 为真表示已确认可执行文件位于该软件目录下，且已取得进程启动时间。
    .OUTPUTS
        @( @{ Id; Name; Path; StartedAt; Certain } )
    #>
    param(
        $Plan,
        [string]$InstallDir,
        [string[]]$ExtraDirs
    )

    $dirs = @()
    foreach ($dir in @(@($InstallDir) + @($ExtraDirs))) {
        $text = ([string]$dir).Trim().Trim('"').TrimEnd('\', '/')
        if ($text.Length -ge 3 -and ($dirs -notcontains $text)) { $dirs += $text }
    }

    $main = Get-WinstMainProgram -Plan $Plan
    $mainBase = ''
    if ($main) {
        try { $mainBase = [IO.Path]::GetFileNameWithoutExtension($main) } catch { $mainBase = '' }
    }

    # 清单里声明的运行进程名：安装版软件的安装目录常解析不出来
    # （如 Chrome 的 MsiExec 型注册表记录没有 InstallLocation），目录匹配无从下手时按进程名兜底
    $declaredNames = @()
    foreach ($declared in @(Get-EntryArray -Entry $Plan -Key 'processes')) {
        try { $base = [IO.Path]::GetFileNameWithoutExtension(([string]$declared).Trim()) } catch { $base = ([string]$declared).Trim() }
        if ($base) { $declaredNames += $base.ToLowerInvariant() }
    }

    $result = @()
    $self = $PID
    foreach ($proc in @(Get-WinstProcessSnapshot)) {
        $procId = [int]$proc['Id']
        if ($procId -eq $self) { continue }

        $path = ([string]$proc['Path']).Trim().Trim('"')
        $certain = $path -and (Test-WinstPathUnderAnyDir -Path $path -Dirs $dirs)
        $matched = $certain
        $nameBase = ''
        if (-not $matched) {
            try { $nameBase = [IO.Path]::GetFileNameWithoutExtension([string]$proc['Name']) } catch { }
        }

        # 仅按名字命中的进程不能证明属于本次安装，只提示用户手动关闭。
        if (-not $matched -and $declaredNames.Count -gt 0) {
            if ($nameBase -and ($declaredNames -contains $nameBase.ToLowerInvariant())) {
                $matched = $true
            }
        }

        # 路径读不到时（如以管理员运行）仅在进程名与主程序一致时才作为候选（避免误伤同名但别处的程序）
        if (-not $matched -and -not $path -and $mainBase) {
            $shellNames = @('powershell', 'pwsh', 'cmd', 'wscript', 'cscript', 'conhost', 'explorer')
            if ($nameBase -and $nameBase -ieq $mainBase -and ($shellNames -notcontains $nameBase.ToLowerInvariant())) {
                $matched = $true
            }
        }

        if (-not $matched) { continue }
        $startedAt = Get-EntryValue -Entry $proc -Key 'StartedAt'
        $result += [ordered]@{ Id = $procId; Name = [string]$proc['Name']; Path = $path; StartedAt = $startedAt; Certain = ($certain -and $null -ne $startedAt) }
    }
    return @($result)
}
