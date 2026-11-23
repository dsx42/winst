#Requires -Version 5.1

function ConvertFrom-WinstUpdateTargetsResult {
    <#
    .SYNOPSIS
        返回自定义更新的成功和失败计数，以及用于显示的失败原因。
    #>
    param($Result)

    # 选择阶段取消才回退到默认更新，执行阶段取消计入跳过。
    $mapped = @{ Cancelled = $false; Updated = 0; Failed = 0; Error = '' }
    if (-not $Result) {
        $mapped.Error = '更新没有返回结果'
        $mapped.Failed = 1
        return $mapped
    }
    $mapped.Updated = [int]$Result.Updated
    $mapped.Failed = [int]$Result.Failed
    if (-not $Result.Ok) {
        if ($mapped.Failed -gt 0) {
            $mapped.Error = ('{0} 个软件更新失败（退出码 {1}）' -f $mapped.Failed, $Result.ExitCode)
        } else {
            $mapped.Failed = 1
            $mapped.Error = ('更新未完成（退出码 {0}）' -f $Result.ExitCode)
        }
    }
    return $mapped
}
