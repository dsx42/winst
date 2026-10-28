#Requires -Version 5.1

function Read-WinstConfirm {
    <#
    .SYNOPSIS
        统一确认询问：`y` / `yes` 为同意（不区分大小写），空输入（直接回车）按 -Default，其它文本一律算不同意。
    .DESCRIPTION
        确认提示的「回车算什么」只在这里定义一处，避免各处自己解析出不同口径：
        - `(y/N)` → -Default 'n'：回车 = 不做任何改动；
        - `(Y/n)` → -Default 'y'：回车 = 执行，**调用方必须在提示里写清后果**（如「n = 跳过这一个」）。
        非交互场景（`--yes` / 输入被重定向 / `--dry-run`）由调用方先判断、通常根本不调用本函数
        （各处原有的 `-not $Yes` 守卫保持不动）；这里只在这个宿主读不到键盘输入时按 -Default 兜底，
        不会把默认值偷偷改成「是」。
    .OUTPUTS
        [bool]
    #>
    param(
        [Parameter(Mandatory = $true)][string]$Prompt,
        [ValidateSet('y', 'n')][string]$Default = 'n'
    )

    $raw = $null
    try {
        $raw = Read-Host $Prompt
    } catch {
        return ($Default -eq 'y')
    }

    $text = ''
    if ($null -ne $raw) { $text = ([string]$raw).Trim() }
    if (-not $text) { return ($Default -eq 'y') }
    return [bool]($text -match '^(?i)y(es)?$')
}
