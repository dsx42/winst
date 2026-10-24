#Requires -Version 5.1

function Get-WinstVersionTokens {
    <#
    .SYNOPSIS
        把版本号按「数字串 / 字母串」切段（分隔符丢弃），供语义化比较使用。
    #>
    param([string]$Value)

    $tokens = New-Object 'System.Collections.Generic.List[string]'
    # StringBuilder：字符串 `+=` 每次都新建实例（O(n²)），而版本比较在排序里会被调用 O(n log n) 次
    $current = New-Object 'System.Text.StringBuilder'
    $currentKind = ''
    foreach ($ch in ([string]$Value).ToCharArray()) {
        $kind = 'sep'
        if ([char]::IsDigit($ch)) { $kind = 'digit' }
        elseif ([char]::IsLetter($ch)) { $kind = 'letter' }
        if ($kind -eq 'sep') {
            if ($current.Length -gt 0) {
                $tokens.Add($current.ToString())
                $null = $current.Clear()
                $currentKind = ''
            }
            continue
        }
        if ($current.Length -gt 0 -and $kind -ne $currentKind) {
            $tokens.Add($current.ToString())
            $null = $current.Clear()
        }
        $null = $current.Append($ch)
        $currentKind = $kind
    }
    if ($current.Length -gt 0) { $tokens.Add($current.ToString()) }
    return $tokens.ToArray()
}
