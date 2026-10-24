#Requires -Version 5.1

function Get-WinstPathRemovalPlan {
    <#
    .SYNOPSIS
        计算「从 PATH 里移除某一项」的结果，不落盘：返回要保留的项、移除数量，以及是否因会清空 PATH 而拒绝。
    .DESCRIPTION
        纯计算，便于校验「删完之后 PATH 会不会消失」这条不可逆操作：
        `Set-WinstEnvironmentVariableEx` 把空值当作「删除整个变量」，因此删到一项不剩时必须拒绝写入。
    .OUTPUTS
        @{ Removed; Kept; Refused }
    #>
    param(
        [string[]]$Segments = @(),
        [string]$PathValue
    )

    $kept = New-Object 'System.Collections.Generic.List[string]'
    $removed = 0
    $wanted = ([string]$PathValue).Trim().Trim('"')
    foreach ($segment in @($Segments)) {
        $one = [string]$segment
        if ($one.Trim().Trim('"') -ieq $wanted) { $removed++; continue }
        $kept.Add($one)
    }
    # 删到空 = PATH 变量整体消失（不可逆，且用户原有项也一起没了）→ 拒绝写入
    $refused = ($removed -gt 0 -and $kept.Count -eq 0)
    return @{ Removed = $removed; Kept = @($kept.ToArray()); Refused = $refused }
}
