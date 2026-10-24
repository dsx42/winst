#Requires -Version 5.1

function Test-WinstResolvedAtStale {
    <#
    .SYNOPSIS
        判断单个软件的版本信息（per-app resolvedAt）是否超过有效期。
    .DESCRIPTION
        没有记录（从未解析过）或时间戳无法解析视为过期，首次按需刷新补齐；
        `manifestTTLHours` <= 0 视为每次都刷新。
    #>
    param([string]$ResolvedAt, [datetime]$Now, [int]$TtlHours)

    if (-not $ResolvedAt) { return $true }
    $stamp = [datetime]::MinValue
    if (-not [datetime]::TryParse([string]$ResolvedAt, [ref]$stamp)) { return $true }
    if ($TtlHours -le 0) { return $true }
    return (($Now - $stamp).TotalHours -ge $TtlHours)
}
