#Requires -Version 5.1

function Get-RegexCaptureValues {
    <#
    .SYNOPSIS
        从版本及链接识别器的第一个捕获组提取非空匹配。
    #>
    param(
        [string]$Text,
        [string]$Pattern
    )

    $values = New-Object 'System.Collections.Generic.List[string]'
    if (-not $Text) { return $values.ToArray() }
    if (-not $Pattern) { return $values.ToArray() }

    try {
        foreach ($m in [regex]::Matches($Text, $Pattern, [Text.RegularExpressions.RegexOptions]::None, [timespan]::FromSeconds(1))) {
            $value = $m.Groups[1].Value.Trim()
            if ($value) { $values.Add($value) }
        }
    } catch { throw ('正则提取失败或超时: {0}（{1}）' -f $Pattern, $_.Exception.Message) }
    return $values.ToArray()
}
