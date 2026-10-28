#Requires -Version 5.1

function Get-WinstJsonSourceSpec {
    <#
    .SYNOPSIS
        校验 json 源的接口地址 / 版本规则 / files[] 声明，返回取数所需的规格。
    .OUTPUTS
        @{ Error; Source; ApiUrl; VersionKind; VersionBetween; Declared; MainLocator; FileRule }
    #>
    param($Entry)

    $source = Get-EntryValue -Entry $Entry -Key 'source' -Default $null
    $apiUrl = (Get-EntryString -Entry $source -Key 'apiUrl').Trim()
    if (-not $apiUrl) {
        return @{ Error = '软件源里没有填写 JSON 接口地址（source.apiUrl）' }
    }
    if ($apiUrl -match '\{(versionMajor|version|tag)\}') {
        return @{ Error = ('JSON 接口地址要写固定地址（版本号由接口给出，不能用占位符）: {0}' -f $apiUrl) }
    }

    # 版本识别规则：与 page / magnet 解析器共用同一套校验
    $versionRule = Get-WinstVersionRule -Source $source
    if (-not $versionRule.Ok) { return @{ Error = [string]$versionRule.Error } }

    $declared = @(Get-SourceFileDeclarations -Source $source)
    if ($declared.Count -eq 0) {
        return @{ Error = '软件源里没有填写要下载的文件（source.files）' }
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
        VersionKind = [string]$versionRule.VersionKind; VersionBetween = @($versionRule.VersionBetween)
        Declared = $declared; MainLocator = $mainLocator; FileRule = $fileRule
    }
}
