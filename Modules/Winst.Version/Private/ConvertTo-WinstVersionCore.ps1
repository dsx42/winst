#Requires -Version 5.1

function ConvertTo-WinstVersionCore {
    <#
    .SYNOPSIS
        版本号规范化：去首尾空白与单个 v / V 前缀（Compare-WinstVersion 的内部步骤，提为函数避免每次比较都新建 scriptblock）。
    #>
    param([string]$Value)

    $s = ''
    if ($null -ne $Value) { $s = ([string]$Value).Trim() }
    if ($s.Length -gt 1 -and ($s[0] -eq 'v' -or $s[0] -eq 'V')) { $s = $s.Substring(1) }
    return $s.Trim()
}
