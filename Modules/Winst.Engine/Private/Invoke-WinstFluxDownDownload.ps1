#Requires -Version 5.1

function Invoke-WinstFluxDownDownload {
    <#
    .SYNOPSIS
        在本进程外运行一次独立下载，使用自动分段。单文件的工作目录允许识别引擎改名的产物。
    #>
    param([string]$Exe, [string]$Url, [string]$WorkDir, [string]$FileName, [hashtable]$Headers, [string]$ProxyUrl)

    $argsList = @('add', '--local', '-d', $workDir, '-o', $FileName)
    if ($ProxyUrl) { $argsList += @('--proxy', $ProxyUrl) }
    $options = @{ 'Cookie' = '--cookies'; 'Referer' = '--referrer'; 'User-Agent' = '--user-agent' }
    foreach ($name in $options.Keys) {
        if ($Headers[$name]) { $argsList += @($options[$name], [string]$Headers[$name]) }
    }
    $argsList += $Url
    $arguments = foreach ($value in $argsList) {
        if (-not (Test-WinstArgumentSafe -Value $value)) {
            return @{ Ok = $false; FailureKind = 'Other'; WorkDir = $workDir; Error = '下载参数含有双引号或控制字符' }
        }
        Format-WinstCommandArgument -Value $value
    }

    $run = Invoke-WinstCapturedCommand -FilePath $Exe -Arguments ($arguments -join ' ') -NoTimeout -TailOutput -MaxOutputChars 4096
    if (-not $run.Ok -or $null -eq $run.ExitCode) {
        return @{ Ok = $false; FailureKind = 'Other'; Error = ('下载引擎执行失败，暂存位置 {0}：{1}' -f $workDir, $run.Error) }
    }
    if ($run.ExitCode -ne 0) {
        $message = ([string]$run.ErrText).Trim()
        if (-not $message) { $message = ([string]$run.Text).Trim() }
        $partial = Get-Item -LiteralPath (Join-WinstPath $workDir ($FileName + '.fdownloading')) -ErrorAction SilentlyContinue
        $received = 0L
        if ($partial) { $received = $partial.Length }
        $kind = Get-WinstFluxFailureKind -Message $message -ExitCode $run.ExitCode -ReceivedBytes $received
        # 引擎诊断可能回显带签名的地址或请求参数，仅展示与分类相关的状态和退出码。
        $reason = @{ Connect = '无法建立连接'; Auth = '文件请求遭拒绝（HTTP 401/403）'; Http = '文件服务器返回 HTTP 错误'; Interrupted = '接收文件时断流';
            Cancelled = '用户取消'; Disk = '写入文件失败'; Other = '下载失败' }
        return @{ Ok = $false; FailureKind = $kind; WorkDir = $workDir
            Error = ('{0}（FluxDown 退出码 {1}）' -f $reason[$kind], $run.ExitCode) }
    }
    $output = Join-WinstPath $workDir $FileName
    if (-not (Test-Path -LiteralPath $output -PathType Leaf)) {
        $files = @(Get-ChildItem -LiteralPath $workDir -File -Force -ErrorAction Stop |
            Where-Object { $_.Name -notlike '*.fdownloading' })
        if ($files.Count -ne 1) {
            return @{ Ok = $false; FailureKind = 'Other'; WorkDir = $workDir; Error = ('缺少期望文件 {0}，有 {1} 个候选文件' -f $FileName, $files.Count) }
        }
        $output = $files[0].FullName
    }
    Assert-WinstSafeWritePath -Path $output
    return @{ Ok = $true; Path = $output; WorkDir = $workDir }
}
