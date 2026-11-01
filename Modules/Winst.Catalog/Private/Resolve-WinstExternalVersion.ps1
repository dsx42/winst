#Requires -Version 5.1

function Resolve-WinstExternalVersion {
    <#
    .SYNOPSIS
        从独立的 HEAD 响应头或 JSON 接口字段读取版本。
    #>
    param([hashtable]$Context, $Source, [string]$VersionFrom)

    $uri = (Get-EntryString -Entry $Source -Key 'versionUrl').Trim()
    if (-not $uri) { throw 'source.versionUrl 必填（独立版本地址）' }
    if ($uri -match '\{version(Major)?\}') { throw 'source.versionUrl 不支持版本占位符' }
    if ($VersionFrom -eq 'header') {
        $value = Get-WinstRemoteHeader -Context $Context -Uri $uri -Name (Get-EntryString -Entry $Source -Key 'versionHeader')
    } else {
        $key = (Get-EntryString -Entry $Source -Key 'versionKey').Trim()
        if (-not $key) { throw 'source.versionKey 必填（JSON 版本字段路径）' }
        $text = Invoke-WinstHttpGet -Context $Context -Uri $uri
        $json = ConvertFrom-Json -InputObject $text -ErrorAction Stop
        $field = Get-JsonNodeValue -Node $json -Key $key
        if (-not $field.Ok) { throw ('JSON 接口缺少版本字段：{0}' -f $key) }
        $value = [string]$field.Node
    }
    $version = Get-NormalizedVersionString -Value $value
    if (-not $version -or -not (Get-WinstVersionFromText -Text $version)) { throw ('独立版本地址没有返回有效版本号：{0}' -f $uri) }
    return $version
}