#Requires -Version 5.1

function Write-WinstInstallTargetResult {
    <#
    .SYNOPSIS
        按安装结果四态输出（取消 / 成功 / 跳过 / 失败 / 预览），跳过原因避免重复打印。
    .DESCRIPTION
        失败时**必须有原因**：Error 与 Message 都为空说明流程在某处静默返回了失败，
        这里补一句兜底说明，避免界面上只看到「失败 1」却没有任何线索。

        `-Quiet`（内嵌在依赖处理 / 更新流程里时）什么都不打印：那些调用方会自己转述结果，
        这里再打一遍只会让同一屏出现两份措辞。
    #>
    param($Install, [bool]$SkipReasonShown, [switch]$Quiet)

    if ($Quiet) { return }

    if ($Install.Cancelled) {
        Write-Host ('  已取消: {0}' -f $Install.Message) -ForegroundColor DarkGray
    } elseif ($Install.Preview) {
        if ($Install.Message) { Write-Host ('  {0}' -f $Install.Message) -ForegroundColor Cyan }
    } elseif ($Install.Ok -and -not $Install.Skipped) {
        if ($Install.Message) { Write-Host ('  {0}' -f $Install.Message) -ForegroundColor Green }
    } elseif ($Install.Skipped) {
        if (-not $SkipReasonShown) {
            Write-Host ('  已跳过: {0}' -f $Install.Message) -ForegroundColor DarkYellow
        }
    } else {
        $reason = [string]$Install.Error
        if (-not $reason) { $reason = [string]$Install.Message }
        if (-not $reason) { $reason = '安装流程没有给出原因（可用 --verbose 重试以取得更多信息）' }
        Write-Host ('  失败: {0}' -f $reason) -ForegroundColor Red
    }
}
