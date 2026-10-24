#Requires -Version 5.1

function Write-WinstUninstallResult {
    <#
    .SYNOPSIS
        卸载结果三态输出（取消 / 失败 / 成功 + 重启与备注提示）。
    .DESCRIPTION
        「已装软件 → d」与「软件列表 → d」共用这段输出。
    #>
    param($Result)

    if ($Result.Cancelled) { return }
    if (-not $Result.Ok) {
        Write-Host ''
        Write-Host ('  失败: {0}' -f $Result.Error) -ForegroundColor Red
        return
    }
    Write-Host ''
    Write-Host ('  {0}' -f $Result.Message) -ForegroundColor Green
    if ($Result.NeedRestart) { Write-Host '  提示: 卸载程序提示需要重启电脑才能完成。' -ForegroundColor DarkYellow }
    foreach ($note in @($Result.Notes)) { Write-Host ('  提示: {0}' -f $note) -ForegroundColor DarkYellow }
}
