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

    $values = @()
    if ($null -eq $Text -or -not $Text) { return $values }
    if ($null -eq $Pattern -or -not $Pattern) { return $values }

    foreach ($m in [regex]::Matches([string]$Text, $Pattern)) {
        $value = [string]$m.Value
        if ($GroupName -and $m.Groups[$GroupName].Success) {
            $value = [string]$m.Groups[$GroupName].Value
        } elseif ($m.Groups.Count -gt 1 -and $m.Groups[1].Success) {
            $value = [string]$m.Groups[1].Value
        }
        if ($value -and $value.Trim()) { $values += $value.Trim() }
    }
    return $values
}
