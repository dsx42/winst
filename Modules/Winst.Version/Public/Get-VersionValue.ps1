#Requires -Version 5.1

function Get-VersionValue {
    <#
    .SYNOPSIS
        按版本识别器从文本中取第一个版本；未命中返回空串。
    #>
    param([string]$Text, [string]$Kind)

    $pattern = Get-VersionKindPattern -Kind $Kind
    if (-not $pattern) { return '' }
    $capture = Get-RegexCaptureValue -Text $Text -Pattern $pattern -GroupName 'v'
    if ($capture.Hit) { return ([string]$capture.Value).Trim() }
    return ''
}
