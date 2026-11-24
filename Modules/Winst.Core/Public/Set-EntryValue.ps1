#Requires -Version 5.1

function Set-EntryValue {
    <#
    .SYNOPSIS
        写入字典（hashtable / ordered）或 PSCustomObject 的字段——Get-EntryValue 的写入版。
    .DESCRIPTION
        解析锁里的条目读自 JSON（ConvertFrom-Json 得到 PSCustomObject，既不能用 ['key'] 读取、
        也不能用 ['key'] = 赋值，会报「Unable to index into an object of type PSObject」），
        而解析器实时构造的条目是哈希表；安装流程回写版本号时统一走这里。
    #>
    param(
        $Entry,
        [Parameter(Mandatory = $true)]
        [string]$Key,
        $Value
    )

    if ($null -eq $Entry) { return }
    if ($Entry -is [System.Collections.IDictionary]) {
        $Entry[$Key] = $Value
        return
    }
    $prop = $Entry.PSObject.Properties[$Key]
    if ($prop) {
        if (-not $prop.IsSettable) { return }
        $prop.Value = $Value
        return
    }
    try {
        $Entry | Add-Member -NotePropertyName $Key -NotePropertyValue $Value -Force -ErrorAction Stop
    } catch {
    }
}
