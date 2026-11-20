#Requires -Version 5.1
<#
    Windows PowerShell 5.1 文件入口。通过 $args 接收 CLI 长开关。
    按绝对路径导入本地模块，运行命令或交互菜单。双击启动由 winst.cmd 负责。
#>

# ---------------------------------------------------------------- 点源保护
if ($MyInvocation.InvocationName -eq '.') {
    Write-Warning 'winst.ps1 是应用入口，不支持点源加载。请运行 powershell -NoProfile -ExecutionPolicy Bypass -File .\winst.ps1。'
    return
}

# ------------------------------------------------------------ 进程级偏好
Set-StrictMode -Version 2
$ErrorActionPreference = 'Stop'
$ProgressPreference = 'SilentlyContinue'

# ------------------------------------------------------------------ 根目录
# 必须在提权之前算好：提权要按它重新启动自己。
$script:WinstRoot = $PSScriptRoot
$script:WinstArguments = @($args)

function Test-WinstNeedsElevation {
    param([bool]$ReadOnly)

    if ($env:WINST_NO_ELEVATE -eq '1') { return $false }
    if ($ReadOnly) { return $false }
    try {
        $identity = [Security.Principal.WindowsIdentity]::GetCurrent()
        $principal = New-Object Security.Principal.WindowsPrincipal($identity)
        if ($principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) { return $false }
    } catch {
        # 读不到身份信息（极端受限环境）：不提权，让后续步骤按自己的口径报错
        return $false
    }
    return $true
}

function Start-WinstElevatedEntry {
    param([bool]$Interactive)

    $winstElevateArgs = @('-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', ($script:WinstRoot + '\winst.ps1')) + [string[]]$script:WinstArguments

    $winstArgText = ($winstElevateArgs | ForEach-Object { Format-WinstCommandArgument -Value $_ }) -join ' '

    try {
        # 用 ProcessStartInfo + runas：Start-Process -Verb RunAs 拿到的
        # 进程对象在部分系统上取不到 ExitCode，而带子命令时必须能拿到它。
        $winstStart = New-Object System.Diagnostics.ProcessStartInfo
        $winstStart.FileName = 'powershell.exe'
        $winstStart.Arguments = $winstArgText
        $winstStart.UseShellExecute = $true
        $winstStart.Verb = 'runas'
        $winstProcess = [Diagnostics.Process]::Start($winstStart)

        if ($Interactive) {
            # 交互式菜单：任务已交给提权窗口，本窗口立即关闭——等下去会同时出现两个控制台窗口
            [Console]::Out.WriteLine('winst: 需要管理员权限，已在新窗口中以管理员身份启动，本窗口会自动关闭。')
            exit 0
        }

        # 带子命令：等到它结束并转发退出码，否则调用方永远只拿到 0
        [Console]::Out.WriteLine('winst: 需要管理员权限，已在新窗口中以管理员身份启动，本窗口会等待其结束后退出。')
        $winstProcess.WaitForExit()
        $winstCode = $winstProcess.ExitCode
        if ($null -eq $winstCode) { throw '无法取得提权进程退出码' }
        exit $winstCode
    } catch {
        # 用户点了「否」/ 系统策略禁止提权：明确报错，不偷偷降级继续跑
        [Console]::Error.WriteLine('winst: 需要管理员权限（安装软件、写系统环境变量、运行安装程序都要用到）。')
        [Console]::Error.WriteLine('winst: 提权失败：' + $_.Exception.Message)
        [Console]::Error.WriteLine('winst: 如只想查看信息，可设 WINST_NO_ELEVATE=1 后重试。')
        exit 1
    }
}

# 元数据请求 / 下载走 TLS 1.2 以上；个别受限环境不允许修改，忽略即可。
try {
    [Net.ServicePointManager]::SecurityProtocol = [Net.ServicePointManager]::SecurityProtocol -bor [Net.SecurityProtocolType]::Tls12
} catch {
}

# ------------------------------------------------------------ 模块搜索路径
# 从 PowerShell 7 启动时可能继承它的 PSModulePath。将 Windows PowerShell 的系统模块目录
# 移到本进程搜索路径首位，使 5.1 优先加载兼容版本。
try {
    $winstSystemModules = [IO.Path]::Combine([string]$env:WINDIR, 'System32\WindowsPowerShell\v1.0\Modules')
    if (Test-Path -LiteralPath $winstSystemModules -PathType Container) {
        $winstModulePaths = @()
        foreach ($one in ([string]$env:PSModulePath) -split ';') {
            $text = ([string]$one).Trim()
            if (-not $text) { continue }
            if ($text.TrimEnd('\') -ieq $winstSystemModules.TrimEnd('\')) { continue }
            $winstModulePaths += $text
        }
        $env:PSModulePath = (@($winstSystemModules) + $winstModulePaths) -join ';'
    }
} catch {
}

# ---------------------------------------------------------------- 模块加载
function Import-WinstLocalModule {
    <#
    .SYNOPSIS
        按绝对路径导入一个本地模块。

    .DESCRIPTION
        使用 -DisableNameChecking 屏蔽 Ensure-OfficialManifest 等函数的非标准动词警告。

        开发时设置环境变量 WINST_DEV=1 可强制重新导入（避免模块缓存）。

    .OUTPUTS
        [void]
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$ManifestPath
    )

    $parameters = @{
        Name                = $ManifestPath
        DisableNameChecking = $true
        ErrorAction         = 'Stop'
    }

    if ($env:WINST_DEV -eq '1') {
        $parameters['Force'] = $true
    }

    Import-Module @parameters
}

function Get-WinstModulePlan {
    <#
    .SYNOPSIS
        判定当前是哪种模块形态，返回要导入的清单文件列表。

    .DESCRIPTION
        Modules\ 下凡「目录名与其中清单同名」的子目录都算一个模块。
        只有一个 Winst 时就是 release 的单一模块形态，导入它即可；
        否则是开发树，逐个导入。

        没有任何模块目录，或某个模块目录缺少同名清单，都直接报错、
        不做猜测。

    .OUTPUTS
        [string[]] 本地模块清单路径
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$Root
    )

    $modulesDir = Join-Path $Root 'Modules'
    if (-not (Test-Path -LiteralPath $modulesDir -PathType Container)) {
        throw ('缺少 Modules 目录：{0}' -f $modulesDir)
    }

    $manifests = New-Object 'System.Collections.Generic.List[string]'
    $problems = New-Object 'System.Collections.Generic.List[string]'

    foreach ($dir in @(Get-ChildItem -LiteralPath $modulesDir -Directory -ErrorAction Stop | Sort-Object -Property Name)) {
        $manifestPath = Join-Path $dir.FullName ($dir.Name + '.psd1')
        if (Test-Path -LiteralPath $manifestPath -PathType Leaf) {
            $manifests.Add($manifestPath)
        } else {
            $problems.Add(('Modules\{0} 不是模块目录：缺少同名清单 {0}.psd1' -f $dir.Name))
        }
    }

    if ($problems.Count -gt 0) {
        throw ($problems -join [Environment]::NewLine)
    }
    if ($manifests.Count -eq 0) {
        throw ('{0} 下没有任何模块目录' -f $modulesDir)
    }

    return $manifests
}

try {
    foreach ($manifestPath in (Get-WinstModulePlan -Root $script:WinstRoot)) {
        Import-WinstLocalModule -ManifestPath $manifestPath
    }

    # 跨模块状态必须先建好：StrictMode 下读取未初始化的状态会得到 $null，
    # 随后对 $null 取成员 / 调方法会直接抛异常。
    $null = Initialize-WinstState

    $parsed = Read-WinstCommandLine -Tokens $script:WinstArguments
    if (Test-WinstNeedsElevation -ReadOnly (Test-WinstReadOnlyInvocation -Parsed $parsed)) {
        Start-WinstElevatedEntry -Interactive (-not $parsed.Error -and -not $parsed.Command)
    }

    $result = Invoke-WinstApplication -Root $script:WinstRoot -Parsed $parsed
    $script:WinstExitCode = $result.ExitCode
} catch {
    $script:WinstExitCode = 1

    $message = $_.Exception.Message
    if ($_.InvocationInfo -and $_.InvocationInfo.PositionMessage) {
        $message = $message + [Environment]::NewLine + $_.InvocationInfo.PositionMessage
    }

    [Console]::Error.WriteLine('winst: ' + $message)

    if (@($script:WinstArguments) -contains '--verbose') {
        [Console]::Error.WriteLine($_.ScriptStackTrace)
    }
}

exit $script:WinstExitCode
