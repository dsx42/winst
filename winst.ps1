#Requires -Version 5.1
<#
    winst 主入口（Windows PowerShell 5.1）

    绿色免安装：解压到任意目录后直接运行，不需要安装、不需要 PSModulePath。

    启动方式：
        cmd:
            powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0winst.ps1" %*
        PowerShell:
            powershell.exe -NoProfile -ExecutionPolicy Bypass -File "$PSScriptRoot\winst.ps1"

    也可以直接双击同目录的 winst.cmd。

    两种模块形态
    ------------
    同一个入口要能跑两种目录布局，按磁盘上的目录自动判定：

        单一模块（release，用户拿到的）
            Modules\Winst\Winst.psd1
            Modules\Winst\Winst.psm1      由 build.ps1 合并生成
            一次 Import-Module，冷启动约 4 秒

        多模块（开发树）
            Modules\Winst.<名>\<名>.psd1  每个模块一个目录
            逐个 Import-Module，改完一个文件重跑即可，不必先构建

    判定方式：Modules\ 下每个「目录名与其中清单同名」的子目录算一个模块。
    恰好只有一个 `Winst` 时就是单一模块形态，否则按开发树逐个导入。

    两种形态都不需要清单文件：新增 / 删除 / 重命名模块只动磁盘上的目录，
    本脚本和 build.ps1 都不用改。顺序也不影响正确性，因为函数文件只定义
    函数、加载期没有互相调用。

    设计说明
    --------
    1. 本入口刻意不使用 param / CmdletBinding。
       winst 的 CLI 使用 --force、--pkg-dir=... 这类长开关，交给 PowerShell
       参数绑定器会把它们当成未知参数并直接报错。参数一律从 $args 读。

    2. 本入口只做五件事：
           设置进程级偏好
           记录根目录
           按当前形态加载模块
           调用 Winst.App 的应用入口
           把结果映射为进程退出码
       任何安装、网络、菜单逻辑都不出现在这里。

    3. 模块按绝对路径逐个 Import-Module，不依赖 PSModulePath。
       这也是「解压到任意目录都能用」的实现方式。

    4. 不支持点源加载（. .\winst.ps1）。
       它只返回一条警告就结束，避免调用方以为加载成功却拿不到任何函数。
       要拿函数请 Import-Module Modules\Winst\Winst.psd1（release）或
       Modules\<模块名>\<模块名>.psd1（开发树）。
#>

# ---------------------------------------------------------------- 点源保护
if ($MyInvocation.InvocationName -eq '.') {
    Write-Warning 'winst.ps1 是应用入口，不支持点源加载。请直接运行它，或 Import-Module Modules\Winst\Winst.psd1。'
    return
}

# ------------------------------------------------------------ 进程级偏好
Set-StrictMode -Version 2
$ErrorActionPreference = 'Stop'
$ProgressPreference = 'SilentlyContinue'

# 元数据请求 / 下载走 TLS 1.2 以上；个别受限环境不允许修改，忽略即可。
try {
    [Net.ServicePointManager]::SecurityProtocol = [Net.ServicePointManager]::SecurityProtocol -bor [Net.SecurityProtocolType]::Tls12
} catch {
}

# ------------------------------------------------------------------ 根目录
$script:WinstRoot = $PSScriptRoot
if (-not $script:WinstRoot) {
    # $PSScriptRoot 为空只可能出现在 -Command 内联执行等场景。
    $script:WinstRoot = (Get-Location).ProviderPath
}

$script:WinstExitCode = 0
$script:WinstArguments = @()
if ($null -ne $args) {
    $script:WinstArguments = @($args)
}

# ---------------------------------------------------------------- 模块加载
function Import-WinstLocalModule {
    <#
    .SYNOPSIS
        按绝对路径导入一个本地模块。

    .DESCRIPTION
        使用 -DisableNameChecking：函数名里有 Write-Section、Read-WinstPause
        这类非标准动词，改名会波及全部调用点，因此只屏蔽警告、不改名。

        开发时设置环境变量 WINST_DEV=1 可强制重新导入（避免模块缓存）。

    .OUTPUTS
        [void]
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$ManifestPath
    )

    if (-not (Test-Path -LiteralPath $ManifestPath -PathType Leaf)) {
        throw ('缺少模块清单：{0}' -f $ManifestPath)
    }

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
        @{ Mode; Manifests }
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

    $mode = 'multi'
    if ($manifests.Count -eq 1) { $mode = 'bundle' }

    return @{ Mode = $mode; Manifests = $manifests }
}

try {
    $plan = Get-WinstModulePlan -Root $script:WinstRoot

    foreach ($manifestPath in $plan.Manifests) {
        Import-WinstLocalModule -ManifestPath $manifestPath
    }

    # 跨模块状态必须先建好：StrictMode 下读取未初始化的状态会得到 $null，
    # 随后对 $null 取成员 / 调方法会直接抛异常。
    $null = Initialize-WinstState

    # 应用入口：负责 CLI 解析、命令分发、菜单，返回退出码。
    $result = Invoke-WinstApplication -Root $script:WinstRoot -Arguments $script:WinstArguments

    if ($null -ne $result) {
        if ($result -is [int]) {
            $script:WinstExitCode = $result
        } elseif ($null -ne $result.PSObject.Properties['ExitCode']) {
            $script:WinstExitCode = [int]$result.ExitCode
        }
    }
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
