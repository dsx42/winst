#Requires -Version 5.1

function Get-RegexCaptureValue {
    <#
    .SYNOPSIS
        按正则从文本提取单个值：命名组优先，其次第 1 捕获组，最后整段匹配。
    .OUTPUTS
        @{ Hit = <bool>; Value = <string> }
    #>
    param(
        [string]$Text,
        [string]$Pattern,
        [string]$GroupName = 'v'
    )

    $result = @{ Hit = $false; Value = '' }
    if ($null -eq $Text -or -not $Text) { return $result }
    if ($null -eq $Pattern -or -not $Pattern) { return $result }

    $m = $null
    try {
        $m = [regex]::Match([string]$Text, $Pattern)
    } catch {
        throw ('正则表达式非法: {0}（{1}）' -f $Pattern, $_.Exception.Message)
    }
    if (-not $m.Success) { return $result }

    if ($GroupName -and $m.Groups[$GroupName].Success) {
        $result.Value = [string]$m.Groups[$GroupName].Value
    } elseif ($m.Groups.Count -gt 1 -and $m.Groups[1].Success) {
        $result.Value = [string]$m.Groups[1].Value
    } else {
        $result.Value = [string]$m.Value
    }
    $result.Hit = $true
    return $result
}
