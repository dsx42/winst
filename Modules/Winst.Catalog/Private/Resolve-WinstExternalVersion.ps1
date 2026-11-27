#Requires -Version 5.1

function Resolve-WinstExternalVersion {
    <#
    .SYNOPSIS
        从独立的 HEAD 响应头或 JSON / YAML 接口字段读取版本，版本数组可过滤和排序。
    #>
    param([hashtable]$Context, $Source, [string]$VersionFrom)

    $uri = (Get-EntryString -Entry $Source -Key 'versionUrl').Trim()
    if (-not $uri) { throw 'source.versionUrl 必填（独立版本地址）' }
    if ($uri -match '\{version(Major|Minor)?\}') { throw 'source.versionUrl 不支持版本占位符' }
    Assert-WinstHttpUrl -Url $uri -Label 'source.versionUrl'
    if ($VersionFrom -eq 'header') {
        $value = Get-WinstRemoteHeader -Context $Context -Uri $uri -Name (Get-EntryString -Entry $Source -Key 'versionHeader')
    } else {
        $key = (Get-EntryString -Entry $Source -Key 'versionKey').Trim()
        if (-not $key) { throw 'source.versionKey 必填（接口版本字段路径）' }
        $selection = Get-WinstJsonSelectionSpec -Source $Source -Label '独立接口版本来源'
        if ($selection.Error) { throw $selection.Error }
        if ($VersionFrom -eq 'yaml') {
            $data = Read-WinstYamlSourceResponse -Context $Context -ApiUrl $uri
        } else {
            $data = Read-WinstJsonSourceResponse -Context $Context -ApiUrl $uri
        }
        $field = Get-JsonNodeValue -Node $data -Key $key
        if (-not $field.Ok) { throw ('接口缺少版本字段：{0}' -f $key) }
        if ($VersionFrom -eq 'yaml' -and $field.Node -isnot [string]) {
            throw ('接口 {0} 的版本字段「{1}」必须指向文本标量' -f $uri, $key)
        }
        # 字段中的单值或数组成员本身就是版本，先按完整原文过滤，再排序与规范化。
        $selection.VersionKey = '.'
        $pick = Select-WinstJsonVersionItems -Items @($field.Node) -Selection $selection -Label '独立接口版本来源'
        if ($pick.Error) { throw $pick.Error }
        if (@($pick.Items).Count -ne 1) {
            throw ('版本字段「{0}」必须选出唯一版本，实际有 {1} 个候选；请配置 source.versionFilter / sort' -f $key, @($pick.Items).Count)
        }
        $value = [string]$pick.Items[0]
    }
    $version = Get-NormalizedVersionString -Value $value
    if (-not $version -or -not (Get-WinstVersionFromText -Text $version)) { throw ('独立版本地址没有返回有效版本号：{0}' -f $uri) }
    return $version
}
