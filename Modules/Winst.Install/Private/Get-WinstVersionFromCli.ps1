#Requires -Version 5.1

function Get-WinstVersionFromCli {
    <#
    .SYNOPSIS
        detect.method = cliVersion：运行检测命令，从输出里识别版本（stdout 优先，回退 stderr）。
    #>
    param(
        [hashtable]$Context,
        $Plan,
        $Detect,
        [string]$InstallDir = '',
        [string]$Kind = '',
        $Between = @(),
        [hashtable]$Result
    )

    # 检测命令运行哪个程序：detect.exe 优先（如 FluxDown 用同目录的 fluxdown_nmh.exe 报版本），缺省 = 主程序
    $main = Expand-PlanPlaceholders -Value (Get-EntryString -Entry $Detect -Key 'exe') -InstallDir $InstallDir -InstallRoot $Context.InstallRoot
    if (-not $main) { $main = Get-WinstMainProgram -Plan $Plan -InstallDir $InstallDir }
    if (-not $main) { return }
    $mainPath = $main
    if ($InstallDir -and -not [IO.Path]::IsPathRooted($mainPath)) { $mainPath = Join-WinstPath $InstallDir $mainPath }
    if (-not (Test-Path -LiteralPath $mainPath -PathType Leaf)) { return }

    $Result.Found = $true
    $argsText = Get-EntryString -Entry $Detect -Key 'versionArgs'
    if (-not $argsText) { $argsText = '-v' }

    $exePath = $mainPath
    $fullArgs = $argsText
    if ($mainPath -match '(?i)\.ps1$') {
        $exePath = 'powershell.exe'
        $fullArgs = ('-NoProfile -NonInteractive -ExecutionPolicy Bypass -File "{0}" {1}' -f $mainPath, $argsText)
    } elseif ($mainPath -match '(?i)\.jar$') {
        # jar 本身不是可执行文件，要由 java 启动（如 PlantUML：java -jar plantuml.jar --version）
        $javaExe = Get-WinstJavaExecutable -Context $Context
        if (-not $javaExe) {
            $Result.Detail = '这个主程序要由 java 运行，但没有找到 java.exe；请先安装 JDK（如 jdk21）或把 java 放进 PATH'
            $Result.Note = '这个主程序要由 java 运行，但没有找到 java.exe。请先安装 JDK（如 jdk21），或把 java 放进 PATH 后重试。'
            return
        }
        $exePath = $javaExe
        $fullArgs = ('-jar "{0}" {1}' -f $mainPath, $argsText)
    }

    # 在隔离的隐藏进程里执行（不继承当前控制台，见 Invoke-WinstCapturedCommand）：
    # 这条命令的输出只用来识别版本，不往 winst 界面上打；检测命中 / 未命中由调用方各用一行说明
    $cmd = Invoke-WinstCapturedCommand -FilePath $exePath -Arguments $fullArgs -TimeoutMs 10000
    if (-not $cmd.Ok) {
        $Result.Detail = [string]$cmd.Error
        # 超时 / 起不来都属于「检测没跑成」，要明确告诉用户这次没检出真版本（安装本身照常完成）
        $Result.Note = [string]$cmd.Error
        return
    }
    $text = [string]$cmd.Text
    $errText = [string]$cmd.ErrText

    # 先在「临时结果」上试 stdout，取不到再试 stderr（java -version 等把版本打到 stderr）
    $detail = ('命令: {0} {1}' -f $exePath, $fullArgs)
    $probe = @{ Ok = $false; Found = $false; Version = ''; Method = $Result.Method; Detail = ''; Note = '' }
    Set-WinstDetectedVersionFromRaw -Result $probe -Raw ([string]$text) -Kind $Kind -Between $Between
    if (-not $probe.Ok -and $errText) {
        Set-WinstDetectedVersionFromRaw -Result $probe -Raw ([string]$errText) -Kind $Kind -Between $Between
    }
    if (-not $probe.Ok) { $Result.Detail = $detail; return }
    $Result.Ok = $true
    $Result.Version = $probe.Version
    $Result.Detail = $detail
}
