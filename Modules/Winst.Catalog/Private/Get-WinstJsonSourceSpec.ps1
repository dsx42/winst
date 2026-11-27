#Requires -Version 5.1

function Get-WinstJsonSourceSpec {
    <#
    .SYNOPSIS
        校验 json 源的接口地址 / 版本规则 / files[] 声明，返回取数所需的规格。
    .OUTPUTS
        @{ Error; Source; ApiUrl; Selection; Follow; FollowSelection; Declared; MainLocator; FileRule; HashFileRule }
    #>
    param($Entry)

    $source = Get-EntryValue -Entry $Entry -Key 'source' -Default $null
    $apiUrl = (Get-EntryString -Entry $source -Key 'apiUrl').Trim()
    if (-not $apiUrl) {
        return @{ Error = '软件源里没有填写 JSON 接口地址（source.apiUrl）' }
    }
    if ($apiUrl -match '\{(versionMajor|versionMinor|version|tag)\}') {
        return @{ Error = ('JSON 接口地址要写固定地址（版本号由接口给出，不能用占位符）: {0}' -f $apiUrl) }
    }

    # 版本识别规则：与 page / magnet 解析器共用同一套校验
    $versionRule = Get-WinstVersionRule -Source $source
    if (-not $versionRule.Ok) { return @{ Error = [string]$versionRule.Error } }
    $selection = Get-WinstJsonSelectionSpec -Source $source -Label 'JSON 来源'
    if ($selection.Error) { return @{ Error = $selection.Error } }
    $follow = $source['follow']
    $followSelection = $null
    if ($null -ne $follow) {
        $hasFollowApiUrl = $follow.Contains('apiUrl')
        $hasFollowUrlKey = $follow.Contains('urlKey')
        if ($hasFollowApiUrl -eq $hasFollowUrlKey) {
            return @{ Error = 'source.follow.apiUrl 与 urlKey 必须且只能填写一个' }
        }
        $followSelection = Get-WinstJsonSelectionSpec -Source $follow -Label 'source.follow'
        if ($followSelection.Error) { return @{ Error = $followSelection.Error } }
        if ($hasFollowApiUrl) {
            $followApiUrl = (Get-EntryString -Entry $follow -Key 'apiUrl').Trim()
            $checkUrl = [regex]::Replace($followApiUrl, '\{version(Major|Minor)?\}', '0')
            if ($checkUrl -match '[{}]') { return @{ Error = 'source.follow.apiUrl 只支持 {version} / {versionMajor} / {versionMinor} 占位符' } }
            if ($followApiUrl -cmatch '\{version(Major|Minor)?\}' -and -not $followSelection.VersionKey) {
                return @{ Error = 'source.follow.apiUrl 使用版本占位符时必须填写 source.follow.versionKey' }
            }
            $checkUri = $null
            if (-not [Uri]::TryCreate($checkUrl, [UriKind]::Absolute, [ref]$checkUri) -or @('http', 'https') -notcontains $checkUri.Scheme) {
                return @{ Error = 'source.follow.apiUrl 必须是完整的绝对 HTTP(S) 地址' }
            }
        }
        elseif (-not (Get-EntryString -Entry $follow -Key 'urlKey').Trim()) {
            return @{ Error = 'source.follow.urlKey 不能为空' }
        }
    }

    $declared = @(Get-SourceFileDeclarations -Source $source)
    if ($declared.Count -eq 0) {
        return @{ Error = '软件源里没有填写要下载的文件（source.files）' }
    }
    for ($i = 1; $i -lt $declared.Count; $i++) {
        if ($declared[$i].Contains('itemsKey')) { return @{ Error = 'files[].itemsKey 只支持 JSON 主包' } }
    }
    $hashFileRule = $null
    $hashFileMatch = (Get-EntryString -Entry $declared[0] -Key 'hashFileMatch').Trim()
    if ($hashFileMatch) {
        if (-not (Get-EntryString -Entry $declared[0] -Key 'itemsKey').Trim()) {
            return @{ Error = 'files[0].hashFileMatch 必须配合非空 itemsKey' }
        }
        $hashFileRule = New-MatchRule -Rule $hashFileMatch -Kind '校验文件名'
        if (-not $hashFileRule.Ok) { return @{ Error = [string]$hashFileRule.Error } }
    }
    $mainLocator = Get-SourceFileLocator -Item $declared[0] -Kind 'json'
    if ($mainLocator.Error) { return @{ Error = [string]$mainLocator.Error } }
    if (-not $mainLocator.UrlKey) {
        return @{ Error = '接口来源的主包要写出它在接口里的字段名（files[0].urlKey，如 url / downloads.windowsZip.link）' }
    }

    $fileRule = $null
    if ($mainLocator.File) {
        $fileRule = New-MatchRule -Rule (Get-MatchRuleText -Rule $mainLocator.File) -Kind '文件名'
        if (-not $fileRule.Ok) { return @{ Error = [string]$fileRule.Error } }
    }

    return @{
        Error = ''; Source = $source; ApiUrl = $apiUrl
        Selection = $selection; Follow = $follow; FollowSelection = $followSelection
        Declared = $declared; MainLocator = $mainLocator; FileRule = $fileRule; HashFileRule = $hashFileRule
    }
}
