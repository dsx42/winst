#Requires -Version 5.1

function Get-RegexCaptureValues {
    <#
    .SYNOPSIS
        按正则从文本提取全部匹配（命名组优先，其次第 1 捕获组，最后整段匹配）。
    #>
    param(
        [string]$Text,
        [string]$Pattern,
        [string]$GroupName = 'v'
    )

    $values = New-Object 'System.Collections.Generic.List[string]'
    if (-not $Text) { return $values.ToArray() }
    if (-not $Pattern) { return $values.ToArray() }

    try {
        foreach ($m in [regex]::Matches($Text, $Pattern, [Text.RegularExpressions.RegexOptions]::None, [timespan]::FromSeconds(1))) {
            $value = [string]$m.Value
            if ($GroupName -and $m.Groups[$GroupName].Success) {
                $value = [string]$m.Groups[$GroupName].Value
            } elseif ($m.Groups.Count -gt 1 -and $m.Groups[1].Success) {
                $value = [string]$m.Groups[1].Value
            }
            if ($value -and $value.Trim()) { $values.Add($value.Trim()) }
        }
    } catch { throw ('正则提取失败或超时: {0}（{1}）' -f $Pattern, $_.Exception.Message) }
    return $values.ToArray()
}
