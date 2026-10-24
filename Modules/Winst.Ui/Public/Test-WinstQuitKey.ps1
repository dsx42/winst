#Requires -Version 5.1

function Test-WinstQuitKey {
    <#
    .SYNOPSIS
        判断用户输入是不是「退出」（q / Q，不区分大小写）。
    .DESCRIPTION
        调用点的输入有的已经过 Read-WinstAnswerText -Lower 转小写、有的没有，因此这里统一不区分大小写，
        退出键的口径只定义一次（避免各处混用 `-eq 'q'` 与 `-ieq 'q'`）。
    .OUTPUTS
        [bool]
    #>
    param([string]$Text)

    if ($null -eq $Text) { return $false }
    return (([string]$Text).Trim() -ieq 'q')
}
