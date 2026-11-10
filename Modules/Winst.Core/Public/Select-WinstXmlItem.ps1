#Requires -Version 5.1

function Select-WinstXmlItem {
    <#
    .SYNOPSIS
        按普通字段路径和等值条件选择唯一 XML 节点。
    #>
    param([System.Xml.XmlNode]$Node, [string]$Key = '', $Match = $null, [string]$Label = '记录')

    if ($null -eq $Node) { throw ('XML ' + $Label + '的起点为空') }
    if ($null -ne $Match -and $Match -isnot [System.Collections.IDictionary] -and $Match -isnot [pscustomobject]) {
        throw ('XML ' + $Label + '的 match 必须是对象')
    }
    $conditions = @()
    foreach ($pair in @(Get-WinstEntryPairs -Entry $Match)) {
        if ($pair[1] -isnot [string]) { throw ('XML ' + $Label + '的 match 条件值必须是字符串：' + [string]$pair[0]) }
        $conditions += @{
            Key = [string]$pair[0]
            XPath = ConvertTo-WinstXmlXPath -Key ([string]$pair[0])
            Value = $pair[1].Trim()
        }
    }
    $candidates = New-Object 'System.Collections.Generic.List[System.Xml.XmlNode]'
    if ($Key.Trim()) {
        $xpath = ConvertTo-WinstXmlXPath -Key $Key
        foreach ($candidate in $Node.SelectNodes($xpath)) { $candidates.Add($candidate) }
    } else {
        $candidates.Add($Node)
    }
    $chosen = $null
    foreach ($candidate in $candidates) {
        $matches = $true
        foreach ($condition in $conditions) {
            $values = $candidate.SelectNodes($condition.XPath)
            if ($values.Count -gt 1) {
                throw ('XML {0}的 match 字段匹配到多个节点：{1}' -f $Label, $condition.Key)
            }
            if ($values.Count -eq 0 -or $values.Item(0).CreateNavigator().Value.Trim() -cne $condition.Value) {
                $matches = $false
                break
            }
        }
        if (-not $matches) { continue }
        if ($null -ne $chosen) { throw ('XML ' + $Label + '匹配到多个节点，请补充 match 条件') }
        $chosen = $candidate
    }
    if ($null -eq $chosen) { throw ('XML ' + $Label + '没有匹配节点') }
    return ,$chosen
}
