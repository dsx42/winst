#Requires -Version 5.1

function Test-WinstNumericVersionPrefix {
    <#
    .SYNOPSIS
        判断 prefix 开头的数字段是否是 value 数字段的逐段前缀（「1.2.3」是「1.2.3.1234」的前缀；
        「0.0.1」不是「0.2.3.0」的前缀）。用于 fileVersion 检测里判断两个版本串是否只是「写法省略」。
    .DESCRIPTION
        只比较两边**开头**的点分数字段：`1.8.0_504` 与 `1.8.0.504` 视为「写法省略」，
        `3.71.1` 与 `3.71.1.0` 同理。调用方负责先把「3, 71, 1, 0」这类逗号写法归一成点号
        （见 ConvertTo-WinstFileVersionText）——逗号串在这里只会匹配到第一段 `3`，
        会把「写法不同」误判成「前缀」，从而保留了那段无法识别的原始文本。
    #>
    param([string]$Prefix, [string]$Value)

    if (-not $Prefix -or -not $Value) { return $false }
    $m1 = [regex]::Match($Prefix, '^\s*[vV]?(\d+(?:\.\d+)*)')
    $m2 = [regex]::Match($Value, '^\s*[vV]?(\d+(?:\.\d+)*)')
    if (-not $m1.Success -or -not $m2.Success) { return $false }
    $a = @($m1.Groups[1].Value.Split('.'))
    $b = @($m2.Groups[1].Value.Split('.'))
    if ($a.Count -gt $b.Count) { return $false }
    for ($i = 0; $i -lt $a.Count; $i++) {
        if ([long]$a[$i] -ne [long]$b[$i]) { return $false }
    }
    return $true
}
