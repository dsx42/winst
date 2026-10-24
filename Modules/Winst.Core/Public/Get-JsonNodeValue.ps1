#Requires -Version 5.1

function Get-JsonNodeValue {
    <#
    .SYNOPSIS
        按点分字段名从 JSON 对象里取值（如 downloads.windowsZip.link；数组下标写数字段；
        键名本身含点时用单引号包住该段，见 Get-JsonKeySegments）。
    .OUTPUTS
        @{ Ok; Node; Text }
    .DESCRIPTION
        json 接口源与 jsonFile 版本检测共用：逐段下行，支持嵌套对象（PSCustomObject /
        字典）与数组下标（如 products.0.url）；取到的标量按 ConvertTo-WinstTextValue 规范化为文本。
        任一段取不到即 Ok = $false，由调用方决定怎么报错。
    #>
    param($Node, [string]$Key)

    $result = @{ Ok = $false; Node = $null; Text = '' }
    if ($null -eq $Node) { return $result }
    if (-not $Key -or -not $Key.Trim()) { return $result }

    $current = $Node
    foreach ($segment in @(Get-JsonKeySegments -Key $Key)) {
        $name = ''
        if ($null -ne $segment) { $name = ([string]$segment).Trim() }
        if (-not $name) { continue }
        if ($null -eq $current) { return $result }

        if ($current -is [System.Array]) {
            $index = -1
            if (-not [int]::TryParse($name, [ref]$index)) { return $result }
            if ($index -lt 0 -or $index -ge @($current).Count) { return $result }
            $current = @($current)[$index]
            continue
        }
        if ($current -is [System.Collections.IDictionary]) {
            if (-not $current.Contains($name)) { return $result }
            $current = $current[$name]
            continue
        }
        if ($current -is [string] -or $current -is [ValueType]) { return $result }

        $prop = $current.PSObject.Properties[$name]
        if (-not $prop) { return $result }
        $current = $prop.Value
    }

    if ($null -eq $current) { return $result }
    $result.Node = $current
    $result.Text = ConvertTo-WinstTextValue -Value $current
    $result.Ok = $true
    return $result
}
