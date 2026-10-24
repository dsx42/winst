#Requires -Version 5.1

function Format-WinstCommandArgument {
    <#
    .SYNOPSIS
        按 Windows CommandLineToArgvW 规则把单个参数序列化为命令行片段。
    .DESCRIPTION
        PowerShell 5.1 的 ProcessStartInfo 没有 ArgumentList 属性、Start-Process -ArgumentList 会重新拼成字符串，
        因此必须自行处理嵌入引号、引号前反斜杠与结尾反斜杠。
    .OUTPUTS
        [string]
    #>
    param([string]$Value)

    if ($null -eq $Value) { return '""' }
    $text = [string]$Value
    if ($text -eq '') { return '""' }
    if ($text -notmatch '[\s"]') { return $text }

    $builder = New-Object 'System.Text.StringBuilder'
    $null = $builder.Append('"')
    $slashes = 0
    foreach ($ch in $text.ToCharArray()) {
        if ($ch -eq '\') {
            $slashes++
            continue
        }
        if ($ch -eq '"') {
            # 引号前的反斜杠要翻倍，另加一个反斜杠转义引号本身。
            for ($i = 0; $i -lt (($slashes * 2) + 1); $i++) { $null = $builder.Append('\') }
            $null = $builder.Append('"')
            $slashes = 0
            continue
        }
        for ($i = 0; $i -lt $slashes; $i++) { $null = $builder.Append('\') }
        $slashes = 0
        $null = $builder.Append($ch)
    }
    # 结尾反斜杠位于闭合引号前，必须翻倍，否则会转义闭合引号。
    for ($i = 0; $i -lt ($slashes * 2); $i++) { $null = $builder.Append('\') }
    $null = $builder.Append('"')
    return $builder.ToString()
}
