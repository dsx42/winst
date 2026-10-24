#Requires -Version 5.1

function Get-WinstVersionRule {
    <#
    .SYNOPSIS
        读取并校验条目的版本识别规则（versionKind / versionBetween）。
    .DESCRIPTION
        page / json / magnet 解析器共用这套判断与文案（与 Get-WinstVersionKindError 完全同文），
        统一到这里；新增识别器时只改 Get-VersionKindPattern / Get-VersionKindList。
    .OUTPUTS
        @{ Ok; Error; VersionKind; VersionBetween }
    #>
    param($Source)

    $kind = (Get-EntryString -Entry $Source -Key 'versionKind').Trim()
    $kindError = Get-WinstVersionKindError -Kind $kind
    if ($kindError) {
        return @{ Ok = $false; Error = $kindError; VersionKind = ''; VersionBetween = @() }
    }
    $between = @(Get-EntryArray -Entry $Source -Key 'versionBetween')
    return @{ Ok = $true; Error = ''; VersionKind = $kind; VersionBetween = $between }
}
