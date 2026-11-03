#Requires -Version 5.1

function ConvertFrom-WinstUpdateTargetsResult {
    <#
    .SYNOPSIS
        把 `Invoke-WinstUpdateTargets` 的汇总结果映射成「自定义更新」的返回值。
    .DESCRIPTION
        按实际结果如实标记 Ok：下载失败、校验失败、退出码非 0 都算失败，并原样带回 ExitCode 与失败原因，
        调用方（菜单 / CLI）据此如实提示。
    .OUTPUTS
        @{ Ok; Cancelled; Mode; Source; ExitCode; Error; Updated; Skipped; Failed }
    #>
    param($Result, [string]$Mode = '', [string]$Source = '')

    # 执行阶段的取消只计入 Skipped；Cancelled 专供选择阶段要求回退默认更新。
    $mapped = @{ Ok = $false; Cancelled = $false; Mode = $Mode; Source = $Source; ExitCode = 0; Error = '';
        Updated = 0; Skipped = 0; Failed = 0 }
    if (-not $Result) {
        $mapped.Error = '更新没有返回结果'
        $mapped.Failed = 1
        return $mapped
    }
    $mapped.Ok = [bool]$Result.Ok
    $mapped.ExitCode = [int]$Result.ExitCode
    $mapped.Updated = [int]$Result.Updated
    $mapped.Skipped = [int]$Result.Skipped
    $mapped.Failed = [int]$Result.Failed
    if (-not $mapped.Ok) {
        $failed = [int]$Result.Failed
        if ($failed -gt 0) {
            $mapped.Error = ('{0} 个软件更新失败（退出码 {1}）' -f $failed, $mapped.ExitCode)
        } else {
            $mapped.Failed = 1
            $mapped.Error = ('更新未完成（退出码 {0}）' -f $mapped.ExitCode)
        }
    }
    return $mapped
}
