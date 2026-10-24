#Requires -Version 5.1

function Get-VersionKeyValue {
    <#
    .SYNOPSIS
        从页面内容里按字段名取版本（如 "version":"16.0.20326.20112"）。
    .OUTPUTS
        @{ Ok; Value }
    .DESCRIPTION
        键支持点分（如 app.version），内部按 JSON 的层级顺序匹配；取到的值原样作为版本。
    #>
    param([string]$Text, [string]$Key)

    $result = @{ Ok = $false; Value = '' }
    if (-not $Text -or -not $Key) { return $result }

    $segments = @()
    foreach ($segment in ([string]$Key).Split('.')) {
        if ($segment -and $segment.Trim()) { $segments += $segment.Trim() }
    }
    if ($segments.Count -eq 0) { return $result }

    $pattern = '"' + [regex]::Escape($segments[0]) + '"'
    for ($i = 1; $i -lt $segments.Count; $i++) {
        $pattern += '\s*:\s*\{[^{}]*?"' + [regex]::Escape($segments[$i]) + '"'
    }
    $pattern += '\s*:\s*"(?<v>[^"]*)"'

    $capture = Get-RegexCaptureValue -Text $Text -Pattern $pattern -GroupName 'v'
    if (-not $capture.Hit) { return $result }
    $result.Value = ([string]$capture.Value).Trim()
    $result.Ok = $true
    return $result
}
