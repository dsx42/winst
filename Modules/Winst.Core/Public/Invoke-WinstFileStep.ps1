#Requires -Version 5.1

function Invoke-WinstFileStep {
    <#
    .SYNOPSIS
        记录文件操作的结果和耗时，返回操作的输出并传递原始错误。
    #>
    param([Parameter(Mandatory = $true)][string]$Name,
        [Parameter(Mandatory = $true, ParameterSetName = 'Run')][scriptblock]$Action,
        [Parameter(Mandatory = $true, ParameterSetName = 'Skip')][string]$Skip,
        [switch]$Quiet)

    $stepTimer = [Diagnostics.Stopwatch]::StartNew()
    if ($PSCmdlet.ParameterSetName -eq 'Skip') {
        if (-not $Quiet) { Write-Host ('    {0} · 跳过（{1}，{2:F1} 秒）' -f $Name, $Skip, $stepTimer.Elapsed.TotalSeconds) }
        return
    }

    try {
        & $Action
        if (-not $Quiet) { Write-Host ('    {0} · 完成（{1:F1} 秒）' -f $Name, $stepTimer.Elapsed.TotalSeconds) }
    } catch {
        if (-not $Quiet) { Write-Host ('    {0} · 失败（{1:F1} 秒）：{2}' -f $Name, $stepTimer.Elapsed.TotalSeconds, $_.Exception.Message) -ForegroundColor Red }
        throw
    }
}
