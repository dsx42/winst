#Requires -Version 5.1

function Expand-VersionPlaceholder {
    <#
    .SYNOPSIS
        把文本中的 {version} / {versionMajor} / {versionMinor} 替换为完整版本、第一段或第二段。
    .DESCRIPTION
        主段沿用版本原文的第一段；次段取规范化版本按「.」切分后的第二段，缺少次段时明确报错。
    #>
    param([string]$Text, [string]$Version)

    if ($null -eq $Text) { return '' }
    $text = [string]$Text
    if (-not [regex]::IsMatch($text, '\{version(Major|Minor)?\}')) { return $text }

    $versionText = ''
    if ($null -ne $Version) { $versionText = [string]$Version }
    if (-not $versionText) { throw '模板使用了版本占位符，但当前版本未知，无法展开' }
    $majorText = ''
    if ($versionText) { $majorText = ($versionText -split '\.')[0] }
    $minorText = ''
    if ($text.Contains('{versionMinor}')) {
        $parts = @((Get-NormalizedVersionString -Value $versionText) -split '\.')
        if ($parts.Count -lt 2 -or -not $parts[1]) { throw '{versionMinor} 需要至少两段的版本号，不能省略次版本号' }
        $minorText = $parts[1]
    }

    return [regex]::Replace($text, '\{version(Major|Minor)?\}', [System.Text.RegularExpressions.MatchEvaluator]{
        param($match)
        switch -CaseSensitive ($match.Value) {
            '{versionMajor}' { return $majorText }
            '{versionMinor}' { return $minorText }
            default { return $versionText }
        }
    })
}
