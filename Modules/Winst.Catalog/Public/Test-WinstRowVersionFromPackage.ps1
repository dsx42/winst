#Requires -Version 5.1

function Test-WinstRowVersionFromPackage {
    <#
    .SYNOPSIS
        这一行的版本号是否「只能等主包取到才知道」。
    .DESCRIPTION
        有明确远端版本时按版本比较；否则以实际选中计划的 versionFromPackage 为准，
        缓存包版本与同一计划的 remoteFresh 一起供后续判定使用。
    .OUTPUTS
        [bool]
    #>
    param($Row)

    if (-not $Row) { return $false }
    if (Get-WinstRowBestSourceEntry -Row $Row) { return $false }
    $chosen = Get-WinstRowBestPlanEntry -Row $Row
    return [bool]($chosen -and (Get-EntryBool -Entry $chosen['Plan'] -Key 'versionFromPackage'))
}
