#Requires -Version 5.1

function Expand-VersionPlaceholder {
    <#
    .SYNOPSIS
        把文本中的 {version} / {versionMajor} 占位符替换为具体版本号 / 版本号主段（第一段）。
    .DESCRIPTION
        {versionMajor} = 版本号按「.」切分后的第一段（如 2.57.1 → 2）——SourceForge 这类按大版本
        分目录的源用它拼目录名（如 KeePass 翻译包的 files/Translations%20{versionMajor}.x/<version>/…）。
    #>
    param([string]$Text, [string]$Version)

    if ($null -eq $Text) { return '' }
    $text = [string]$Text
    if (-not [regex]::IsMatch($text, '\{version(Major)?\}')) { return $text }

    $versionText = ''
    if ($null -ne $Version) { $versionText = [string]$Version }
    $majorText = ''
    if ($versionText) { $majorText = ($versionText -split '\.')[0] }

    # 替换串中的 $ 需转义为 $$，避免被当作正则替换引用
    $versionEscaped = $versionText.Replace('$', '$$')
    $majorEscaped = $majorText.Replace('$', '$$')
    # \{version\} 不会命中 {versionMajor}（要求右花括号紧跟 version），两步替换互不干扰
    $text = [regex]::Replace($text, '\{versionMajor\}', $majorEscaped)
    return [regex]::Replace($text, '\{version\}', $versionEscaped)
}
