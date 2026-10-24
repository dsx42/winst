#Requires -Version 5.1

function Get-WinstDevToolsStringField {
    <#
    .SYNOPSIS
        从一条 DevTools 消息里取第一个 "名字":"值" 的字符串值（不做完整 JSON 解析）。
    .DESCRIPTION
        消息洪流里绝大多数事件我们只要一个字段（下载地址 / 请求地址），整条 ConvertFrom-Json 太慢——
        读得慢会让浏览器的消息队列堆积、渲染进程被拖住（页面 JS 一多 Runtime.evaluate 就不回应），
        所以先用字符串定位、只对命中的那一个值做一次反转义。
    #>
    param([string]$Text, [string]$Name)

    if (-not $Text -or -not $Name) { return '' }
    $pattern = '"' + [regex]::Escape($Name) + '":"((?:[^"\\]|\\.)*)"'
    $match = [regex]::Match($Text, $pattern)
    if (-not $match.Success) { return '' }

    $value = $match.Groups[1].Value
    try { return [string]($('"' + $value + '"') | ConvertFrom-Json) } catch { return $value }
}
