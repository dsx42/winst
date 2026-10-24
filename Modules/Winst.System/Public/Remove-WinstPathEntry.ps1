#Requires -Version 5.1

function Remove-WinstPathEntry {
    <#
    .SYNOPSIS
        从 PATH 里移除某一项（该作用域内的全部重复项），写回时保持其余项原样。
    .DESCRIPTION
        删到一项不剩时**拒绝写入**：空值会被 Set-WinstEnvironmentVariableEx 当成「删除 PATH 变量」，
        等于把用户原有的 PATH 一起抹掉（不可逆）。此时返回 Ok=$false 并说明原因。
    .OUTPUTS
        @{ Ok; Removed; Error }
    #>
    param(
        [Parameter(Mandatory = $true)][string]$PathValue,
        [Parameter(Mandatory = $true)][ValidateSet('User', 'Machine')][string]$Scope
    )

    $result = @{ Ok = $false; Removed = 0; Error = '' }
    if (-not $PathValue) { $result.Ok = $true; return $result }

    # 当前 PATH 用 WMI 读原值（不展开）——按原样逐项比较
    $current = Get-WinstEnvironmentValue -Name 'Path' -Scope $Scope
    if ($null -eq $current) { $current = '' }
    $segments = @(Get-WinstPathSegments -Value $current)

    $plan = Get-WinstPathRemovalPlan -Segments $segments -PathValue $PathValue
    $result.Removed = [int]$plan.Removed
    if ($result.Removed -eq 0) { $result.Ok = $true; return $result }
    if ($plan.Refused) {
        # 删光会让 PATH 变量整体消失（Set-WinstEnvironmentVariableEx 把空值当作删除变量），拒绝写入
        $result.Error = ('拒绝把 PATH 清空：本次会移除全部 {0} 项，删除后环境变量本身也会消失；请先手动保留至少一项再重试。' -f $result.Removed)
        return $result
    }

    try {
        Set-WinstEnvironmentVariableEx -Name 'Path' -Value (@($plan.Kept) -join ';') -Scope $Scope
        $result.Ok = $true
    } catch {
        $result.Error = $_.Exception.Message
    }
    return $result
}
