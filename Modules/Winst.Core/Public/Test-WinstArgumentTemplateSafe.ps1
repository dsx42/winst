#Requires -Version 5.1

function Test-WinstArgumentTemplateSafe {
    <#
    .SYNOPSIS
        校验完整安装参数模板：允许合法双引号，只拒绝控制字符与未闭合引号。
    #>
    param([string]$Value)

    if ($null -eq $Value) { return $true }
    $text = [string]$Value
    if ($text -match '[\x00-\x1F]') { return $false }
    return (-not (Get-WinstCommandLineQuoteState -Text $text))
}
