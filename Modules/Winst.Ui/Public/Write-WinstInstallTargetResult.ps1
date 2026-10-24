#Requires -Version 5.1

function Write-WinstInstallTargetResult {
    <#
    .SYNOPSIS
        按安装结果四态输出（取消 / 成功 / 跳过 / 失败），跳过原因避免重复打印。
    #>
    param($Install, [bool]$SkipReasonShown)

    if ($Install.Cancelled) {
        Write-Host ('  已取消: {0}' -f $Install.Message) -ForegroundColor DarkGray
    } elseif ($Install.Ok -and -not $Install.Skipped -and -not $Install.Preview) {
        if ($Install.Message) { Write-Host ('  {0}' -f $Install.Message) -ForegroundColor Green }
    } elseif ($Install.Skipped) {
        if (-not $SkipReasonShown) {
            Write-Host ('  已跳过: {0}' -f $Install.Message) -ForegroundColor DarkYellow
        }
    } elseif ($Install.Error) {
        Write-Host ('  失败: {0}' -f $Install.Error) -ForegroundColor Red
    }
}
