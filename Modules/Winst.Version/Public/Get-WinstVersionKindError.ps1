#Requires -Version 5.1

function Get-WinstVersionKindError {
    <#
    .SYNOPSIS
        校验版本识别器关键字：认识返回空串，不认识返回可直接落进 Error 的提示。
    .DESCRIPTION
        listing / page / json / magnet 等解析器与配套文件版本解析共用这套判断与文案，
        统一到这里，新增识别器时只需改 Get-VersionKindPattern / Get-VersionKindList。
    #>
    param([string]$Kind)

    $k = ''
    if ($Kind) { $k = ([string]$Kind).Trim() }
    if (-not $k) { return '' }
    if (Get-VersionKindPattern -Kind $k) { return '' }
    return ('不认识的版本识别器「{0}」；可用 {1}' -f $k, ((Get-VersionKindList) -join '、'))
}
