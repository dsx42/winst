#Requires -Version 5.1

function Get-WinstRunningAppProcess {
    <#
    .SYNOPSIS
        找出正在运行的、属于该软件安装目录的进程。
    .DESCRIPTION
        按进程可执行文件路径是否位于安装目录之下判定（避免误伤同名但别处的程序）；
        路径读不到时（如以管理员运行）仅在进程名与主程序一致时才作为候选。
        `Certain` 区分「路径确认」与「仅按名字兜底」：
          - 路径确认在安装目录下 → $true，允许不询问就结束；
          - 只按清单进程名 / 主程序名命中 → $false，要求用户手动关闭。
        -Refresh 跳过进程快照缓存，强制用实时数据判定（交互确认后复核用）。
    .OUTPUTS
        @( @{ Id; Name; Path; Certain } )
    #>
    param(
        [hashtable]$Context,
        $Plan,
        [string]$InstallDir = '',
        [string[]]$ExtraDirs = @(),
        [switch]$Refresh
    )

    $dirs = @()
    foreach ($dir in @(@($InstallDir) + @($ExtraDirs))) {
        $text = ([string]$dir).Trim().Trim('"').TrimEnd('\')
        if ($text -and ($dirs -notcontains $text)) { $dirs += $text }
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
        $base = ''
        try { $base = [IO.Path]::GetFileNameWithoutExtension(([string]$declared).Trim()) } catch { $base = ([string]$declared).Trim() }
        if ($base) { $declaredNames += $base.ToLowerInvariant() }
    }

    $result = @()
    $self = $PID
    foreach ($proc in @(Get-WinstProcessSnapshot -Refresh:$Refresh)) {
        $procId = [int]$proc['Id']
        if ($procId -eq $self) { continue }

        $path = ([string]$proc['Path']).Trim().Trim('"')
        $matched = $false
        $certain = $false

        if ($path) {
            $pathFull = $path.TrimEnd('\')
            foreach ($dir in $dirs) {
                # 盘根（"C:" / "C:\"）会命中该盘上所有进程 → 必须跳过
                if (-not $dir -or $dir.Length -lt 3) { continue }
                if (Test-WinstPathUnderAnyDir -Path $pathFull -Dirs @($dir)) {
                    $matched = $true
                    $certain = $true
                    break
                }
            }
        }

        # 仅按名字命中的进程不能证明属于本次安装，只提示用户手动关闭。
        if (-not $matched -and $declaredNames.Count -gt 0) {
            $nameBase = ''
            try { $nameBase = [IO.Path]::GetFileNameWithoutExtension([string]$proc['Name']) } catch { $nameBase = '' }
            if ($nameBase -and ($declaredNames -contains $nameBase.ToLowerInvariant())) {
                $matched = $true
                $certain = $false
            }
        }

        # 路径读不到时（如以管理员运行）仅在进程名与主程序一致时才作为候选（避免误伤同名但别处的程序）
        if (-not $matched -and -not $path -and $mainBase) {
            $nameBase = ''
            try { $nameBase = [IO.Path]::GetFileNameWithoutExtension([string]$proc['Name']) } catch { $nameBase = '' }
            $shellNames = @('powershell', 'pwsh', 'cmd', 'wscript', 'cscript', 'conhost', 'explorer')
            if ($nameBase -and $nameBase -ieq $mainBase -and ($shellNames -notcontains $nameBase.ToLowerInvariant())) {
                $matched = $true
            }
        }

        if (-not $matched) { continue }
        $exists = $false
        foreach ($item in $result) { if ([int]$item['Id'] -eq $procId) { $exists = $true; break } }
        if (-not $exists) {
            $result += [ordered]@{ Id = $procId; Name = [string]$proc['Name']; Path = $path; Certain = $certain }
        }
    }
    return @($result)
}
