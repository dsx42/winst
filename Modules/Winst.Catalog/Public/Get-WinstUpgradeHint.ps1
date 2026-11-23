#Requires -Version 5.1

function Get-WinstUpgradeHint {
    <#
    .SYNOPSIS
        生成「可更新」提示文本（如 `↑ 可更新到 2.0`）；无需更新时返回空串。
    .DESCRIPTION
        版本比较：软件源里的最高可用版本高于本机已装版本时给出提示。
    #>
    param($Row, [string]$InstalledVersion)

    if (-not $InstalledVersion) { return '' }
    $candidate = Get-WinstRowBestSourceEntry -Row $Row
    if (-not $candidate) { return '' }
    if ((Compare-WinstVersion -A ([string]$candidate['Version']) -B $InstalledVersion) -gt 0) {
        return ('↑ 可更新到 {0}' -f [string]$candidate['Version'])
    }
    return ''
}
