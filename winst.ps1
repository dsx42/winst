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

    2. 本入口只做六件事：
           设置进程级偏好
           记录根目录
           必要时申请管理员权限并重启自己
           按当前形态加载模块
           调用 Winst.App 的应用入口
           把结果映射为进程退出码
       任何安装、网络、菜单逻辑都不出现在这里。

    3. 模块按绝对路径逐个 Import-Module，不依赖 PSModulePath。
       这也是「解压到任意目录都能用」的实现方式。

    4. 启动即申请管理员权限（只读调用 -v / --version / -h / --help 例外）：
       安装软件要写系统级环境变量、要静默运行 msi / exe 安装程序、要读写 HKLM 卸载记录，
       非管理员会在流程中段失败。WINST_NO_ELEVATE=1 可跳过提权。

    5. 不支持点源加载（. .\winst.ps1）。
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

# ------------------------------------------------------------------ 根目录
# 必须在提权之前算好：提权要按它重新启动自己。
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

# ------------------------------------------------------------ 管理员权限
# winst 要写系统级环境变量（安装位置在 %USERPROFILE% 之外时，PATH / 环境变量落在 Machine 作用域）、
# 要静默运行 msi / exe 安装程序、要读写 HKLM 下的卸载记录——这些在非管理员下会失败在流程中段，
# 用户看到的是「装到一半报错」而不是「权限不够」。因此启动即申请提权：
#
#   - 已经是管理员：继续。
#   - 不是管理员：用 RunAs 重新启动自己（带上原来的全部参数），本进程立即退出。
#     UAC 被取消时 RunAs 会抛异常，此时明确报错并返回 1，不静默降级成「无权限继续跑」。
#   - WINST_NO_ELEVATE=1：跳过提权（排障 / 只读查询时不想弹 UAC），按当前权限运行。
#   - 只读调用（-v / --version / -h / --help）：不提权。这些会被别的 winst 进程频繁调用
#     做版本检测（清单里 winst 条目的 detect 就是 `winst.cmd -v`），每次弹 UAC 会直接卡死自更新；
#     它们不写任何文件，也不需要管理员权限。
#
# 判据是「命令位置」而不是「参数里出现过某个词」：`winst install Foo help` 是安装，
# 不能因为末尾那个 help 就跳过提权，否则会装到一半才因权限失败。
# 与 Modules\Winst.App\Private\Test-WinstReadOnlyInvocation.ps1 保持同一口径。
function Test-WinstReadOnlyArgument {
    param([string[]]$Arguments = @())

    $waitingForValue = $false
    foreach ($one in @($Arguments)) {
        $text = ([string]$one).Trim()
        if (-not $text) { continue }

        if ($waitingForValue) { $waitingForValue = $false; continue }
        if ($text -ieq '--install-root' -or $text -ieq '--pkg-dir' -or $text -ieq '--proxy') {
            $waitingForValue = $true
            continue
        }
        if ($text -like '--install-root=*' -or $text -like '--pkg-dir=*' -or $text -like '--proxy=*') { continue }
        if ($text -ieq '--offline' -or $text -ieq '--dry-run' -or $text -ieq '--yes' -or
            $text -ieq '-y' -or $text -ieq '--verbose') { continue }

        if (-not $text.StartsWith('-')) {
            if ($text -ieq 'version' -or $text -ieq 'help' -or $text -ieq '?') { return $true }
            return $false
        }
        if ($text -ieq '-v' -or $text -ieq '--version' -or $text -ieq '-h' -or
            $text -ieq '--help' -or $text -ieq '-?') {
            return $true
        }
    }
    return $false
}

function Test-WinstNeedsElevation {
    param([string[]]$Arguments = @())

    if ($env:WINST_NO_ELEVATE -eq '1') { return $false }
    if (Test-WinstReadOnlyArgument -Arguments $Arguments) { return $false }
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

if (Test-WinstNeedsElevation -Arguments $script:WinstArguments) {
    $winstElevateArgs = New-Object 'System.Collections.Generic.List[string]'
    $winstElevateArgs.Add('-NoProfile')
    $winstElevateArgs.Add('-ExecutionPolicy')
    $winstElevateArgs.Add('Bypass')
    $winstElevateArgs.Add('-File')
    $winstElevateArgs.Add($script:WinstRoot + '\winst.ps1')
    foreach ($one in @($script:WinstArguments)) { $winstElevateArgs.Add([string]$one) }

    # Start-Process -ArgumentList 收到数组时只用空格拼接、不会加引号：
    # 路径含空格（用户名形如 John Smith 时 %USERPROFILE%\...\winst 就带空格）会被截断，
    # 因此逐项按 Windows argv 规则加引号。
    $winstArgText = (($winstElevateArgs | ForEach-Object {
                $winstArgValue = [string]$_
                if ($winstArgValue -notmatch '[\s"]') { return $winstArgValue }
                $winstArgBuilder = New-Object System.Text.StringBuilder
                $null = $winstArgBuilder.Append('"')
                $winstArgSlashes = 0
                foreach ($winstArgChar in $winstArgValue.ToCharArray()) {
                    if ($winstArgChar -eq '\') { $winstArgSlashes++; continue }
                    if ($winstArgChar -eq '"') {
                        $null = $winstArgBuilder.Append(('\' * (($winstArgSlashes * 2) + 1)))
                        $null = $winstArgBuilder.Append('"')
                        $winstArgSlashes = 0
                        continue
                    }
                    if ($winstArgSlashes -gt 0) { $null = $winstArgBuilder.Append(('\' * $winstArgSlashes)); $winstArgSlashes = 0 }
                    $null = $winstArgBuilder.Append($winstArgChar)
                }
                $null = $winstArgBuilder.Append(('\' * ($winstArgSlashes * 2)))
                $null = $winstArgBuilder.Append('"')
                return $winstArgBuilder.ToString()
            }) -join ' ')

    try {
        $winstElevated = Start-Process -FilePath 'powershell.exe' -ArgumentList $winstArgText `
            -Verb RunAs -PassThru -ErrorAction Stop
        if ($winstElevated) {
            [Console]::Out.WriteLine('winst: 需要管理员权限，已在新窗口中以管理员身份启动，本窗口会自动关闭。')
        }
        exit 0
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
# 从 PowerShell 7 会话启动（winst.cmd 在 pwsh 里跑、双击时继承 pwsh 的环境变量）时，
# 本进程会继承 PowerShell 7 的 PSModulePath，其中 Microsoft.PowerShell.Utility 等
# 只适用于 Core 的版本排在 Windows PowerShell 自己的目录之前：Desktop 侧自动加载失败，
# Get-FileHash / Get-Acl 这类内置命令直接变成「无法识别的命令」，下载后校验、自更新校验
# 全部报错。这里把系统自带的 Modules 目录补回最前面，让 5.1 的内置模块优先命中。
# 只影响本进程，不改用户环境变量。
try {
    $winstSystemModules = [IO.Path]::Combine([string]$env:WINDIR, 'System32\WindowsPowerShell\v1.0\Modules')
    if ($winstSystemModules -and (Test-Path -LiteralPath $winstSystemModules -PathType Container)) {
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
