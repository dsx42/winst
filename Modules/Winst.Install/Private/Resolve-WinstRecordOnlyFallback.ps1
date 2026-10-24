#Requires -Version 5.1

function Resolve-WinstRecordOnlyFallback {
    <#
    .SYNOPSIS
        卸载程序没能完成任务时，决定「是否只移除安装记录」并给出中止原因。
    .DESCRIPTION
        两条路径（registry 跑官方卸载器 / appx 移除应用包）失败后处理完全一样，因此共用这里：
          ① 交互式菜单里就地问一句「是否只移除安装记录」（菜单里不出现 --force 这类命令行开关）；
          ② 同意 → 只移除记录，调用方继续走「回收系统项 + 删台账」；
          ③ 不同意 → 中止卸载，并按界面给两套文案（菜单提「重新进入」、命令行提 `--force`）。
        两条菜单文案由 -MenuAbortFormat 传入。
    .OUTPUTS
        @{ Abort; Error }   Abort = $true 时调用方应直接返回该 Error
    #>
    param(
        [Parameter(Mandatory = $true)][string]$Id,
        [Parameter(Mandatory = $true)][string]$Reason,
        [Parameter(Mandatory = $true)][hashtable]$RunState,
        $Yes,
        # 菜单侧中止文案（含 {0} 占位，取 $Reason）；两处措辞不同，必须传入
        [Parameter(Mandatory = $true)][string]$MenuAbortFormat
    )

    if (-not $RunState.ForceRemove) {
        # 简单函数必须括号化：否则 -and / -not 会被当作实参塞进 $args，整条件退化为 if (Test-WinstMenuMode)
        if ((Test-WinstMenuMode) -and (-not $Yes) -and (-not (Test-WinstInputRedirected))) {
            # 菜单里不出现「请加 --force」：就地问一句，同意即只移除安装记录
            $RunState.ForceRemove = Read-WinstRemoveRecordOnlyChoice -Name $Id -Reason $Reason
        }
        if (-not $RunState.ForceRemove) {
            if (Test-WinstMenuMode) {
                # 菜单侧：不提命令行开关，只说清「记录保留着、可以再进来确认」
                return @{ Abort = $true; Error = ($MenuAbortFormat -f $Reason) }
            }
            return @{ Abort = $true; Error = ('{0}；如已手动卸载，可加 --force 只移除安装记录。' -f $Reason) }
        }
    }
    return @{ Abort = $false; Error = '' }
}
