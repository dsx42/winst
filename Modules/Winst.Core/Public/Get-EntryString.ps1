#Requires -Version 5.1

function Get-EntryString {
    <#
    .SYNOPSIS
        从字典（hashtable / ordered）或 PSCustomObject 中安全读取字符串字段。
    .DESCRIPTION
        兼容来自默认配置（hashtable）与 ConvertFrom-Json（PSCustomObject）两种形态。
        ConvertFrom-Json 会把 ISO 8601 形状的字符串自动转成 DateTime（如 2026-09-07T00:00:00），
        此处统一还原为 's' 形式，避免读成随区域设置变化的本地化格式。
    #>
    param(
        $Entry,
        [Parameter(Mandatory = $true)]
        [string]$Key
    )

    if ($null -eq $Entry) { return '' }
    if ($Entry -is [System.Collections.IDictionary]) {
        if ($Entry.Contains($Key)) {
            $value = $Entry[$Key]
            if ($null -ne $value) {
                if ($value -is [DateTime]) { return ([DateTime]$value).ToString('s') }
                return [string]$value
            }
        }
        return ''
    }
    $prop = $Entry.PSObject.Properties[$Key]
    if ($prop -and $null -ne $prop.Value) {
        if ($prop.Value -is [DateTime]) { return ([DateTime]$prop.Value).ToString('s') }
        return [string]$prop.Value
    }
    return ''
}
