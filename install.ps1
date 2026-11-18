<#
    一行安装引导，供 irm | iex 执行。使用 UTF-8 无 BOM，失败时抛出异常。
    从 release 下载并解压，在子进程执行 winst install winst --from，等待安装结束再清理。
#>

$winstInstallPreviousError = $ErrorActionPreference
$winstInstallPreviousProgress = $ProgressPreference
try {
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

    $winstInstallSize = (Get-Item -LiteralPath $winstInstallZip -ErrorAction Stop).Length
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

    # ---------------------------------------------------------------- 3. 安装
    Write-Host '  正在安装 winst …' -ForegroundColor Gray
    Write-Host ''

    # 带子命令的入口会等待提权进程并转发退出码，临时安装包须保留到此时。
    $winstInstallStart = New-Object Diagnostics.ProcessStartInfo
    $winstInstallStart.FileName = 'powershell.exe'
    $winstInstallStart.Arguments = '-NoProfile -ExecutionPolicy Bypass -File "{0}" install winst --from "{1}"' -f $winstInstallEntry, $winstInstallApp
    $winstInstallStart.UseShellExecute = $false
    $winstInstallStart.EnvironmentVariables.Remove('WINST_NO_ELEVATE')
    $winstInstallProcess = [Diagnostics.Process]::Start($winstInstallStart)
    try {
        $winstInstallProcess.WaitForExit()
        $winstInstallExitCode = $winstInstallProcess.ExitCode
        if ($null -eq $winstInstallExitCode) { throw '无法取得安装进程退出码' }
    } finally {
        $winstInstallProcess.Dispose()
    }

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

} finally {
    $ErrorActionPreference = $winstInstallPreviousError
    $ProgressPreference = $winstInstallPreviousProgress
}
