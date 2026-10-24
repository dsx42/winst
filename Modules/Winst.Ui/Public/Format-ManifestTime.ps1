#Requires -Version 5.1

function Format-ManifestTime {
    <#
    .SYNOPSIS
        把 sidecar 中的 ISO 8601 拉取时间格式化为「yyyy-MM-dd HH:mm:ss」用于展示。
    .DESCRIPTION
        存储仍为 ISO 8601，仅展示时转换；
        解析失败（旧数据 / 手工修改）时原样返回。
    #>
    param([string]$Value)

    if (-not $Value -or -not $Value.Trim()) { return '' }
    $text = $Value.Trim()
    $parsed = [DateTime]::MinValue
    if ([DateTime]::TryParse($text, [ref]$parsed)) {
        return $parsed.ToString('yyyy-MM-dd HH:mm:ss')
    }
    return $text
}
