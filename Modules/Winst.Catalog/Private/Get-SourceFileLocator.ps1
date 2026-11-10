#Requires -Version 5.1

function Get-SourceFileLocator {
    <#
    .SYNOPSIS
        读取 files[] 条目的定位方式：url、file、接口的 urlKey 或 XML 的 urlXPath。
    .OUTPUTS
        @{ Url; File; UrlKey; UrlXPath; Error }
    .DESCRIPTION
        定位方式互斥；json 源的 urlKey 可与 file 组合：
          url    —— 完整地址或地址模板（支持 {version} / {versionMajor} / {versionMinor} / {tag}）；github 源上也可以只写文件名；
          file   —— 文件名匹配规则，用于文件名不能由版本推出的项目；
          urlKey —— json / xml 源专属：接口条目里存放下载地址的字段名（如 url / downloads.windowsZip.link），
                    可与 file 组合——用文件名规则在多个候选条目里挑出要下载的那一个。
          urlXPath —— xml 源专属：相对于选中记录读取下载地址。
    #>
    param($Item, [string]$Kind = '')

    $url = (Get-EntryString -Entry $Item -Key 'url').Trim()
    $pattern = (Get-EntryString -Entry $Item -Key 'file').Trim()
    $urlKey = (Get-EntryString -Entry $Item -Key 'urlKey').Trim()
    $urlXPath = (Get-EntryString -Entry $Item -Key 'urlXPath').Trim()
    $kindText = ''
    if ($Kind) { $kindText = ([string]$Kind).Trim().ToLowerInvariant() }

    $result = @{ Url = $url; File = $pattern; UrlKey = $urlKey; UrlXPath = $urlXPath; Error = '' }
    if ($urlXPath -and ($kindText -ne 'xml' -or $url -or $urlKey -or $pattern)) {
        $result.Error = 'urlXPath 只用于 XML 源，且不能与 url / urlKey / file 同时配置'
        return $result
    }
    if ($url -and $urlKey) {
        $result.Url = ''
        $result.File = ''
        $result.UrlKey = ''
        $result.Error = '同一个文件不能同时填写 url（下载地址）与 urlKey（接口字段），请二选一'
        return $result
    }
    if ($url -and $pattern) {
        $result.Url = ''
        $result.File = ''
        $result.UrlKey = ''
        $result.Error = '同一个文件不能同时填写 url（下载地址）和 file（文件名匹配规则），请二选一'
        return $result
    }
    if ($urlKey -and @('json', 'xml') -notcontains $kindText) {
        $result.Url = ''
        $result.File = ''
        $result.UrlKey = ''
        $result.Error = 'urlKey（接口字段）只能用在 JSON / XML 接口源（source.kind: json / xml）里；其它来源请写 url 或 file'
        return $result
    }
    if ($kindText -eq 'xml' -and $urlKey -and $pattern) {
        $result.Error = 'XML 来源的 urlKey 不能与 file 同时配置，请用 itemsKey / match 选择文件'
        return $result
    }
    if ($kindText -eq 'json' -and $pattern -and -not $urlKey) {
        $result.Url = ''
        $result.File = ''
        $result.UrlKey = ''
        $result.Error = 'JSON 接口源里只写 file（文件名匹配规则）无法定位安装包，请同时写出它在接口里的字段名（urlKey）'
        return $result
    }
    return $result
}
