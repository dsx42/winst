#Requires -Version 5.1

function Get-VersionBetween {
    <#
    .SYNOPSIS
        取「两个标记之间」的内容作为版本（如 ["version_", "_"] 从文件名里取出 26h1）。
    .OUTPUTS
        @{ Ok; Value; Error }
    #>
    param($Spec, [string]$Text)

    $result = @{ Ok = $false; Value = ''; Error = '' }
    $parts = @($Spec)
    if ($parts.Count -lt 1 -or $parts.Count -gt 2) {
        $result.Error = 'versionBetween 要写成 ["前缀", "后缀"] 两项（后缀可省略）'
        return $result
    }

    $before = ''
    if ($null -ne $parts[0]) { $before = ([string]$parts[0]) }
    $after = ''
    if ($parts.Count -eq 2 -and $null -ne $parts[1]) { $after = ([string]$parts[1]) }
    if (-not $before) {
        $result.Error = 'versionBetween 的前缀不能为空'
        return $result
    }

    $value = ''
    if ($null -ne $Text) { $value = [string]$Text }

    $start = $value.IndexOf($before, [StringComparison]::Ordinal)
    if ($start -lt 0) { return $result }
    $start += $before.Length

    if ($after) {
        $end = $value.IndexOf($after, $start, [StringComparison]::Ordinal)
        if ($end -lt 0) { return $result }
        $value = $value.Substring($start, $end - $start)
    } else {
        $value = $value.Substring($start)
    }

    $result.Value = $value.Trim()
    $result.Ok = $true
    return $result
}
