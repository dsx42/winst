#Requires -Version 5.1

function Get-WinstUpgradeHint {
    <#
    .SYNOPSIS
        生成「可更新」提示文本（如 `↑ 可更新到 2.0（来自 local）`）；无需更新时返回空串。
    .DESCRIPTION
        版本比较：软件源里的最高可用版本高于本机已装版本时给出提示。
        `-WithSource` 时一并标出这个新版本来自哪个软件源（已装软件列表 / 详情用）。
    #>
    param($Row, [string]$InstalledVersion, [switch]$WithSource)

    if (-not $InstalledVersion) { return '' }
    $candidate = Get-WinstRowBestEntry -Row $Row
    if (-not $candidate) { return '' }
    if ((Compare-WinstVersion -A ([string]$candidate['Version']) -B $InstalledVersion) -gt 0) {
        if ($WithSource -and $candidate['Source']) {
            return ('↑ 可更新到 {0}（来自 {1}）' -f [string]$candidate['Version'], [string]$candidate['Source'])
        }
        return ('↑ 可更新到 {0}' -f [string]$candidate['Version'])
    }
    return ''
}
