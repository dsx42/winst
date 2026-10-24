#Requires -Version 5.1

function Get-WinstGithubTagVersion {
    <#
    .SYNOPSIS
        把发布 tag 转成可比较的版本号（先去掉 source.releaseTag 前缀，再规范化）。
    #>
    param([string]$Tag, [string]$ReleaseTagPrefix = '')

    $text = ''
    if ($null -ne $Tag) { $text = ([string]$Tag).Trim() }
    if (-not $text) { return '' }
    if ($ReleaseTagPrefix -and $text.StartsWith($ReleaseTagPrefix, [StringComparison]::OrdinalIgnoreCase)) {
        $text = $text.Substring($ReleaseTagPrefix.Length)
    }
    return (Get-NormalizedVersionString -Value $text)
}
