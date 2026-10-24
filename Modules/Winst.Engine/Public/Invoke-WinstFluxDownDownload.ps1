#Requires -Version 5.1

function Invoke-WinstFluxDownDownload {
    <#
    .SYNOPSIS
        调用 FluxDown CLI（独立模式）下载单个地址到指定目录。
    .DESCRIPTION
        `fluxdown.exe add <url> -d <目录> [-o <文件名>] --local [--proxy <url>]`——`--local`
        为独立模式：不连服务、不需要令牌、进程内引擎、阻塞至终态，按退出码判定成败。
        引擎自己的输出（任务号 / 进度等）**不进 winst 界面**：用「不接触当前控制台」的隐藏进程 + 捕获输出
        （见 Invoke-WinstCapturedCommand；解压引擎 7z 同样用 `-bso0 -bse0 -bsp0` 静音）——默认丢弃，
        `--verbose` 下打印，失败时把尾部并入错误原因便于排查。
        `-Segments` 对应引擎的 `-s/--segments`（分段 / 线程数）：0 = 不传、由引擎自动决定；
        多段并发被限速时由调用方用 `-s 1` 单连接重试。
    .OUTPUTS
        @{ Ok; ExitCode; Error; Segments }
    #>
    param(
        [Parameter(Mandatory = $true)][hashtable]$Context,
        [Parameter(Mandatory = $true)][string]$Url,
        [Parameter(Mandatory = $true)][string]$DestDir,
        [string]$FileName = '',
        [string]$ProxyUrl = '',
        [int]$Segments = 0
    )

    $result = @{ Ok = $false; ExitCode = -1; Error = ''; Segments = $Segments }
    $exe = Get-WinstEngineExe -Context $Context -Id (Get-WinstDownloadEngineId)
    if (-not $exe) {
        $result.Error = '下载引擎（FluxDown CLI）不可用'
        return $result
    }
    if (-not (Test-Path -LiteralPath $DestDir -PathType Container)) {
        $null = New-Item -ItemType Directory -Path $DestDir -Force -ErrorAction SilentlyContinue
    }

    # 地址 / 文件名都来自清单，而命令行是拼成一个字符串传给引擎的：
    # 值里含引号会截断参数、注入新开关。地址必须是绝对 URI（http / https / ftp 等）且不含引号；
    # 目录 / 代理这类本机配置里的引号按 Windows argv 规则转义成 \"
    $parsedUrl = $null
    if (-not [Uri]::TryCreate([string]$Url, [UriKind]::Absolute, [ref]$parsedUrl) -or ([string]$Url).Contains('"')) {
        $result.Error = ('下载地址不合法（需要绝对地址，且不能含引号）：{0}' -f $Url)
        return $result
    }
    if ($FileName -and ([string]$FileName).Contains('"')) {
        $result.Error = ('下载文件名不合法（不能含引号）：{0}' -f $FileName)
        return $result
    }

    $argText = 'add "{0}" -d "{1}"' -f $Url, ([string]$DestDir).Replace('"', '\"')
    if ($FileName) { $argText += ' -o "{0}"' -f $FileName }
    $argText += ' --local'
    if ($ProxyUrl) { $argText += ' --proxy "{0}"' -f ([string]$ProxyUrl).Replace('"', '\"') }
    # -s 0 不传（引擎自动分段）；调用方按「多段失败 → 单连接重试」的策略传 -s 1
    if ($Segments -gt 0) { $argText += ' -s {0}' -f $Segments }

    try {
        # 不用 `Start-Process -NoNewWindow`：那样引擎与 winst 共用同一个控制台，它的任务号 / 进度会直接打在界面上
        # 。下载可能很久，因此不限时；成败判定仍是退出码。
        $run = Invoke-WinstCapturedCommand -FilePath $exe -Arguments $argText -NoTimeout
        $result.ExitCode = -1
        if ($null -ne $run.ExitCode) { $result.ExitCode = [int]$run.ExitCode }

        # 引擎输出：默认丢弃，--verbose 下打印；失败时只取尾部（折成一行）并入错误原因
        $engineParts = @()
        foreach ($chunk in @($run.Text, $run.ErrText)) {
            $trimmed = ([string]$chunk).Trim()
            if ($trimmed) { $engineParts += $trimmed }
        }
        $engineOutput = ($engineParts -join "`n")
        if ($engineOutput -and (Get-WinstState -Name WinstOptions) -and (Get-WinstState -Name WinstOptions).Verbose) {
            Write-Host ('  [verbose] 下载引擎输出: {0}' -f $engineOutput) -ForegroundColor DarkGray
        }

        if ($run.TimedOut) {
            $result.Error = ('下载引擎超时（已结束进程）：{0}' -f $exe)
        } elseif ($result.ExitCode -eq 0) {
            $result.Ok = $true
        } else {
            $result.Error = ('下载引擎退出码 {0}' -f $result.ExitCode)
            $tail = $engineOutput
            if ($tail.Length -gt 2000) { $tail = $tail.Substring($tail.Length - 2000) }
            $tail = ($tail -replace '\s+', ' ').Trim()
            if ($tail) { $result.Error += ('；引擎输出: {0}' -f $tail) }
        }
    } catch {
        $result.Error = ('调用下载引擎失败：{0}' -f $_.Exception.Message)
    }
    return $result
}
