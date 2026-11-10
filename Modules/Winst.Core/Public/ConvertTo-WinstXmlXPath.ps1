#Requires -Version 5.1

function ConvertTo-WinstXmlXPath {
    <#
    .SYNOPSIS
        将普通点分 XML 字段路径转换为不依赖命名空间前缀的 XPath。
    #>
    param([string]$Key)

    $text = $Key.Trim()
    if (-not $text) { throw 'XML 字段路径不能为空' }
    $segments = $text.Split('.')
    $parts = @()
    for ($i = 0; $i -lt $segments.Count; $i++) {
        $name = $segments[$i]
        $attribute = $name.StartsWith('@')
        if ($attribute) {
            if ($i -ne $segments.Count - 1) { throw ('XML 属性只能写在字段路径末段：' + $text) }
            $name = $name.Substring(1)
        }
        try { $null = [System.Xml.XmlConvert]::VerifyNCName($name) }
        catch { throw ('XML 字段路径的每一段必须是元素名或末段 @属性名：' + $text) }
        $part = "*[local-name()='" + $name + "']"
        if ($attribute) { $part = '@' + $part }
        $parts += $part
    }
    return ($parts -join '/')
}
