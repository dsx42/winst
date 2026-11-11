#Requires -Version 5.1

function Read-WinstConfirm {
    <#
    .SYNOPSIS
        统一确认询问：`y` / `yes` 为同意（不区分大小写），空输入（直接回车）按 -Default，其它文本一律算不同意。
    .DESCRIPTION
        确认提示的「回车算什么」只在这里定义一处，避免各处自己解析出不同口径：
        - `(y/N)` → -Default 'n'：回车 = 不做任何改动；
        - `(Y/n)` → -Default 'y'：回车 = 执行，**调用方必须在提示里写清后果**（如「n = 跳过这一个」）。
        重定向、EOF 或读取异常一律取消；默认值只适用于交互终端的真实回车。
    .OUTPUTS
        [bool]
    #>
    param(
        [Parameter(Mandatory = $true)][string]$Prompt,
        [ValidateSet('y', 'n')][string]$Default = 'n'
    )

    $text = Read-WinstAnswerText -Prompt $Prompt
    if ($null -eq $text) { return $false }
    if (-not $text) { return ($Default -eq 'y') }
    return [bool]($text -match '^(?i)y(es)?$')
}
