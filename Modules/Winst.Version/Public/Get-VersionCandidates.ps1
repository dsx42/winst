#Requires -Version 5.1

function Get-VersionCandidates {
    <#
    .SYNOPSIS
        按版本识别器从文本中收集全部版本候选（去重，保持出现顺序）。
    .OUTPUTS
        @( 版本字符串 )
    #>
    param([string]$Text, [string]$Kind)

    $values = @()
    $pattern = Get-VersionKindPattern -Kind $Kind
    if (-not $pattern) { return $values }
    if (-not $Text) { return $values }
    return @(Get-DistinctValues -Values @(Get-RegexCaptureValues -Text $Text -Pattern $pattern -GroupName 'v'))
}
