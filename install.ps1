<#
    install.ps1  (仓库根)

    一行安装引导脚本，只做四件事：下载 release zip、解压出 winst.ps1、
    提权并等它执行 `winst install winst --from <zip>`、按退出码报告结果。

    编码约束（与仓库其它 .ps1 相反）
    --------------------------------
    本文件必须 **UTF-8 无 BOM**，且不能写 `#Requires`。

    它通过 `irm | iex` 执行：`irm` 取回的文本原样交给 `iex` 解析，前导的 U+FEFF
    在解析字符串时不按 BOM 剥离，而是被当成命令名的一部分：

        ?#Requires : 无法将“?#Requires”项识别为 cmdlet ...

    这句报错不中断后续语句，于是表现为「安装成功，但屏幕上多一条报错」。
    同理，无 BOM 时 `#Requires` 只是被 `iex` 忽略（不报错但也不生效）。

    build.ps1 会校验这两点，避免编辑器把 BOM 加回来。
#>
<#
    winst 一行安装（引导脚本）

    用法：
        irm https://raw.githubusercontent.com/dsx42/winst/main/install.ps1 | iex

    想先看看内容再执行：
        irm https://raw.githubusercontent.com/dsx42/winst/main/install.ps1 | more

    它只做四件事
    ------------
        1. 下载 release 最新版的 winst.zip
        2. 解压到临时目录，只为拿到其中能运行的 winst.ps1
        3. 以管理员身份运行它并等它结束（本脚本层提权，子进程里不会再派生一个提权进程）
        4. 调用它：winst install winst --from <刚下载的 zip>

    安装逻辑不在这里
    ----------------
    安装目录怎么定、怎么解压合并、怎么建快捷方式、怎么写台账——全部在
    winst 的 Install-WinstSelf 里。本脚本一行都没有，它只是把 zip 交到
    winst 手上。所以这里既不会和 winst 的逻辑跑偏，也不会出现两套实现。

    为什么必须先解压
    ----------------
    winst.ps1 一启动就要按 $PSScriptRoot 导入 Modules\ 里的模块，
    而这些模块只存在于 zip 里。`irm .../winst.ps1 | iex` 拿到的只是纯文本、
    没有 Modules，必然起不来。所以需要一个不依赖任何本地文件的脚本先把包取下来。

    为什么第 3 步用 --from
    ----------------------
    --from 走本地安装包，不查软件源、不解析依赖、不联网。全新机器上软件源
    还没有缓存，这条路才走得通；否则「装 winst 需要先有软件源」会自锁。

    重复运行 = 更新
    ---------------
    已安装时再跑一次本脚本：winst 会读包里的版本号与本机台账比较，

        包更新   → 更新（替换文件，保留 lists\ 与 *.list，快捷方式不动）
        版本相同 → 提示已是最新，一个文件都不动
        包更旧   → 拒绝降级（确需降级用 --force）

    关于完整性校验
    --------------
    本脚本与被下载的 zip 来自同一个 TLS 源（GitHub），信任级别相同，因此
    这里不再单独校验哈希。走软件源的 `winst install winst`（不带 --from）
    仍按清单声明的 .sha512 校验；--from 没有清单可依，故不校验。

    与 `irm | iex` 配合的写法约束
    -----------------------------
    通过管道执行时，本脚本运行在调用者的作用域里，因此：

        - 不使用 param()：管道执行时参数传不进来，报错也不直观
        - 不使用 $PSScriptRoot / $PSCommandPath：管道执行时二者为空
        - 不使用 exit：会终止调用者的 PowerShell 会话，而不是只结束本脚本
          失败时抛出异常并写明原因
        - 不依赖任何本地文件：整个流程只有下载、解压、调用

    需要换安装位置 / 走代理时，用装好之后的 winst：

        winst install winst --install-root D:\winst --proxy http://127.0.0.1:7890
#>

# 管道执行时，函数与变量都落在调用者作用域，用显眼前缀避免碰坏用户环境。
$ErrorActionPreference = 'Stop'
$ProgressPreference = 'SilentlyContinue'

try {
    [Net.ServicePointManager]::SecurityProtocol =
        [Net.ServicePointManager]::SecurityProtocol -bor [Net.SecurityProtocolType]::Tls12
} catch {
    # 个别受限环境不允许改安全协议，忽略
}

# 固定文件名、不带版本号：GitHub 的 releases/latest/download/<名字> 会重定向到
# 最新 release 的该资产，所以这条地址永远指向最新版，一行命令不需要改。
$winstInstallArchiveUrl = 'https://github.com/dsx42/winst/releases/latest/download/winst.zip'
$winstInstallRoot = Join-Path ([IO.Path]::GetTempPath()) ('winst-install-' + [Guid]::NewGuid().ToString('N').Substring(0, 8))
$winstInstallZip = Join-Path $winstInstallRoot 'winst.zip'
$winstInstallApp = Join-Path $winstInstallRoot 'app'

Write-Host ''
Write-Host '  winst 安装程序' -ForegroundColor Cyan
Write-Host '  ----------------------------------------' -ForegroundColor DarkGray

try {
    $null = New-Item -ItemType Directory -Path $winstInstallRoot -Force

    # ---------------------------------------------------------------- 1. 下载
    Write-Host '  正在下载 winst …' -ForegroundColor Gray
    $null = Invoke-WebRequest -Uri $winstInstallArchiveUrl -OutFile $winstInstallZip -UseBasicParsing

    if (-not (Test-Path -LiteralPath $winstInstallZip -PathType Leaf)) {
        throw '下载完成后没有生成文件'
    }

    $winstInstallSize = (Get-Item -LiteralPath $winstInstallZip).Length
    if ($winstInstallSize -le 0) {
        throw '下载到的压缩包是空文件'
    }
    Write-Host ('  已下载 {0:N0} 字节' -f $winstInstallSize) -ForegroundColor Gray

    # ---------------------------------------------------------------- 2. 解压
    Write-Host '  正在解压 …' -ForegroundColor Gray
    $null = New-Item -ItemType Directory -Path $winstInstallApp -Force
    Expand-Archive -LiteralPath $winstInstallZip -DestinationPath $winstInstallApp -Force

    $winstInstallEntry = Join-Path $winstInstallApp 'winst.ps1'
    if (-not (Test-Path -LiteralPath $winstInstallEntry -PathType Leaf)) {
        throw ('解压后没有找到 winst.ps1（{0}）' -f $winstInstallEntry)
    }

    # 完整性自检：release 必须带模块目录，否则装上去也起不来。
    # 这里只做「一眼能看出坏了」的检查，真正的结构校验在 winst 侧（Set-WinstSelfTree）。
    $winstInstallManifests = @(Get-ChildItem -LiteralPath (Join-Path $winstInstallApp 'Modules') `
            -Recurse -Filter '*.psd1' -File -ErrorAction SilentlyContinue)
    if ($winstInstallManifests.Count -eq 0) {
        throw ('解压后缺少模块清单（{0}）' -f (Join-Path $winstInstallApp 'Modules'))
    }

    # ---------------------------------------------------------------- 3. 安装
    Write-Host '  正在安装 winst …' -ForegroundColor Gray
    Write-Host ''

    # 用独立进程运行解压出来的 winst.ps1：
    #   - 它按自己的 $PSScriptRoot 导入模块，正常工作
    #   - 不会污染调用者的会话 / 模块表
    #   - 退出码可直接取得，用于判断成败
    #
    # Start-Process -ArgumentList 收到数组时只是用空格拼成一条命令行，不会自动加引号：
    # 临时目录常带空格（用户名形如 John Smith 时 %TEMP% 就是 C:\Users\John Smith\...），
    # 不逐项加引号的话 -File 的路径会被空格截断，--from 的值也会被拆成两个参数。
    # 这里按 Windows argv 规则（同 winst 内部的 Format-WinstCommandArgument）自行加引号。
    $winstInstallArguments = @(
        '-NoProfile'
        '-ExecutionPolicy', 'Bypass'
        '-File', $winstInstallEntry
        'install', 'winst', '--from', $winstInstallZip
    )
    $winstInstallArgText = (($winstInstallArguments | ForEach-Object {
                $winstArgText = [string]$_
                if ($winstArgText -notmatch '[\s"]') { return $winstArgText }
                # 引号前的反斜杠要翻倍，结尾反斜杠要翻倍，否则会转义闭合引号
                $winstArgBuilder = New-Object System.Text.StringBuilder
                $null = $winstArgBuilder.Append('"')
                $winstArgSlashes = 0
                foreach ($winstArgChar in $winstArgText.ToCharArray()) {
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

    # 提权放在本脚本这一层，并等它真正结束：
    #   已是管理员 → 直接同步跑，输出留在当前窗口；
    #   不是管理员 → 用 runas 起一个管理员子进程。子进程里的 winst.ps1 启动时已是管理员，
    #                不会再把工作交给第三个进程，因此它返回的退出码就是安装结果。
    # 提权不在这一层完成时，子进程会「起一个新进程后自己 exit 0」，本脚本拿到的 0
    # 不代表装好了，而最后的 finally 会在安装读取 --from 之前删掉临时目录。
    $winstInstallIsAdmin = $false
    try {
        $winstInstallIdentity = [Security.Principal.WindowsIdentity]::GetCurrent()
        $winstInstallPrincipal = New-Object Security.Principal.WindowsPrincipal($winstInstallIdentity)
        $winstInstallIsAdmin = $winstInstallPrincipal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
    } catch {
        $winstInstallIsAdmin = $false
    }

    if ($winstInstallIsAdmin) {
        $winstInstallProcess = Start-Process -FilePath 'powershell.exe' `
            -ArgumentList $winstInstallArgText `
            -NoNewWindow -Wait -PassThru
    } else {
        $winstInstallStart = New-Object System.Diagnostics.ProcessStartInfo
        $winstInstallStart.FileName = 'powershell.exe'
        $winstInstallStart.Arguments = $winstInstallArgText
        $winstInstallStart.UseShellExecute = $true
        $winstInstallStart.Verb = 'runas'
        try {
            $winstInstallProcess = [Diagnostics.Process]::Start($winstInstallStart)
        } catch {
            throw ('无法以管理员身份启动安装程序（UAC 被取消？）：{0}' -f $_.Exception.Message)
        }
        $winstInstallProcess.WaitForExit()
    }

    $winstInstallExitCode = -1
    try { $winstInstallExitCode = [int]$winstInstallProcess.ExitCode } catch { $winstInstallExitCode = -1 }

    Write-Host ''
    if ($winstInstallExitCode -ne 0) {
        throw ('winst install 失败（退出码 {0}）' -f $winstInstallExitCode)
    }

    Write-Host '  完成。双击桌面或开始菜单的 winst 快捷方式即可打开。' -ForegroundColor Green
} catch {
    Write-Host ''
    Write-Host ('  安装失败：{0}' -f $_.Exception.Message) -ForegroundColor Red
    Write-Host '  可手动下载后解压运行：https://github.com/dsx42/winst/releases' -ForegroundColor DarkGray
    Write-Host '  若已有旧版本，也可用 winst install winst --force 重新安装。' -ForegroundColor DarkGray

    # 管道执行时不要 exit（会杀掉调用者的会话），改为抛出，让调用方看到红字。
    throw
} finally {
    try {
        if (Test-Path -LiteralPath $winstInstallRoot) {
            Remove-Item -LiteralPath $winstInstallRoot -Recurse -Force -ErrorAction SilentlyContinue
        }
    } catch { }
}
