#Requires -Version 5.1

function Resolve-WinstExternalVersion {
    <#
    .SYNOPSIS
        从独立的 HEAD 响应头或 JSON 接口字段读取版本，JSON 版本数组可过滤和排序。
    #>
    param([hashtable]$Context, $Source, [string]$VersionFrom)

    $uri = (Get-EntryString -Entry $Source -Key 'versionUrl').Trim()
    if (-not $uri) { throw 'source.versionUrl 必填（独立版本地址）' }
    if ($uri -match '\{version(Major|Minor)?\}') { throw 'source.versionUrl 不支持版本占位符' }
    if ($VersionFrom -eq 'header') {
        $value = Get-WinstRemoteHeader -Context $Context -Uri $uri -Name (Get-EntryString -Entry $Source -Key 'versionHeader')
    } else {
        $key = (Get-EntryString -Entry $Source -Key 'versionKey').Trim()
        if (-not $key) { throw 'source.versionKey 必填（JSON 版本字段路径）' }
        $selection = Get-WinstJsonSelectionSpec -Source $Source -Label '独立 JSON 版本来源'
        if ($selection.Error) { throw $selection.Error }
        $text = Invoke-WinstHttpGet -Context $Context -Uri $uri
        try { $json = ConvertFrom-Json -InputObject $text -ErrorAction Stop }
        catch { throw ('独立版本地址返回的内容不是合法 JSON：{0}（{1}）' -f $uri, $_.Exception.Message) }
        if ($null -eq $json) { throw ('独立版本地址未返回可用的 JSON 数据：' + $uri) }
        $field = Get-JsonNodeValue -Node $json -Key $key
        if (-not $field.Ok) { throw ('JSON 接口缺少版本字段：{0}' -f $key) }
        # 字段中的单值或数组成员本身就是版本，先按完整原文过滤，再排序与规范化。
        $selection.VersionKey = '.'
        $pick = Select-WinstJsonVersionItems -Items @($field.Node) -Selection $selection -Label '独立 JSON 版本来源'
        if ($pick.Error) { throw $pick.Error }
        if (@($pick.Items).Count -ne 1) {
            throw ('JSON 版本字段「{0}」必须选出唯一版本，实际有 {1} 个候选；请配置 source.versionFilter / sort' -f $key, @($pick.Items).Count)
        }
        $value = [string]$pick.Items[0]
    }
    $version = Get-NormalizedVersionString -Value $value
    if (-not $version -or -not (Get-WinstVersionFromText -Text $version)) { throw ('独立版本地址没有返回有效版本号：{0}' -f $uri) }
    return $version
}
