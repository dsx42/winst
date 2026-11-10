#Requires -Version 5.1

function Get-WinstXmlValue {
    <#
    .SYNOPSIS
        按 XPath 读取唯一节点或字符串表达式的非空文本。
    #>
    param([System.Xml.XmlNode]$Node, [string]$XPath)

    if ($null -eq $Node) { throw 'XML 取值节点为空' }
    $expression = $XPath.Trim()
    if (-not $expression) { throw 'XML XPath 不能为空' }
    try {
        $value = $Node.CreateNavigator().Evaluate($expression)
    } catch {
        throw ('XML XPath 无法解析「{0}」：{1}' -f $expression, $_.Exception.Message)
    }
    if ($value -is [System.Xml.XPath.XPathNodeIterator]) {
        if (-not $value.MoveNext()) { throw ('XML XPath 没有匹配节点：' + $expression) }
        $text = $value.Current.Value
        if ($value.MoveNext()) { throw ('XML XPath 匹配到多个节点：' + $expression) }
    } elseif ($value -is [string]) {
        $text = $value
    } else {
        throw ('XML XPath 必须返回唯一节点或字符串：' + $expression)
    }
    $text = $text.Trim()
    if (-not $text) { throw ('XML XPath 取到空值：' + $expression) }
    return $text
}
