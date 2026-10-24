#Requires -Version 5.1

function ConvertTo-WinstSemVer {
    <#
    .SYNOPSIS
        解析严格 SemVer 2.0.0；无法解析时返回 Valid = false，交由宽松版本比较兜底。
    #>
    param([string]$Value)

    $result = @{ Valid = $false; Major = ''; Minor = ''; Patch = ''; PreRelease = @() }
    $text = ConvertTo-WinstVersionCore -Value $Value
    $match = [regex]::Match($text, '^([0-9]+)\.([0-9]+)\.([0-9]+)(?:-([0-9A-Za-z-]+(?:\.[0-9A-Za-z-]+)*))?(?:\+[0-9A-Za-z-]+(?:\.[0-9A-Za-z-]+)*)?$')
    if (-not $match.Success) { return $result }

    $core = @($match.Groups[1].Value, $match.Groups[2].Value, $match.Groups[3].Value)
    foreach ($part in $core) {
        if ($part.Length -gt 1 -and $part.StartsWith('0')) { return $result }
    }

    $pre = @()
    if ($match.Groups[4].Success) {
        $pre = @($match.Groups[4].Value.Split('.'))
        foreach ($identifier in $pre) {
            if ($identifier -match '^[0-9]+$' -and $identifier.Length -gt 1 -and $identifier.StartsWith('0')) {
                return $result
            }
        }
    }

    $result.Valid = $true
    $result.Major = $core[0]
    $result.Minor = $core[1]
    $result.Patch = $core[2]
    $result.PreRelease = @($pre)
    return $result
}
