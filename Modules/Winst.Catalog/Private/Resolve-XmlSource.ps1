#Requires -Version 5.1

function Resolve-XmlSource {
    <#
    .SYNOPSIS
        按字段路径与条件或 XPath 选择 XML 记录，读取版本、下载地址与摘要。
    #>
    param([hashtable]$Context, $Entry)

    $result = New-SourceResolveResult -Kind 'xml'
    $source = Get-EntryValue -Entry $Entry -Key 'source' -Default $null
    $versionKeys = @()
    $sourceMatch = $null
    foreach ($pair in @(Get-WinstEntryPairs -Entry $source)) {
        $key = [string]$pair[0]
        if (@('apiUrl', 'itemsKey', 'itemsXPath', 'versionXPath', 'baseUrl') -contains $key -and $pair[1] -isnot [string]) {
            throw ('source.' + $key + ' 必须是字符串')
        }
        if ($key -ieq 'versionKey') {
            if (($pair[1] -isnot [string] -and $pair[1] -isnot [Array]) -or @($pair[1]).Count -eq 0) {
                throw 'source.versionKey 必须是字段路径字符串或非空字符串数组'
            }
            foreach ($part in @($pair[1])) {
                if ($part -isnot [string] -or -not $part.Trim()) { throw 'source.versionKey 的每个字段路径必须为非空字符串' }
                $null = ConvertTo-WinstXmlXPath -Key $part
                $versionKeys += $part.Trim()
            }
        }
        if ($key -ieq 'match') {
            if ($pair[1] -isnot [System.Collections.IDictionary] -and $pair[1] -isnot [pscustomobject]) {
                throw 'source.match 必须是对象'
            }
            $sourceMatch = $pair[1]
        }
    }
    $apiUrl = (Get-EntryString -Entry $source -Key 'apiUrl').Trim()
    $itemsKey = (Get-EntryString -Entry $source -Key 'itemsKey').Trim()
    $itemsXPath = (Get-EntryString -Entry $source -Key 'itemsXPath').Trim()
    $versionXPath = (Get-EntryString -Entry $source -Key 'versionXPath').Trim()
    if (-not $apiUrl -or (-not $itemsKey -and -not $itemsXPath) -or ($versionKeys.Count -eq 0 -and -not $versionXPath)) {
        throw 'XML 来源必须填写 apiUrl、itemsKey 或 itemsXPath，以及 versionKey 或 versionXPath'
    }
    if ($itemsKey -and $itemsXPath) { throw 'source.itemsKey 与 itemsXPath 不能同时配置' }
    if ($itemsXPath -and $null -ne $sourceMatch) { throw 'source.match 只能配合 itemsKey，不能与 itemsXPath 同时配置' }
    if ($versionKeys.Count -gt 0 -and $versionXPath) { throw 'source.versionKey 与 versionXPath 不能同时配置' }
    if ($itemsKey) { $null = ConvertTo-WinstXmlXPath -Key $itemsKey }
    $apiUri = $null
    if ($apiUrl -match '\{(versionMajor|versionMinor|version|tag)\}' -or
            -not [Uri]::TryCreate($apiUrl, [UriKind]::Absolute, [ref]$apiUri) -or @('http', 'https') -notcontains $apiUri.Scheme) {
        throw 'source.apiUrl 必须是无版本占位符的绝对 HTTP(S) 地址'
    }
    $baseUrl = (Get-EntryString -Entry $source -Key 'baseUrl').Trim()
    $baseUri = $null
    if ($baseUrl -and (-not [Uri]::TryCreate($baseUrl, [UriKind]::Absolute, [ref]$baseUri) -or
            @('http', 'https') -notcontains $baseUri.Scheme -or $baseUri.Query -or $baseUri.Fragment -or
            -not $baseUri.AbsolutePath.EndsWith('/'))) {
        throw 'source.baseUrl 必须是以 / 结尾且无查询串或片段的绝对 HTTP(S) 目录地址'
    }
    foreach ($xpath in @($itemsXPath, $versionXPath)) {
        if (-not $xpath) { continue }
        try { $null = [System.Xml.XPath.XPathExpression]::Compile($xpath) }
        catch { throw ('XML XPath 写法错误「{0}」：{1}' -f $xpath, $_.Exception.Message) }
    }
    $declared = @(Get-SourceFileDeclarations -Source $source)
    if ($declared.Count -eq 0) { throw 'XML 来源必须填写 source.files' }
    for ($i = 0; $i -lt $declared.Count; $i++) {
        $item = $declared[$i]
        foreach ($pair in @(Get-WinstEntryPairs -Entry $item)) {
            $key = [string]$pair[0]
            if (@('itemsKey', 'urlKey', 'hashKey', 'urlXPath', 'hashXPath') -contains $key -and $pair[1] -isnot [string]) {
                throw ('files[].' + $key + ' 必须是字符串')
            }
            if ($key -ieq 'match' -and $pair[1] -isnot [System.Collections.IDictionary] -and $pair[1] -isnot [pscustomobject]) {
                throw 'files[].match 必须是对象'
            }
        }
        foreach ($key in @('itemsKey', 'urlKey', 'hashKey')) {
            $value = (Get-EntryString -Entry $item -Key $key).Trim()
            if ($value) { $null = ConvertTo-WinstXmlXPath -Key $value }
        }
        $locator = Get-SourceFileLocator -Item $item -Kind 'xml'
        if ($locator.Error) { throw $locator.Error }
        $fromXml = [bool]($locator.UrlKey -or $locator.UrlXPath)
        if ($i -eq 0 -and -not $fromXml) { throw 'XML 主包必须填写 files[0].urlKey 或 urlXPath' }
        if (-not $fromXml -and -not $locator.Url) { throw 'XML 文件必须填写 urlKey、urlXPath 或 url' }
        if ($fromXml -and (Get-EntryString -Entry $item -Key 'versionListUrl').Trim()) {
            throw 'XML urlKey / urlXPath 文件不能配置 versionListUrl'
        }
        if ((Get-EntryString -Entry $item -Key 'hashKey').Trim() -and (Get-EntryString -Entry $item -Key 'hashXPath').Trim()) {
            throw 'files[].hashKey 与 hashXPath 不能同时配置'
        }
        foreach ($xpath in @($locator.UrlXPath, (Get-EntryString -Entry $item -Key 'hashXPath').Trim())) {
            if (-not $xpath) { continue }
            try { $null = [System.Xml.XPath.XPathExpression]::Compile($xpath) }
            catch { throw ('XML 文件 XPath 写法错误「{0}」：{1}' -f $xpath, $_.Exception.Message) }
        }
    }

    try { $text = Invoke-WinstHttpGet -Uri $apiUrl -Context $Context }
    catch { throw ('无法打开 XML 接口 {0}：{1}' -f $apiUrl, $_.Exception.Message) }
    $document = ConvertFrom-WinstXml -Text $text
    if ($itemsKey) {
        $record = Select-WinstXmlItem -Node $document.DocumentElement -Key $itemsKey -Match $sourceMatch -Label '父记录'
    } else {
        try { $records = $document.SelectNodes($itemsXPath) }
        catch { throw ('XML itemsXPath 无法选择记录：{0}（{1}）' -f $itemsXPath, $_.Exception.Message) }
        if ($records.Count -ne 1) {
            throw ('XML itemsXPath 必须匹配唯一记录，实际匹配 {0} 条：{1}' -f $records.Count, $itemsXPath)
        }
        $record = $records.Item(0)
    }
    if ($versionKeys.Count -gt 0) {
        $parts = @(foreach ($key in $versionKeys) {
            Get-WinstXmlValue -Node $record -XPath (ConvertTo-WinstXmlXPath -Key $key)
        })
        $versionText = $parts -join '.'
    } else {
        $versionText = Get-WinstXmlValue -Node $record -XPath $versionXPath
    }
    $version = Get-NormalizedVersionString -Value $versionText
    if ($version -match '(^\.|\.$|\.\.)' -or -not (Get-WinstVersionFromText -Text $version)) { throw ('XML 版本字段没有返回完整版本号：' + $version) }
    $result.Version = $version
    $files = @()
    for ($i = 0; $i -lt $declared.Count; $i++) {
        $item = $declared[$i]
        $locator = Get-SourceFileLocator -Item $item -Kind 'xml'
        $fromXml = [bool]($locator.UrlKey -or $locator.UrlXPath)
        $fileItemsKey = (Get-EntryString -Entry $item -Key 'itemsKey').Trim()
        $fileMatch = Get-EntryValue -Entry $item -Key 'match' -Default $null
        $fileRecord = $record
        if ($fileItemsKey -or $null -ne $fileMatch) {
            $fileRecord = Select-WinstXmlItem -Node $record -Key $fileItemsKey -Match $fileMatch -Label ('文件记录 ' + ($i + 1))
        }
        $fileVersion = Get-SourceFileVersion -Item $item -Version $version
        if (-not $fromXml -and $i -gt 0) {
            $fileVersion = Get-WinstCompanionFileVersion -Context $Context -Item $item -Source $source -MainVersion $version
            foreach ($note in @($fileVersion.Notes)) { $result.Notes += $note }
        }
        if (-not $fileVersion.Ok) { throw $fileVersion.Error }
        $urlText = Expand-VersionPlaceholder -Text $locator.Url -Version $fileVersion.Version
        if ($locator.UrlKey) { $urlText = Get-WinstXmlValue -Node $fileRecord -XPath (ConvertTo-WinstXmlXPath -Key $locator.UrlKey) }
        elseif ($locator.UrlXPath) { $urlText = Get-WinstXmlValue -Node $fileRecord -XPath $locator.UrlXPath }
        $downloadUri = $null
        if (-not [Uri]::TryCreate($urlText, [UriKind]::Absolute, [ref]$downloadUri)) {
            if (-not $baseUri) { throw ('XML 相对下载地址必须配置 source.baseUrl：' + $urlText) }
            if (-not [Uri]::TryCreate($baseUri, $urlText, [ref]$downloadUri)) { throw ('XML 下载地址无效：' + $urlText) }
        }
        if (@('http', 'https') -notcontains $downloadUri.Scheme) { throw ('XML 下载地址必须是 HTTP(S)：' + $urlText) }
        $hash = ''
        $hashKey = (Get-EntryString -Entry $item -Key 'hashKey').Trim()
        $hashXPath = (Get-EntryString -Entry $item -Key 'hashXPath').Trim()
        if ($hashKey) { $hashXPath = ConvertTo-WinstXmlXPath -Key $hashKey }
        if ($hashXPath) {
            $hash = Get-WinstXmlValue -Node $fileRecord -XPath $hashXPath
            if ($hash -notmatch '\A[0-9a-fA-F]+\z' -or -not (Get-HashAlgorithmFromDigestLength -Length $hash.Length)) {
                throw 'XML 摘要字段必须返回 32 / 40 / 64 / 128 位十六进制摘要'
            }
        }
        $dest = Get-WinstFileDest -Item $item -Index ($i + 1) -Result $result
        $ownVersion = ($i -eq 0)
        if (-not $fromXml -and $i -gt 0) { $ownVersion = [bool]$fileVersion.Own }
        $files += New-ResolvedFileFromDeclaration -Item $item -Url $downloadUri.AbsoluteUri -Version $fileVersion.Version `
            -Dest $dest -HashOverride $hash -MainFile:($i -eq 0) -OwnVersion:$ownVersion
    }
    $probe = Test-WinstManifestUrlOrNote -Context $Context -Url $files[0].url `
        -Skip (Get-EntryBool -Entry $source -Key 'skipExistsCheck') `
        -MissingError ('XML 接口给出的地址不存在（HTTP 404）：' + $files[0].url)
    if (-not $probe.Ok) { $result.Error = $probe.Error; return $result }
    if ($probe.Note) { $result.Notes += $probe.Note }
    $result.Files = $files
    $result.Ok = $true
    return $result
}
