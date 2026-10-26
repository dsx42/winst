#Requires -Version 5.1

function Find-WinstRecordsForVersion {
    <#
    .SYNOPSIS
        在系统安装记录里找出**显示名指向这个版本**的记录。
    .DESCRIPTION
        检测到的版本号可能比记录里的显示名更细（`10.0.13.50000` vs `... 10.0.13 (x64)`），
        也可能更粗。判定按「数字段逐段相等、只允许差最后一段」比较，见 Test-WinstNameContainsVersion：
        这样 `10.0.13` 不会匹配到 `10.0.14`，也不会匹配到 `10.0.130`。
    .OUTPUTS
        [object[]]：命中的卸载记录；无匹配时返回空数组
    #>
    param($Plan, [string]$Version)

    $text = ([string]$Version).Trim()
    if (-not $text) { return @() }
    $hits = @(Get-WinstRegistryEntriesForPlan -Plan $Plan -InstallDir '')
    if ($hits.Count -eq 0) { return @() }

    $matched = @()
    foreach ($hit in $hits) {
        if (-not (Test-WinstNameContainsVersion -Text ([string]$hit['DisplayName']) -Version $text)) { continue }
        $matched += $hit
    }
    return $matched
}
