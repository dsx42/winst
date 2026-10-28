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
          - 清单 `processes` 里声明的名字与主程序同名（chrome.exe）→ $true；
          - 声明的是共享运行时（java / python / node 等）或路径在别处 → $false，必须让用户确认。
    .OUTPUTS
        @( @{ Id; Name; Path; Certain } )
    #>
    param(
        [hashtable]$Context,
        $Plan,
        [string]$InstallDir = '',
        [string[]]$ExtraDirs = @()
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
    foreach ($proc in @(Get-WinstProcessSnapshot)) {
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

        # 声明的进程名：清单声明 = 有意覆盖该产品的全部进程（如 Chrome 的 MsiExec 型记录拿不到安装目录）。
        # 但「只按名字命中」的风险取决于名字是不是这个软件自己的主程序：
        #   - 与主程序同名（chrome.exe）→ 视为确认命中，可自动结束；
        #   - 是共享运行时（java / python / dotnet / node 等）→ 只算候选，必须让用户确认，
        #     否则 `processes: ["java"]` 一条声明就能把用户机器上所有 JVM 一起杀掉。
        if (-not $matched -and $declaredNames.Count -gt 0) {
            $nameBase = ''
            try { $nameBase = [IO.Path]::GetFileNameWithoutExtension([string]$proc['Name']) } catch { $nameBase = '' }
            if ($nameBase -and ($declaredNames -contains $nameBase.ToLowerInvariant())) {
                $matched = $true
                $certain = [bool]($mainBase -and ($nameBase -ieq $mainBase))
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
