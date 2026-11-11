#Requires -Version 5.1

function ConvertTo-WinstManifestEntry {
    <#
    .SYNOPSIS
        校验作者字段，将版本、校验与卸载配置归一为业务层字段，不修改原对象。
    #>
    param($Entry)

    $entryFields = @('id', 'name', 'description', 'homepage', 'type', 'group', 'dependencies', 'version',
        'source', 'stripTopDir', 'extractFiles', 'portableMode', 'keep', 'mainExe', 'addToPath', 'env',
        'shortcuts', 'postInstallCopy', 'postInstall', 'installArgs', 'uninstallArgs', 'installerExe',
        'processes', 'uninstall', 'detect')
    $entryStrings = @('id', 'name', 'description', 'homepage', 'type', 'group', 'version', 'portableMode', 'mainExe', 'installArgs', 'uninstallArgs', 'installerExe')
    $copy = Copy-WinstManifestFields -Value $Entry -Label '条目' -Fields $entryFields -Strings $entryStrings
    $id = Get-EntryString -Entry $copy -Key 'id'
    if (-not (Test-WinstSafePathSegment -Name $id)) { throw ('软件源条目 id 不合法：' + $id) }
    $type = ConvertTo-WinstEntryType -Type (Get-EntryString -Entry $copy -Key 'type')
    if (@('portable', 'installer', 'file', 'download') -notcontains $type) { throw '条目 type 必须为 portable / installer / file / download' }
    if ($copy.Contains('stripTopDir') -and $copy['stripTopDir'] -isnot [bool] -and $copy['stripTopDir'] -isnot [string]) { throw 'stripTopDir 必须是布尔值或路径字符串' }
    if ($copy.Contains('env')) {
        if ($copy['env'] -isnot [System.Collections.IDictionary] -and $copy['env'] -isnot [pscustomobject]) { throw 'env 必须是对象' }
        foreach ($pair in @(Get-WinstEntryPairs -Entry $copy['env'])) {
            if ($pair[1] -isnot [string]) { throw ('env.' + $pair[0] + ' 必须是字符串') }
        }
    }

    $sourceFields = @('kind', 'repo', 'releaseTag', 'latestOnly', 'files', 'url', 'pageUrl', 'indexUrl',
        'apiUrl', 'baseUrl', 'itemsKey', 'itemsXPath', 'match', 'follow', 'fetchWith', 'skipExistsCheck',
        'link', 'click', 'thenLink', 'thenClick', 'hashClick', 'version', 'versionFrom', 'versionUrl',
        'versionHeader', 'versionKey', 'versionXPath', 'versionKind', 'versionBetween', 'versionFilter',
        'sort', 'versionRewrite', 'packageVersion')
    $sourceStrings = @('kind', 'repo', 'releaseTag', 'url', 'pageUrl', 'apiUrl', 'baseUrl', 'itemsKey', 'itemsXPath', 'fetchWith', 'versionFrom', 'versionUrl', 'versionHeader', 'versionXPath', 'versionKind', 'versionFilter', 'sort')
    $source = Copy-WinstManifestFields -Value $copy['source'] -Label 'source' -Fields $sourceFields -Strings $sourceStrings -Booleans @('latestOnly', 'skipExistsCheck')
    $kind = (Get-EntryString -Entry $source -Key 'kind').Trim().ToLowerInvariant()
    if (@('direct', 'github', 'listing', 'page', 'json', 'xml', 'magnet') -notcontains $kind) { throw ('未知的来源类型：' + $kind) }

    if ($source.Contains('version')) {
        $versionFields = @('value', 'from', 'url', 'header', 'key', 'xpath', 'kind', 'between', 'filter', 'sort', 'rewrite', 'package')
        $version = Copy-WinstManifestFields -Value $source['version'] -Label 'source.version' -Fields $versionFields -Strings @('value', 'from', 'url', 'header', 'xpath', 'kind', 'filter', 'sort')
        $map = [ordered]@{ from = 'versionFrom'; url = 'versionUrl'; header = 'versionHeader'
            key = 'versionKey'; xpath = 'versionXPath'; kind = 'versionKind'; between = 'versionBetween'
            filter = 'versionFilter'; sort = 'sort'; rewrite = 'versionRewrite'; package = 'packageVersion' }
        foreach ($oldKey in $map.Values) {
            if ($source.Contains($oldKey)) { throw ('source.version 不能与 source.' + $oldKey + ' 同时填写') }
        }
        if ($copy.Contains('version')) { throw 'source.version 不能与条目 version 同时填写' }
        if ($version.Contains('value')) {
            foreach ($key in @($version.Keys)) {
                if (@('value', 'rewrite') -notcontains $key) { throw 'source.version.value 不能与动态版本配置同时填写' }
            }
            if (-not ([string]$version['value']).Trim()) { throw 'source.version.value 不能为空' }
            $copy['version'] = $version['value']
        }
        if ($kind -eq 'direct' -and (Get-EntryString -Entry $version -Key 'from').Trim() -ieq 'page') {
            $map['url'] = 'pageUrl'
            if ($source.Contains('pageUrl')) { throw 'source.version.url 不能与 direct 的 source.pageUrl 同时填写' }
        }
        foreach ($key in $map.Keys) {
            if ($version.Contains($key)) { $source[$map[$key]] = $version[$key] }
        }
        $source.Remove('version')
    }
    if ($copy.Contains('version')) {
        if ($kind -ne 'direct') { throw '固定 version 只适用于 direct 来源；其它来源请声明版本读取规则' }
        if (-not ([string]$copy['version']).Trim()) { throw '固定 version 不能为空' }
        foreach ($key in @('versionFrom', 'versionUrl', 'versionHeader', 'versionKey', 'versionXPath', 'versionKind', 'versionBetween', 'versionFilter', 'sort', 'packageVersion')) {
            if ($source.Contains($key)) { throw ('固定 version 不能与 source.' + $key + ' 同时填写') }
        }
    }
    $from = (Get-EntryString -Entry $source -Key 'versionFrom').Trim().ToLowerInvariant()
    if ($from -and @('listing', 'json', 'xml', 'magnet') -contains $kind) { throw ('source.version.from 不适用于 ' + $kind + ' 来源') }
    $versionKeys = @('versionFrom', 'versionUrl', 'versionHeader', 'versionKey', 'versionXPath', 'versionKind', 'versionBetween', 'versionFilter', 'sort', 'packageVersion')
    $allowedVersion = @()
    switch ($kind) {
        'listing' { $allowedVersion = @('versionKind', 'versionFilter', 'sort') }
        'json' { $allowedVersion = @('versionKey', 'versionKind', 'versionBetween', 'versionFilter', 'sort') }
        'xml' { $allowedVersion = @('versionKey', 'versionXPath') }
        'magnet' { $allowedVersion = @('versionKind', 'versionBetween') }
        default {
            $effectiveFrom = $from
            if (-not $effectiveFrom -and $kind -eq 'github') { $effectiveFrom = 'tag' }
            if (-not $effectiveFrom -and $kind -eq 'page') { $effectiveFrom = 'url' }
            $allowedFrom = switch ($kind) {
                'direct' { @('page', 'package', 'header', 'json') }
                'github' { @('tag', 'file', 'package', 'releaseTitle', 'releaseBody') }
                'page' { @('url', 'page', 'package', 'header', 'json') }
            }
            if ($effectiveFrom -and $allowedFrom -notcontains $effectiveFrom) { throw ('source.version.from 不适用于 ' + $kind + ' 来源：' + $effectiveFrom) }
            $allowedVersion = @('versionFrom')
            switch ($effectiveFrom) {
                'package' { $allowedVersion += 'packageVersion' }
                'header' { $allowedVersion += @('versionUrl', 'versionHeader') }
                'json' { $allowedVersion += @('versionUrl', 'versionKey', 'versionFilter', 'sort') }
                { @('page', 'url', 'file', 'releaseTitle', 'releaseBody') -contains $_ } {
                    $allowedVersion += @('versionKind', 'versionBetween')
                    if ($kind -eq 'page') { $allowedVersion += 'versionKey' }
                }
            }
        }
    }
    foreach ($key in $versionKeys) {
        if ($source.Contains($key) -and $allowedVersion -notcontains $key) { throw ('source.' + $key + ' 不适用于当前来源和版本读取方式') }
    }
    $sort = (Get-EntryString -Entry $source -Key 'sort').Trim()
    $allowedSort = @('semver')
    if ($kind -eq 'listing') { $allowedSort += 'text' }
    if ($sort -and $allowedSort -notcontains $sort) { throw ('source.version.sort 只支持 ' + ($allowedSort -join ' / ')) }
    if ($source.Contains('versionKey')) {
        $keyValue = $source['versionKey']
        if ($kind -eq 'xml' -and $keyValue -is [array]) {
            if ($keyValue.Count -eq 0) { throw 'source.version.key 数组不能为空' }
            foreach ($part in $keyValue) {
                if ($part -isnot [string] -or -not $part.Trim()) { throw 'source.version.key 数组只能包含非空字符串' }
            }
        } elseif ($keyValue -isnot [string]) { throw 'source.version.key 必须是字符串' }
        if ((Get-EntryString -Entry $source -Key 'versionKey') -and ($source.Contains('versionKind') -or $source.Contains('versionBetween'))) {
            throw 'source.version.key 不能与 kind / between 同时填写'
        }
    }
    if ($source.Contains('versionBetween')) {
        $between = $source['versionBetween']
        if ($between -isnot [array] -or $between.Count -gt 2) { throw 'source.version.between 必须是至多两项的字符串数组' }
        foreach ($part in $between) { if ($part -isnot [string]) { throw 'source.version.between 只能包含字符串' } }
        if ($between.Count -gt 0 -and -not $between[0]) { throw 'source.version.between 的前缀不能为空' }
    }
    if ($source.Contains('packageVersion')) {
        $packageFields = @('file', 'inner', 'path', 'versionKind')
        $source['packageVersion'] = Copy-WinstManifestFields -Value $source['packageVersion'] -Label 'source.version.package' -Fields ($packageFields + @('versionBetween')) -Strings $packageFields
    }
    $sourceKinds = @{
        repo = @('github'); releaseTag = @('github'); latestOnly = @('github')
        indexUrl = @('listing'); apiUrl = @('json', 'xml'); baseUrl = @('xml')
        itemsKey = @('json', 'xml'); itemsXPath = @('xml'); match = @('xml'); follow = @('json')
        pageUrl = @('direct', 'page'); fetchWith = @('direct', 'page')
        link = @('page'); click = @('page'); thenLink = @('page'); thenClick = @('page'); hashClick = @('page')
    }
    foreach ($key in $sourceKinds.Keys) {
        if ($source.Contains($key) -and $sourceKinds[$key] -notcontains $kind) { throw ('source.' + $key + ' 不适用于 ' + $kind + ' 来源') }
    }
    if ($kind -eq 'direct' -and $from -ne 'page' -and ($source.Contains('pageUrl') -or $source.Contains('fetchWith'))) { throw 'direct 的 pageUrl / fetchWith 必须配合页面版本读取方式' }
    if ($source.Contains('skipExistsCheck') -and $kind -eq 'magnet') { throw 'magnet 来源不支持 skipExistsCheck' }
    if ($source.Contains('fetchWith') -and @('iwr', 'browser') -notcontains $source['fetchWith']) { throw 'source.fetchWith 只能为 iwr / browser' }
    if ($source.Contains('follow')) {
        $fields = @('itemsKey', 'versionKey', 'versionFilter', 'sort', 'apiUrl', 'urlKey')
        $source['follow'] = Copy-WinstManifestFields -Value $source['follow'] -Label 'source.follow' -Fields $fields -Strings $fields
    }
    $conditionFields = @('class', 'id', 'text', 'href')
    foreach ($key in @('link', 'click', 'thenClick', 'hashClick')) {
        if (-not $source.Contains($key)) { continue }
        $rules = @()
        foreach ($rule in @($source[$key])) {
            $rules += Copy-WinstManifestFields -Value $rule -Label ('source.' + $key) -Fields $conditionFields -Strings $conditionFields
        }
        if ($key -eq 'link') {
            if ($rules.Count -ne 1) { throw 'source.link 必须是一个条件对象' }
            $source[$key] = $rules[0]
        } else { $source[$key] = $rules }
    }
    if ($source.Contains('thenLink')) {
        $then = Copy-WinstManifestFields -Value $source['thenLink'] -Label 'source.thenLink' -Fields @('link')
        if ($then.Contains('link')) {
            $then['link'] = Copy-WinstManifestFields -Value $then['link'] -Label 'source.thenLink.link' -Fields $conditionFields -Strings $conditionFields
        }
        $source['thenLink'] = $then
    }

    $files = @()
    $index = 0
    if ($source.Contains('files') -and $source.Contains('url')) { throw 'source.files 与 source.url 不能同时声明' }
    $fileItems = @()
    if ($source.Contains('files')) {
        if ($source['files'] -isnot [array]) { throw 'source.files 必须是文件数组，不能为 null 或单个对象' }
        $fileItems = $source['files']
    }
    foreach ($item in $fileItems) {
        $label = 'source.files[' + $index + ']'
        if ($item -is [string]) {
            if (-not $item.Trim()) { throw ($label + ' 的地址不能为空') }
            $file = [ordered]@{ url = $item }
        }
        else {
            $fileStrings = @('url', 'file', 'urlKey', 'urlXPath', 'itemsKey', 'dest', 'name',
                'hash', 'hashHeader', 'hashKey', 'hashXPath', 'hashFile', 'hashFileKey', 'hashFileMatch',
                'hashFrom', 'refresh', 'compare', 'versionListUrl', 'versionKind', 'versionFilter')
            $fileFields = $fileStrings + @('match', 'extract', 'stripTopDir', 'checksum', 'maxAgeHours', 'versionRewrite')
            $file = Copy-WinstManifestFields -Value $item -Label $label -Fields $fileFields -Strings $fileStrings -Booleans @('extract')
        }
        if ($file.Contains('stripTopDir') -and $file['stripTopDir'] -isnot [bool] -and $file['stripTopDir'] -isnot [string]) { throw ($label + '.stripTopDir 必须是布尔值或路径字符串') }
        if ($file.Contains('match')) {
            if (@('json', 'xml') -notcontains $kind -or ($kind -eq 'json' -and $index -ne 0)) { throw ($label + '.match 只适用于 JSON 主包或 XML 文件') }
            if ($file['match'] -isnot [System.Collections.IDictionary] -and $file['match'] -isnot [pscustomobject]) { throw ($label + '.match 必须是对象') }
            foreach ($pair in @(Get-WinstEntryPairs -Entry $file['match'])) {
                if ($pair[1] -isnot [string]) { throw ($label + '.match.' + $pair[0] + ' 必须是字符串') }
            }
        }
        if ($file.Contains('checksum')) {
            $checksumFields = @('value', 'header', 'key', 'xpath', 'file', 'fileKey', 'fileMatch', 'format')
            $checksum = Copy-WinstManifestFields -Value $file['checksum'] -Label ($label + '.checksum') -Fields ($checksumFields + @('click')) -Strings $checksumFields
            $map = [ordered]@{ value = 'hash'; header = 'hashHeader'; key = 'hashKey'; xpath = 'hashXPath'
                file = 'hashFile'; fileKey = 'hashFileKey'; fileMatch = 'hashFileMatch'; format = 'hashFrom' }
            foreach ($oldKey in $map.Values) {
                if ($file.Contains($oldKey)) { throw ($label + '.checksum 不能与 ' + $oldKey + ' 同时填写') }
            }
            $selectors = @($checksum.Keys | Where-Object { @('format', 'click') -notcontains $_ })
            if (($selectors.Count -ne 1 -and $checksum['format'] -ne 'page') -or ($checksum['format'] -eq 'page' -and $selectors.Count -ne 0)) {
                throw ($label + '.checksum 必须且只能声明一种摘要来源；页面摘要单独使用 format: page')
            }
            if ($checksum.Contains('format') -and $checksum['format'] -ne 'page' -and @('file', 'fileKey', 'fileMatch') -notcontains $selectors[0]) {
                throw ($label + '.checksum.format 只适用于校验文件或 page')
            }
            foreach ($key in $map.Keys) {
                if ($checksum.Contains($key)) {
                    if (-not ([string]$checksum[$key]).Trim()) { throw ($label + '.checksum.' + $key + ' 不能为空') }
                    $file[$map[$key]] = $checksum[$key]
                }
            }
            if ($checksum.Contains('click')) {
                if ($index -ne 0 -or $kind -ne 'page' -or $checksum['format'] -ne 'page') { throw ($label + '.checksum.click 仅适用于 page 主包的页面摘要') }
                if ($source.Contains('hashClick')) { throw 'checksum.click 不能与 source.hashClick 同时填写' }
                $steps = @()
                foreach ($step in @($checksum['click'])) {
                    $steps += Copy-WinstManifestFields -Value $step -Label ($label + '.checksum.click') -Fields $conditionFields -Strings $conditionFields
                }
                $source['hashClick'] = $steps
            }
            $file.Remove('checksum')
        }
        $hashSelectors = @($file.Keys | Where-Object { @('hash', 'hashHeader', 'hashKey', 'hashXPath', 'hashFile', 'hashFileKey', 'hashFileMatch') -contains $_ })
        if ($hashSelectors.Count -gt 1) { throw ($label + ' 必须且只能声明一种摘要来源') }
        $hashFrom = (Get-EntryString -Entry $file -Key 'hashFrom').Trim()
        if ($hashFrom -ieq 'page') {
            if ($kind -ne 'page' -or $index -ne 0 -or $hashSelectors.Count -gt 0) { throw ($label + ' 的页面摘要只适用于 page 主包，不能与其它摘要来源同时填写') }
        } elseif ($hashFrom -and ($hashSelectors.Count -ne 1 -or @('hashFile', 'hashFileKey', 'hashFileMatch') -notcontains $hashSelectors[0])) {
            throw ($label + '.checksum.format 必须配合校验文件来源')
        }
        foreach ($key in @('hashKey', 'hashXPath', 'hashFileKey', 'hashFileMatch')) {
            if (-not $file.Contains($key)) { continue }
            $validKind = ($kind -eq 'xml' -and @('hashKey', 'hashXPath') -contains $key) -or
                ($kind -eq 'json' -and $index -eq 0 -and $key -ne 'hashXPath')
            if (-not $validKind) { throw ($label + '.' + $key + ' 不适用于当前来源或配套文件') }
        }
        if ($file.Contains('hashHeader') -and $kind -eq 'magnet') { throw 'magnet 来源不支持 checksum.header' }
        if ($file.Contains('hash')) {
            $hash = ([string]$file['hash']).Trim()
            if ($hash -notmatch '\{version(Major|Minor)?\}' -and $hash -notmatch '\A(?:[0-9a-fA-F]{32}|[0-9a-fA-F]{40}|[0-9a-fA-F]{64}|[0-9a-fA-F]{128})\z') {
                throw ($label + '.checksum.value 必须是 32 / 40 / 64 / 128 位十六进制字符串')
            }
        }
        if ($file.Contains('refresh')) {
            $refresh = ([string]$file['refresh']).Trim().ToLowerInvariant().Replace('-', '').Replace('_', '').Replace(' ', '')
            if (@('auto', 'always', 'ifmissing', 'check', 'ttl') -notcontains $refresh) { throw ($label + '.refresh 取值无效') }
        }
        if ($file.Contains('maxAgeHours')) {
            $hours = 0
            if (-not [int]::TryParse([string]$file['maxAgeHours'], [ref]$hours) -or $hours -le 0) { throw ($label + '.maxAgeHours 必须是正整数') }
        }
        if ($file.Contains('compare')) {
            foreach ($part in @(([string]$file['compare']) -split '[,;|\s]+')) {
                $criterion = $part.ToLowerInvariant().Replace('-', '').Replace('_', '')
                if ($criterion -and @('auto', 'size', 'etag', 'lastmodified', 'lm', 'checksum', 'hash', 'fingerprint') -notcontains $criterion) { throw ($label + '.compare 不支持：' + $part) }
            }
        }
        $files += $file
        $index++
    }
    if ($source.Contains('files')) { $source['files'] = $files }
    $copy['source'] = $source

    if ($copy.Contains('detect')) {
        $fields = @('method', 'name', 'pathGlob', 'jsonKey', 'exe', 'versionArgs', 'versionKind')
        $copy['detect'] = Copy-WinstManifestFields -Value $copy['detect'] -Label 'detect' -Fields ($fields + @('versionBetween', 'versionRewrite')) -Strings $fields
    }
    if ($copy.Contains('shortcuts')) {
        $copy['shortcuts'] = Copy-WinstManifestFields -Value $copy['shortcuts'] -Label 'shortcuts' -Fields @('desktop', 'startMenu') -Booleans @('desktop', 'startMenu')
    }
    if ($copy.Contains('uninstall')) {
        $uninstall = Copy-WinstManifestFields -Value $copy['uninstall'] -Label 'uninstall' -Fields @('name', 'commands', 'args') -Strings @('args')
        if ($uninstall.Contains('args')) {
            if ($copy.Contains('uninstallArgs')) { throw 'uninstall.args 不能与条目 uninstallArgs 同时填写' }
            $copy['uninstallArgs'] = $uninstall['args']
            $uninstall.Remove('args')
        }
        $copy['uninstall'] = $uninstall
    }
    if ($copy.Contains('postInstallCopy')) {
        $rules = @()
        foreach ($rule in @($copy['postInstallCopy'])) {
            $rules += Copy-WinstManifestFields -Value $rule -Label 'postInstallCopy' -Fields @('from', 'to', 'move') -Strings @('from', 'to') -Booleans @('move')
        }
        $copy['postInstallCopy'] = $rules
    }
    foreach ($field in @('postInstall', 'uninstall.commands')) {
        $owner = $copy
        $key = $field
        if ($field -eq 'uninstall.commands') { $owner = $copy['uninstall']; $key = 'commands' }
        if ($null -eq $owner -or -not $owner.Contains($key)) { continue }
        $commands = @()
        foreach ($command in @($owner[$key])) {
            $commandCopy = Copy-WinstManifestFields -Value $command -Label $field -Fields @('exe', 'args', 'timeoutSec', 'requireAdmin') -Strings @('exe', 'args') -Booleans @('requireAdmin')
            if ($commandCopy.Contains('timeoutSec')) {
                $seconds = 0
                if (-not [int]::TryParse([string]$commandCopy['timeoutSec'], [ref]$seconds) -or $seconds -le 0) { throw ($field + '.timeoutSec 必须是正整数') }
            }
            $commands += $commandCopy
        }
        $owner[$key] = $commands
    }
    return $copy
}
