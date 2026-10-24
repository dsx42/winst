#Requires -Version 5.1

function Copy-WinstObjectShallow {
    <#
    .SYNOPSIS
        浅拷贝字典 / PSCustomObject 为 ordered hashtable（保留全部字段与字段顺序）。
    .DESCRIPTION
        用于「保留上次成功结果」时给旧条目追加备注：解析锁条目从 JSON 读回是 PSCustomObject，
        直接改属性会污染缓存对象，故先拷贝再改。
    #>
    param($InputObject)

    if ($null -eq $InputObject) { return $null }
    $copy = [ordered]@{}
    if ($InputObject -is [System.Collections.IDictionary]) {
        foreach ($key in @($InputObject.Keys)) { $copy[[string]$key] = $InputObject[$key] }
    } else {
        foreach ($prop in $InputObject.PSObject.Properties) { $copy[$prop.Name] = $prop.Value }
    }
    return $copy
}
