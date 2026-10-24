#Requires -Version 5.1

function Get-WinstRowCompanionInfo {
    <#
    .SYNOPSIS
        取某一行的「主包无变化、只有配套文件有变化」信息（供更新检查与更新执行共用）。
    .DESCRIPTION
        更新检查（列表里标「附加文件有更新」）与更新执行（决定走「仅配套文件更新」还是「已是最新」）
        用的必须是同一个判定，因此统一走这里：

            $companionPlanEntry = Get-WinstRowBestPlanEntry -Row $Row
            if ($companionPlanEntry -and $companionPlanEntry['Plan']) {
                $companionInfo = Get-WinstCompanionUpdateInfo -Context $Context -Plan $companionPlanEntry['Plan']
            }

        「先取该行的最佳计划条目、再拿配套信息」这个两步链一旦两边不一致（比如一边忘了判空、
        或改用别的取条目函数），就会出现「检查时说要更新、执行时说已是最新」。

        注意本函数**只回答「配套文件有没有变化」**，不决定是否要更新 —— 调用方自己按
        `$info.CompanionsOnly` 决定动作，因为检查侧与执行侧的动作语义不同：
          · 检查侧：只标 Action/Message 供展示；
          · 执行侧：`-Force` 时必须故意跳过这条分支（用户明确要求重装），检查侧没有这个语义。
    .OUTPUTS
        Get-WinstCompanionUpdateInfo 的结果（@{ Checked; CompanionsOnly; ChangedCount; Names; Error }）；
        取不到计划条目时返回 $null。
    #>
    param(
        [hashtable]$Context,
        [Parameter(Mandatory = $true)]$Row
    )

    $planEntry = Get-WinstRowBestPlanEntry -Row $Row
    if (-not $planEntry -or -not $planEntry['Plan']) { return $null }
    return (Get-WinstCompanionUpdateInfo -Context $Context -Plan $planEntry['Plan'])
}
