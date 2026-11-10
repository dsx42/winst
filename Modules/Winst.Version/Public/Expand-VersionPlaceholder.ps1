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
    $majorText = ''
    if ($versionText) { $majorText = ($versionText -split '\.')[0] }
    $minorText = ''
    if ($text.Contains('{versionMinor}')) {
        $parts = @((Get-NormalizedVersionString -Value $versionText) -split '\.')
        if ($parts.Count -lt 2 -or -not $parts[1]) { throw '{versionMinor} 需要至少两段的版本号，不能省略次版本号' }
        $minorText = $parts[1]
    }

    # 替换串中的 $ 需转义为 $$，避免被当作正则替换引用。
    $versionEscaped = $versionText.Replace('$', '$$')
    $majorEscaped = $majorText.Replace('$', '$$')
    $minorEscaped = $minorText.Replace('$', '$$')
    $text = [regex]::Replace($text, '\{versionMajor\}', $majorEscaped)
    $text = [regex]::Replace($text, '\{versionMinor\}', $minorEscaped)
    return [regex]::Replace($text, '\{version\}', $versionEscaped)
}
