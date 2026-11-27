#Requires -Version 5.1

function Test-WinstQuitKey {
    <#
    .SYNOPSIS
        判断用户输入是不是「退出」（q / Q，不区分大小写）。
    .OUTPUTS
        [bool]
    #>
    param([string]$Text)

    return ($Text.Trim() -ieq 'q')
}
